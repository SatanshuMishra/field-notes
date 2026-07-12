import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/domain/models/models.dart';

void main() {
  group('Entry', () {
    Entry buildText({int? deletedAt}) => Entry(
          id: 'en1',
          dayId: 'dy1',
          type: EntryType.text,
          textContent: 'a good day',
          createdAt: 1720000000000,
          updatedAt: 1720000000000,
          deletedAt: deletedAt,
        );

    test('stores a text entry with null media fields', () {
      final entry = buildText();
      expect(entry.id, 'en1');
      expect(entry.dayId, 'dy1');
      expect(entry.type, EntryType.text);
      expect(entry.textContent, 'a good day');
      expect(entry.mediaId, isNull);
      expect(entry.thumbnailMediaId, isNull);
      expect(entry.durationMs, isNull);
      expect(entry.deletedAt, isNull);
    });

    test('stores a video entry with media, thumbnail, and duration', () {
      const entry = Entry(
        id: 'en2',
        dayId: 'dy1',
        type: EntryType.video,
        mediaId: 'sha256-vid',
        thumbnailMediaId: 'sha256-thumb',
        durationMs: 42000,
        createdAt: 1720000000000,
        updatedAt: 1720000000000,
      );
      expect(entry.type, EntryType.video);
      expect(entry.mediaId, 'sha256-vid');
      expect(entry.thumbnailMediaId, 'sha256-thumb');
      expect(entry.durationMs, 42000);
      expect(entry.textContent, isNull);
    });

    test('isDeleted reflects the tombstone', () {
      expect(buildText().isDeleted, isFalse);
      expect(buildText(deletedAt: 1720000009999).isDeleted, isTrue);
    });

    test('value equality holds for identical fields', () {
      expect(buildText(), equals(buildText()));
      expect(buildText().hashCode, equals(buildText().hashCode));
    });

    test('differs on type', () {
      expect(
        buildText(),
        isNot(equals(const Entry(
          id: 'en1',
          dayId: 'dy1',
          type: EntryType.voice,
          textContent: 'a good day',
          createdAt: 1720000000000,
          updatedAt: 1720000000000,
        ))),
      );
    });

    test('differs on the tombstone', () {
      expect(
        buildText(),
        isNot(equals(buildText(deletedAt: 1720000009999))),
      );
    });
  });
}
