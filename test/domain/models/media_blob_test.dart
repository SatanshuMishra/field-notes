import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/domain/models/models.dart';

void main() {
  group('MediaBlob', () {
    MediaBlob build() => const MediaBlob(
          id: 'sha256-abc',
          relPath: 'media/ab/abc.jpg',
          mime: 'image/jpeg',
          kind: MediaKind.photo,
          bytes: 2048,
          width: 800,
          height: 600,
          createdAt: 1720000000000,
        );

    test('stores every field', () {
      final blob = build();
      expect(blob.id, 'sha256-abc');
      expect(blob.relPath, 'media/ab/abc.jpg');
      expect(blob.mime, 'image/jpeg');
      expect(blob.kind, MediaKind.photo);
      expect(blob.bytes, 2048);
      expect(blob.width, 800);
      expect(blob.height, 600);
      expect(blob.durationMs, isNull);
      expect(blob.createdAt, 1720000000000);
    });

    test('optional dimensions and duration default to null', () {
      const blob = MediaBlob(
        id: 'sha256-audio',
        relPath: 'media/aa/aa.m4a',
        mime: 'audio/mp4',
        kind: MediaKind.audio,
        bytes: 1024,
        createdAt: 1720000000001,
      );
      expect(blob.width, isNull);
      expect(blob.height, isNull);
      expect(blob.durationMs, isNull);
    });

    test('value equality holds for identical fields', () {
      expect(build(), equals(build()));
      expect(build().hashCode, equals(build().hashCode));
    });

    test('differs when the id differs', () {
      expect(
        build(),
        isNot(equals(const MediaBlob(
          id: 'sha256-other',
          relPath: 'media/ab/abc.jpg',
          mime: 'image/jpeg',
          kind: MediaKind.photo,
          bytes: 2048,
          width: 800,
          height: 600,
          createdAt: 1720000000000,
        ))),
      );
    });

    test('differs when the kind differs', () {
      expect(
        build(),
        isNot(equals(const MediaBlob(
          id: 'sha256-abc',
          relPath: 'media/ab/abc.jpg',
          mime: 'image/jpeg',
          kind: MediaKind.video,
          bytes: 2048,
          width: 800,
          height: 600,
          createdAt: 1720000000000,
        ))),
      );
    });
  });
}
