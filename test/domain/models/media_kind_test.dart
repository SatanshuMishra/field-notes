import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/domain/models/models.dart';

void main() {
  group('MediaKind', () {
    test('has exactly three kinds', () {
      expect(MediaKind.values.length, 3);
    });

    test('ids match the persisted media_blobs.kind values', () {
      expect(MediaKind.photo.id, 'photo');
      expect(MediaKind.audio.id, 'audio');
      expect(MediaKind.video.id, 'video');
    });

    test('ids are unique', () {
      final ids = MediaKind.values.map((k) => k.id).toSet();
      expect(ids.length, MediaKind.values.length);
    });

    test('fromId round-trips every kind', () {
      for (final kind in MediaKind.values) {
        expect(MediaKind.fromId(kind.id), kind);
      }
    });

    test('fromId returns null for null, empty, and unknown ids', () {
      expect(MediaKind.fromId(null), isNull);
      expect(MediaKind.fromId(''), isNull);
      expect(MediaKind.fromId('gif'), isNull);
      expect(MediaKind.fromId('Photo'), isNull);
    });
  });
}
