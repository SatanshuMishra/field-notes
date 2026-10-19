import 'package:fake_async/fake_async.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/live_audio_capture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_audio_test_support.dart';

const int _samplesIn2Seconds = 96000;

void main() {
  test('a chunk arriving microseconds after its own span is written without padding', () {
    fakeAsync((FakeAsync async) {
      final FakeMicrophone microphone = FakeMicrophone();
      final FakeLiveAudio sound = FakeLiveAudio(writesFiles: false);
      final LiveAudioCapture capture = LiveAudioCapture(
        recorderFactory: () => microphone,
        encoder: sound,
        chainRunner: passThroughChain,
        clock: () => async.elapsed,
      );
      capture.start(
        input: const AudioInput(id: null, label: 'System default'),
        profile: InputProfile.studio,
        volume: 100,
        path: 'take.m4a',
        armed: true,
      );
      async.flushMicrotasks();

      capture.beginWriting();
      async.elapse(const Duration(seconds: 2, microseconds: 62));
      microphone.push(pcmAtDbfs(-20, samples: _samplesIn2Seconds));
      async.flushMicrotasks();

      LiveAudioTake? take;
      capture.stop().then((LiveAudioTake kept) => take = kept);
      async.flushMicrotasks();
      expect(take, isNotNull);

      expect(sound.samplesAppended, _samplesIn2Seconds);
      capture.dispose();
      async.flushMicrotasks();
    });
  });
}
