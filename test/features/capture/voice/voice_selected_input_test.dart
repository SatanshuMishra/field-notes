import 'dart:io';

import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/voice/record_voice_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

class _FakeAudioRecorder extends Fake implements AudioRecorder {
  RecordConfig? startedWith;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    startedWith = config;
  }

  @override
  Future<void> dispose() async {}
}

Future<RecordConfig> _startedConfig(
  Future<AudioInput> Function() resolve,
) async {
  final Directory temp = await Directory.systemTemp.createTemp(
    'voice_input_test_',
  );
  addTearDown(() => temp.delete(recursive: true));
  final _FakeAudioRecorder fake = _FakeAudioRecorder();
  final RecordVoiceRecorder recorder = RecordVoiceRecorder(
    recorder: fake,
    temporaryDirectory: () async => temp,
    resolveInput: resolve,
  );
  await recorder.start();
  return fake.startedWith!;
}

void main() {
  test('a voice take records from the chosen microphone', () async {
    final RecordConfig config = await _startedConfig(
      () async => const AudioInput(id: 'b', label: 'CORSAIR HS80 MAX'),
    );

    expect(config.device?.id, 'b');
    expect(config.device?.label, 'CORSAIR HS80 MAX');
    expect(config.encoder, AudioEncoder.aacLc);
    expect(config.numChannels, 1);
    expect(config.bitRate, 48000);
  });

  test('a voice take with no choice records from the system default', () async {
    final RecordConfig config = await _startedConfig(
      () async => const AudioInput(id: null, label: 'System default'),
    );

    expect(config.device, isNull);
    expect(config.encoder, AudioEncoder.aacLc);
    expect(config.numChannels, 1);
    expect(config.bitRate, 48000);
  });

  test('a failing resolver records from the system default', () async {
    final RecordConfig config = await _startedConfig(
      () async => throw StateError('no inputs'),
    );

    expect(config.device, isNull);
  });
}
