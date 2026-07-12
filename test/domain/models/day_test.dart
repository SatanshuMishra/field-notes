import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/domain/models/models.dart';

void main() {
  group('Day', () {
    Day build({Mood? mood, int? deletedAt}) => Day(
          id: 'dy1',
          date: '2026-07-11',
          mood: mood,
          createdAt: 1720000000000,
          updatedAt: 1720000000000,
          deletedAt: deletedAt,
        );

    test('stores every field and defaults mood and tombstone to null', () {
      final day = build();
      expect(day.id, 'dy1');
      expect(day.date, '2026-07-11');
      expect(day.mood, isNull);
      expect(day.createdAt, 1720000000000);
      expect(day.updatedAt, 1720000000000);
      expect(day.deletedAt, isNull);
    });

    test('references a Mood from the mood catalog through the barrel', () {
      final day = build(mood: Mood.happy);
      expect(day.mood, Mood.happy);
      expect(day.mood!.flower, FlowerKind.peony);
    });

    test('isDeleted reflects the tombstone', () {
      expect(build().isDeleted, isFalse);
      expect(build(deletedAt: 1720000009999).isDeleted, isTrue);
    });

    test('value equality holds for identical fields', () {
      expect(build(mood: Mood.calm), equals(build(mood: Mood.calm)));
      expect(
        build(mood: Mood.calm).hashCode,
        equals(build(mood: Mood.calm).hashCode),
      );
    });

    test('a mood change breaks equality', () {
      expect(build(mood: Mood.calm), isNot(equals(build(mood: Mood.happy))));
      expect(build(mood: Mood.calm), isNot(equals(build())));
    });

    test('a tombstone breaks equality', () {
      expect(build(), isNot(equals(build(deletedAt: 1720000009999))));
    });
  });
}
