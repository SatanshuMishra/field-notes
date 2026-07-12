import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/domain/models/models.dart';

void main() {
  group('EntryType', () {
    test('has exactly three types', () {
      expect(EntryType.values.length, 3);
    });

    test('ids match the persisted entries.type values', () {
      expect(EntryType.text.id, 'text');
      expect(EntryType.voice.id, 'voice');
      expect(EntryType.video.id, 'video');
    });

    test('ids are unique', () {
      final ids = EntryType.values.map((t) => t.id).toSet();
      expect(ids.length, EntryType.values.length);
    });

    test('fromId round-trips every type', () {
      for (final type in EntryType.values) {
        expect(EntryType.fromId(type.id), type);
      }
    });

    test('fromId returns null for null, empty, and unknown ids', () {
      expect(EntryType.fromId(null), isNull);
      expect(EntryType.fromId(''), isNull);
      expect(EntryType.fromId('image'), isNull);
      expect(EntryType.fromId('TEXT'), isNull);
    });
  });
}
