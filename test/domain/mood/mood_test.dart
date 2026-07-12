import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/domain/mood/mood.dart';

void main() {
  group('Mood catalog', () {
    test('moodOrder is the ten moods in the locked sequence', () {
      expect(
        moodOrder.map((m) => m.id).toList(),
        <String>[
          'happy',
          'love',
          'warm',
          'grateful',
          'hopeful',
          'calm',
          'anxious',
          'tired',
          'sad',
          'angry',
        ],
      );
    });

    test('moodOrder matches the enum declaration order', () {
      expect(moodOrder, Mood.values);
    });

    test('each mood maps to its locked flower', () {
      expect(Mood.happy.flower, FlowerKind.peony);
      expect(Mood.love.flower, FlowerKind.rose);
      expect(Mood.warm.flower, FlowerKind.sunflower);
      expect(Mood.grateful.flower, FlowerKind.chrysanthemum);
      expect(Mood.hopeful.flower, FlowerKind.daffodil);
      expect(Mood.calm.flower, FlowerKind.lavender);
      expect(Mood.anxious.flower, FlowerKind.aster);
      expect(Mood.tired.flower, FlowerKind.poppy);
      expect(Mood.sad.flower, FlowerKind.bleedingHeart);
      expect(Mood.angry.flower, FlowerKind.redSpiderLily);
    });

    test('loved mood persists as "love" but displays as "Loved"', () {
      expect(Mood.love.id, 'love');
      expect(Mood.love.label, 'Loved');
    });

    test('no mood maps to an ambient-only flower', () {
      for (final mood in Mood.values) {
        expect(mood.flower.ambientOnly, isFalse, reason: mood.id);
      }
    });

    test('mood ids are unique', () {
      final ids = Mood.values.map((m) => m.id).toSet();
      expect(ids.length, Mood.values.length);
    });

    test('fromId round-trips every mood', () {
      for (final mood in Mood.values) {
        expect(Mood.fromId(mood.id), mood);
      }
    });

    test('fromId returns null for null, empty, and unknown ids', () {
      expect(Mood.fromId(null), isNull);
      expect(Mood.fromId(''), isNull);
      expect(Mood.fromId('loved'), isNull);
      expect(Mood.fromId('bogus'), isNull);
    });
  });
}
