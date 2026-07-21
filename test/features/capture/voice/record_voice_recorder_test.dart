import 'package:field_notes/features/capture/voice/record_voice_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
