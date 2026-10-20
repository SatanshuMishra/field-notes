import 'dart:io';

import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/voice/record_voice_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../audio/live_audio_test_support.dart';

const Duration _chunkEvery = Duration(milliseconds: 100);
const Duration _poll = Duration(milliseconds: 10);
const Duration _reopenWait = Duration(seconds: 3);
const int _samplesPerChunk = 4800;
const int _chunksAfterReopen = 10;
const int _withinMs = 500;

void main() {
  test(
    'a voice take whose microphone goes quiet keeps sound to the end',
    () async {
      final Directory temp = await Directory.systemTemp.createTemp(
        'voice_microphone_recovery_',
      );
      addTearDown(() => temp.delete(recursive: true));
      final FakeMicrophone microphone = FakeMicrophone();
      final FakeLiveAudio sound = FakeLiveAudio();
      final RecordVoiceRecorder recorder = RecordVoiceRecorder(
        recorder: microphone,
        encoder: sound,
        chainRunner: passThroughChain,
        temporaryDirectory: () async => temp,
        resolveInput: () async =>
            const AudioInput(id: null, label: 'System default'),
      );
      addTearDown(recorder.dispose);

      await recorder.start();
      microphone.push(pcmAtDbfs(-20, samples: _samplesPerChunk));

      final Stopwatch waited = Stopwatch()..start();
      while (microphone.streamsOpened < 2 && waited.elapsed < _reopenWait) {
        await Future<void>.delayed(_poll);
      }
      expect(microphone.streamsOpened, greaterThanOrEqualTo(2));

      for (int chunk = 0; chunk < _chunksAfterReopen; chunk += 1) {
        await Future<void>.delayed(_chunkEvery);
        microphone.push(pcmAtDbfs(-20, samples: _samplesPerChunk));
      }
      await Future<void>.delayed(_poll);

      final VoiceRecording recording = await recorder.stop();

      expect(
        (recording.durationMs - recorder.elapsed.inMilliseconds).abs(),
        lessThanOrEqualTo(_withinMs),
      );
    },
  );
}
