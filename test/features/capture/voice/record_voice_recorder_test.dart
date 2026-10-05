import 'dart:io';

import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/voice/record_voice_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';

class _FakeAudioRecorder extends Fake implements AudioRecorder {
  String? _path;
  RecordConfig? startedWith;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    startedWith = config;
    _path = path;
    await File(path).writeAsBytes(<int>[1, 2, 3], flush: true);
  }

  @override
  Future<String?> stop() async => _path;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

File _capturedFile(VoiceRecording recording) =>
    (recording.media as CaptureFile).file;

void main() {
  group('voice recording format', () {
    test('records AAC-LC into an m4a container with the mp4 audio mime', () {
      expect(voiceRecordingEncoder, AudioEncoder.aacLc);
      expect(voiceRecordingExtension, 'm4a');
      expect(voiceRecordingMime, 'audio/mp4');
    });
  });

  group('voice recording configuration', () {
    test('starts recording as AAC-LC mono at 48 kbps', () async {
      final Directory temp =
          await Directory.systemTemp.createTemp('voice_config_test_');
      addTearDown(() => temp.delete(recursive: true));
      final _FakeAudioRecorder fake = _FakeAudioRecorder();
      final RecordVoiceRecorder recorder = RecordVoiceRecorder(
        recorder: fake,
        temporaryDirectory: () async => temp,
      );

      await recorder.start();

      final RecordConfig? config = fake.startedWith;
      expect(config, isNotNull);
      expect(config!.encoder, AudioEncoder.aacLc);
      expect(config.numChannels, 1);
      expect(config.bitRate, 48000);
    });
  });

  group('voiceRecordingFileName', () {
    test('builds a timestamped file name with the recording extension', () {
      expect(voiceRecordingFileName(1720000000000), 'voice_1720000000000.m4a');
    });

    test('produces distinct names for distinct timestamps', () {
      expect(
        voiceRecordingFileName(1) == voiceRecordingFileName(2),
        isFalse,
      );
    });
  });

  group('resolveVoiceRecordingPath', () {
    test('creates the target directory when it does not exist', () async {
      final Directory base =
          await Directory.systemTemp.createTemp('voice_recorder_test_');
      addTearDown(() => base.delete(recursive: true));
      final Directory missing =
          Directory(p.join(base.path, 'nested', 'caches', 'bundle'));
      expect(missing.existsSync(), isFalse);

      final String path = await resolveVoiceRecordingPath(missing, 1720000000000);

      expect(missing.existsSync(), isTrue);
      expect(path, p.join(missing.path, 'voice_1720000000000.m4a'));
    });

    test('returns a path inside an already-existing directory', () async {
      final Directory base =
          await Directory.systemTemp.createTemp('voice_recorder_test_');
      addTearDown(() => base.delete(recursive: true));

      final String path = await resolveVoiceRecordingPath(base, 42);

      expect(base.existsSync(), isTrue);
      expect(path, p.join(base.path, 'voice_42.m4a'));
    });
  });

  group('releasing saved memos', () {
    late Directory temp;
    late RecordVoiceRecorder recorder;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('voice_release_test_');
      recorder = RecordVoiceRecorder(
        recorder: _FakeAudioRecorder(),
        temporaryDirectory: () async => temp,
      );
    });

    tearDown(() => temp.delete(recursive: true));

    test('releasing a saved memo deletes the file the recorder created',
        () async {
      final File picked = File(p.join(temp.path, 'picked.m4a'))
        ..writeAsBytesSync(<int>[9, 9]);

      await recorder.start();
      final VoiceRecording recording = await recorder.stop();
      final File captured = _capturedFile(recording);

      expect(p.isWithin(temp.path, captured.path), isTrue);
      expect(captured.existsSync(), isTrue);

      await recorder.releaseSaved(
        VoiceRecording(
          media: CaptureFile(file: picked, mime: voiceRecordingMime),
          durationMs: 1,
        ),
      );

      expect(picked.existsSync(), isTrue);
      expect(captured.existsSync(), isTrue);

      await recorder.releaseSaved(recording);

      expect(captured.existsSync(), isFalse);
      expect(picked.existsSync(), isTrue);
    });

    test('releasing an earlier stop keeps the file a later stop still holds',
        () async {
      await recorder.start();
      final VoiceRecording first = await recorder.stop();
      final VoiceRecording retry = await recorder.stop();
      final File captured = _capturedFile(retry);

      expect(_capturedFile(first).path, captured.path);

      await recorder.releaseSaved(first);

      expect(captured.existsSync(), isTrue);

      await recorder.releaseSaved(retry);

      expect(captured.existsSync(), isFalse);
    });
  });
}
