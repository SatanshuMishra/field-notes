import 'dart:io';

import 'package:field_notes/features/capture/voice/record_voice_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';

void main() {
  group('voice recording format', () {
    test('records AAC-LC into an m4a container with the mp4 audio mime', () {
      expect(voiceRecordingEncoder, AudioEncoder.aacLc);
      expect(voiceRecordingExtension, 'm4a');
      expect(voiceRecordingMime, 'audio/mp4');
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
}
