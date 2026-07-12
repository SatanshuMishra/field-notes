import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/domain/models/models.dart';

void main() {
  group('EntryPhoto', () {
    EntryPhoto build({int? deletedAt}) => EntryPhoto(
          id: 'ph1',
          entryId: 'en1',
          mediaId: 'sha256-abc',
          sortOrder: 0,
          createdAt: 1720000000000,
          updatedAt: 1720000000000,
          deletedAt: deletedAt,
        );

    test('stores every field', () {
      final photo = build();
      expect(photo.id, 'ph1');
      expect(photo.entryId, 'en1');
      expect(photo.mediaId, 'sha256-abc');
      expect(photo.sortOrder, 0);
      expect(photo.createdAt, 1720000000000);
      expect(photo.updatedAt, 1720000000000);
      expect(photo.deletedAt, isNull);
    });

    test('isDeleted reflects the tombstone', () {
      expect(build().isDeleted, isFalse);
      expect(build(deletedAt: 1720000009999).isDeleted, isTrue);
    });

    test('value equality holds for identical fields', () {
      expect(build(), equals(build()));
      expect(build().hashCode, equals(build().hashCode));
    });

    test('a tombstoned photo differs from a live one', () {
      expect(build(), isNot(equals(build(deletedAt: 1720000009999))));
    });
  });
}
