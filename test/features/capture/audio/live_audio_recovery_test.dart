import 'package:fake_async/fake_async.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/live_audio_capture.dart';
import 'package:field_notes/features/capture/audio/microphone_hearing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_audio_test_support.dart';

const Duration _chunkEvery = Duration(milliseconds: 100);
const int _samplesPerChunk = 4800;
const Duration _step = Duration(milliseconds: 10);
const Duration _reopenWithin = Duration(milliseconds: 600);

int _samplesIn(Duration span) =>
    span.inMicroseconds * liveAudioSampleRate ~/ Duration.microsecondsPerSecond;

void main() {
  test('a live take whose microphone goes quiet is reopened and its gap is filled with silence', () {
    fakeAsync((FakeAsync async) {
      final List<FakeMicrophone> microphones = <FakeMicrophone>[];
      final FakeLiveAudio sound = FakeLiveAudio(writesFiles: false);
      final LiveAudioCapture capture = LiveAudioCapture(
        recorderFactory: () {
          final FakeMicrophone microphone = FakeMicrophone();
          microphones.add(microphone);
          return microphone;
        },
        encoder: sound,
        chainRunner: passThroughChain,
        clock: () => async.elapsed,
      );
      bool started = false;
      capture
          .start(
            input: const AudioInput(id: null, label: 'System default'),
            profile: InputProfile.studio,
            volume: 100,
            path: 'take.m4a',
          )
          .then((_) => started = true);
      async.flushMicrotasks();
      expect(started, isTrue);
      final Duration takeBegan = async.elapsed;

      for (int chunk = 0; chunk < 2; chunk += 1) {
        async.elapse(_chunkEvery);
        microphones.last.push(pcmAtDbfs(-20, samples: _samplesPerChunk));
        async.flushMicrotasks();
      }
      expect(capture.hearingNow, MicrophoneHearing.hearing);
      final Duration wentQuiet = async.elapsed;

      while (microphones.length < 2 &&
          async.elapsed - wentQuiet <= _reopenWithin) {
        async.elapse(_step);
      }
      expect(microphones, hasLength(2));
      expect(microphones.last.startStreamConfigs, hasLength(1));
      expect(async.elapsed - wentQuiet, lessThanOrEqualTo(_reopenWithin));
      expect(capture.hearingNow, MicrophoneHearing.lost);

      for (int chunk = 0; chunk < 13; chunk += 1) {
        async.elapse(_chunkEvery);
        microphones.last.push(pcmAtDbfs(-20, samples: _samplesPerChunk));
        async.flushMicrotasks();
      }
      expect(capture.hearingNow, MicrophoneHearing.hearing);

      LiveAudioTake? take;
      capture.stop().then((LiveAudioTake kept) => take = kept);
      async.flushMicrotasks();
      expect(take, isNotNull);

      final int elapsedSamples = _samplesIn(async.elapsed - takeBegan);
      expect(
        (sound.samplesAppended - elapsedSamples).abs(),
        lessThanOrEqualTo(_samplesPerChunk),
      );
      capture.dispose();
      async.flushMicrotasks();
    });
  });
}
