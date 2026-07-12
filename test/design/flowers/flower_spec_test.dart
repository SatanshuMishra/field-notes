import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/design/flowers/bloom_style.dart';
import 'package:field_notes/design/flowers/flower_spec.dart';
import 'package:field_notes/domain/mood/mood.dart';

void main() {
  group('flowerSpecFor', () {
    test('returns a spec keyed to every FlowerKind', () {
      for (final kind in FlowerKind.values) {
        expect(flowerSpecFor(kind).kind, kind, reason: kind.name);
      }
    });

    test('every spec carries drawable parameters', () {
      for (final kind in FlowerKind.values) {
        final spec = flowerSpecFor(kind);
        expect(spec.petalCount, greaterThan(0), reason: kind.name);
        expect(spec.petalLength, greaterThan(0), reason: kind.name);
        expect(spec.petalWidth, greaterThan(0), reason: kind.name);
        expect(spec.centerRadius, greaterThanOrEqualTo(0), reason: kind.name);
      }
    });

    test('only the wilting rose droops', () {
      for (final kind in FlowerKind.values) {
        expect(
          flowerSpecFor(kind).droop,
          kind == FlowerKind.wiltingRose,
          reason: kind.name,
        );
      }
    });

    test('bleeding heart uses the heart-pendant silhouette', () {
      expect(flowerSpecFor(FlowerKind.bleedingHeart).style,
          BloomStyle.heartPendants);
      expect(flowerSpecFor(FlowerKind.lavender).style, BloomStyle.spike);
      expect(flowerSpecFor(FlowerKind.thistle).style, BloomStyle.puff);
      expect(flowerSpecFor(FlowerKind.redSpiderLily).style,
          BloomStyle.spiderPetals);
    });

    test('every selectable mood resolves to a spec for its flower', () {
      for (final mood in Mood.values) {
        expect(flowerSpecFor(mood.flower).kind, mood.flower, reason: mood.id);
      }
    });
  });
}
