import 'package:fake_async/fake_async.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/live_audio_capture.dart';
import 'package:field_notes/features/capture/audio/microphone_hearing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_audio_test_support.dart';

const Duration _chunkEvery = Duration(milliseconds: 100);
const int _samplesPerChunk = 4800;

LiveAudioCapture _capture(
  FakeAsync async,
  FakeLiveAudio sound,
  List<FakeMicrophone> microphones, {
  bool firstHangs = false,
}) => LiveAudioCapture(
  recorderFactory: () {
    final FakeMicrophone microphone = FakeMicrophone()
      ..hang = firstHangs && microphones.isEmpty;
    microphones.add(microphone);
    return microphone;
  },
  encoder: sound,
  chainRunner: passThroughChain,
  clock: () => async.elapsed,
);

void main() {
  test('a microphone whose start never completes is reported as not hearing within 2 seconds', () {
    fakeAsync((FakeAsync async) {
      final List<FakeMicrophone> microphones = <FakeMicrophone>[];
      final LiveAudioCapture capture = _capture(
        async,
        FakeLiveAudio(writesFiles: false),
        microphones,
        firstHangs: true,
      );
      final List<MicrophoneHearing> heard = <MicrophoneHearing>[];
      capture.hearing.listen(heard.add);
      bool started = false;
      capture
          .start(
            input: const AudioInput(id: null, label: 'System default'),
            profile: InputProfile.studio,
            volume: 100,
            path: 'take.m4a',
            armed: true,
          )
          .then((_) => started = true);
      async.flushMicrotasks();
      expect(capture.hearingNow, MicrophoneHearing.opening);
      expect(microphones.single.startStreamConfigs, hasLength(1));
      expect(microphones.single.streamsOpened, 0);

      async.elapse(const Duration(seconds: 2));

      expect(capture.hearingNow, MicrophoneHearing.cannotHear);
      expect(heard, contains(MicrophoneHearing.cannotHear));
      expect(started, isTrue);
      expect(microphones, hasLength(2));
      expect(microphones.last.startStreamConfigs, hasLength(1));
      expect(microphones.last.streamsOpened, 1);
      capture.dispose();
      async.flushMicrotasks();
    });
  });

  test('digital silence is reported as not hearing', () {
    fakeAsync((FakeAsync async) {
      final List<FakeMicrophone> microphones = <FakeMicrophone>[];
      final LiveAudioCapture capture = _capture(
        async,
        FakeLiveAudio(writesFiles: false),
        microphones,
      );
      capture.start(
        input: const AudioInput(id: null, label: 'System default'),
        profile: InputProfile.studio,
        volume: 100,
        path: 'take.m4a',
        armed: true,
      );
      async.flushMicrotasks();

      const int chunksIn2Seconds = 20;
      for (int chunk = 0; chunk < chunksIn2Seconds; chunk += 1) {
        async.elapse(_chunkEvery);
        microphones.last.push(silentPcm(_samplesPerChunk));
        async.flushMicrotasks();
      }

      expect(capture.hearingNow, MicrophoneHearing.cannotHear);
      expect(microphones, hasLength(1));
      capture.dispose();
      async.flushMicrotasks();
    });
  });
}
