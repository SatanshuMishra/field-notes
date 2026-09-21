import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/notes/notes.dart';

const double _em = 16;

PhotoPlan _plan(
  PhotoSize size, {
  double measure = 320,
  double em = _em,
  double? aspect = 3 / 2,
  PhotoSide side = PhotoSide.right,
}) {
  return planFloat(
    measure: measure,
    em: em,
    side: side,
    size: size,
    aspect: aspect,
  );
}

void main() {
  group('planFloat block width', () {
    test('is the size fraction of the measure, never an em value', () {
      expect(_plan(PhotoSize.small).width, closeTo(0.55 * 320, 1e-9));
      expect(_plan(PhotoSize.medium).width, closeTo(0.75 * 320, 1e-9));
      expect(_plan(PhotoSize.large).width, closeTo(0.92 * 320, 1e-9));
      expect(_plan(PhotoSize.full).width, closeTo(320, 1e-9));
    });

    test('gives four visibly distinct widths at a 320pt phone measure', () {
      final List<double> widths = <double>[
        for (final PhotoSize size in PhotoSize.values) _plan(size).width,
      ];

      expect(widths.toSet(), hasLength(4));
      for (int i = 1; i < widths.length; i++) {
        expect(widths[i] - widths[i - 1], greaterThan(20));
      }
      expect(widths.where((double width) => width == 262), isEmpty);
    });

    test('always stacks in this unit, whatever the measure', () {
      for (final double measure in <double>[320, 360, 462.4, 560, 840]) {
        for (final PhotoSize size in PhotoSize.values) {
          expect(_plan(size, measure: measure).isStacked, isTrue);
        }
      }
    });
  });

  group('planFloat block height', () {
    test('follows the aspect ratio for a landscape photo', () {
      final PhotoPlan plan = _plan(PhotoSize.full, aspect: 2);

      expect(plan.height, closeTo(160, 1e-9));
    });

    test('clamps a tall portrait photo to 1.6 times its width', () {
      final PhotoPlan plan = _plan(PhotoSize.medium, aspect: 9 / 16);

      expect(plan.height, closeTo(photoHeightClamp * plan.width, 1e-9));
      expect(plan.height, lessThan(plan.width / (9 / 16)));
    });

    test('falls back to 3:2 when the dimensions are unknown or nonsense', () {
      for (final double? aspect in <double?>[null, 0, -1, double.nan]) {
        final PhotoPlan plan = _plan(PhotoSize.full, aspect: aspect);
        expect(plan.height, closeTo(320 / photoFallbackAspect, 1e-9));
      }
    });

    test('an unbounded or broken measure plans an empty box, not a crash', () {
      final PhotoPlan plan = _plan(PhotoSize.full, measure: double.infinity);

      expect(plan.width, 0);
      expect(plan.height, 0);
      expect(plan.measureCanFloat, isFalse);
    });
  });

  group('canFloatAt', () {
    test('a phone measure cannot float and a desktop measure can', () {
      expect(canFloatAt(measure: 320, em: _em), isFalse);
      expect(canFloatAt(measure: 360, em: _em), isFalse);
      expect(canFloatAt(measure: 560, em: _em), isTrue);
    });

    test('the gate sits at 28.9 em of measure', () {
      expect(canFloatAt(measure: 28.9 * _em + 0.01, em: _em), isTrue);
      expect(canFloatAt(measure: 28.9 * _em - 0.01, em: _em), isFalse);
    });

    test('is scale invariant: 1.5x text on a 1280 window still floats', () {
      expect(canFloatAt(measure: 840, em: 24), isTrue);
      expect(canFloatAt(measure: 560, em: 24), isFalse);
    });

    test('the plan carries the same answer the gate gives', () {
      expect(_plan(PhotoSize.medium, measure: 320).measureCanFloat, isFalse);
      expect(_plan(PhotoSize.medium, measure: 560).measureCanFloat, isTrue);
    });

    test('Side applies only where the measure floats and the size is not Full',
        () {
      expect(_plan(PhotoSize.medium, measure: 320).sideApplies, isFalse);
      expect(_plan(PhotoSize.medium, measure: 560).sideApplies, isTrue);
      expect(_plan(PhotoSize.full, measure: 560).sideApplies, isFalse);
    });
  });

  group('photoAspectOf', () {
    test('reads real dimensions and rejects missing ones', () {
      expect(photoAspectOf(1200, 800), 1.5);
      expect(photoAspectOf(null, 800), isNull);
      expect(photoAspectOf(1200, 0), isNull);
    });
  });
}
