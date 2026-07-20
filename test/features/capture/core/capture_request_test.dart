import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CaptureRequest', () {
    test('copies the caller photo list so later mutation cannot leak in', () {
      final List<CaptureMedia> source = <CaptureMedia>[
        const CaptureBytes(bytes: <int>[1, 2], mime: 'image/png'),
      ];
      final TextCaptureRequest request = TextCaptureRequest(
        date: '2026-07-19',
        text: 'a note',
        photos: source,
      );

      source.add(const CaptureBytes(bytes: <int>[3, 4], mime: 'image/png'));

      expect(request.photos, hasLength(1));
    });

    test('exposes an unmodifiable photo list', () {
      final TextCaptureRequest request = TextCaptureRequest(
        date: '2026-07-19',
        text: 'a note',
      );

      expect(
        () => request.photos
            .add(const CaptureBytes(bytes: <int>[9], mime: 'image/png')),
        throwsUnsupportedError,
      );
    });

    test('each variant reports the entry type it will write', () {
      expect(
        TextCaptureRequest(date: '2026-07-19', text: 'a note').type,
        EntryType.text,
      );
      expect(
        VoiceCaptureRequest(
          date: '2026-07-19',
          audio: const CaptureBytes(bytes: <int>[1], mime: 'audio/m4a'),
          durationMs: 1000,
        ).type,
        EntryType.voice,
      );
      expect(
        VideoCaptureRequest(
          date: '2026-07-19',
          video: const CaptureBytes(bytes: <int>[1], mime: 'video/mp4'),
          durationMs: 1000,
        ).type,
        EntryType.video,
      );
    });
  });
}
