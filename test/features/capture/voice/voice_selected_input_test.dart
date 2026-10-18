import 'dart:io';

import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/voice/record_voice_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

import '../audio/live_audio_test_support.dart';

Future<RecordConfig> _startedConfig(
  Future<AudioInput> Function() resolve,
) async {
  final Directory temp = await Directory.systemTemp.createTemp(
    'voice_input_test_',
  );
  addTearDown(() => temp.delete(recursive: true));
  final FakeMicrophone mic = FakeMicrophone();
  final RecordVoiceRecorder recorder = RecordVoiceRecorder(
    recorder: mic,
    encoder: FakeLiveAudio(),
    chainRunner: passThroughChain,
    temporaryDirectory: () async => temp,
    resolveInput: resolve,
  );
  addTearDown(recorder.dispose);
  await recorder.start();
  return mic.startStreamConfigs.single;
}

void main() {
  test('a voice take records from the chosen microphone', () async {
    final RecordConfig config = await _startedConfig(
      () async => const AudioInput(id: 'b', label: 'CORSAIR HS80 MAX'),
    );

    expect(config.device?.id, 'b');
    expect(config.device?.label, 'CORSAIR HS80 MAX');
    expect(config.encoder, AudioEncoder.pcm16bits);
    expect(config.sampleRate, 48000);
    expect(config.numChannels, 1);
  });

  test('a voice take with no choice records from the system default', () async {
    final RecordConfig config = await _startedConfig(
      () async => const AudioInput(id: null, label: 'System default'),
    );

    expect(config.device, isNull);
    expect(config.encoder, AudioEncoder.pcm16bits);
    expect(config.sampleRate, 48000);
    expect(config.numChannels, 1);
  });

  test('a failing resolver records from the system default', () async {
    final RecordConfig config = await _startedConfig(
      () async => throw StateError('no inputs'),
    );

    expect(config.device, isNull);
  });
}
