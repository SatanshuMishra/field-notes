import 'package:fake_async/fake_async.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/live_audio_capture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_audio_test_support.dart';

const int _samplesPerChunk = 4800;
const int _samplesIn40Ms = 1920;

void main() {
  test('a chunk that straddles the start of writing keeps only the samples after it', () {
    fakeAsync((FakeAsync async) {
      final FakeMicrophone microphone = FakeMicrophone();
      final FakeLiveAudio sound = FakeLiveAudio(writesFiles: false);
      final LiveAudioCapture capture = LiveAudioCapture(
        recorderFactory: () => microphone,
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
            armed: true,
          )
          .then((_) => started = true);
      async.flushMicrotasks();
      expect(started, isTrue);

      async.elapse(const Duration(milliseconds: 100));
      microphone.push(pcmAtDbfs(-20, samples: _samplesPerChunk));
      async.flushMicrotasks();
      expect(sound.samplesAppended, 0);

      async.elapse(const Duration(milliseconds: 50));
      capture.beginWriting();
      async.elapse(const Duration(milliseconds: 40));
      microphone.push(pcmAtDbfs(-20, samples: _samplesPerChunk));
      async.flushMicrotasks();

      LiveAudioTake? take;
      capture.stop().then((LiveAudioTake kept) => take = kept);
      async.flushMicrotasks();
      expect(take, isNotNull);

      expect(sound.samplesAppended, _samplesIn40Ms);
      capture.dispose();
      async.flushMicrotasks();
    });
  });
}
