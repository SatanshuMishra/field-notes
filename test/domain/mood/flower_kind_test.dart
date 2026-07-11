import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';

void main() {
  group('FlowerKind', () {
    test('has exactly twelve kinds', () {
      expect(FlowerKind.values.length, 12);
    });

    test('only wilting rose and thistle are ambient-only', () {
      final ambient = FlowerKind.values.where((f) => f.ambientOnly).toSet();
      expect(ambient, <FlowerKind>{FlowerKind.wiltingRose, FlowerKind.thistle});
    });

    test('the ten non-ambient kinds are selectable blooms', () {
      final selectable =
          FlowerKind.values.where((f) => !f.ambientOnly).toList();
      expect(selectable.length, 10);
    });

    test('labels match the spec for multiword blooms', () {
      expect(FlowerKind.bleedingHeart.label, 'Bleeding Heart');
      expect(FlowerKind.redSpiderLily.label, 'Red Spider Lily');
      expect(FlowerKind.wiltingRose.label, 'Wilting Rose');
      expect(FlowerKind.thistle.label, 'Thistle');
    });
  });
}
