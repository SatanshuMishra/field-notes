import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/notes/notes.dart';

const double _em = 16;

PhotoPlan _plan(
  PhotoSize size, {
  double measure = 320,
  double em = _em,
  double? aspect = 3 / 2,
  PhotoSide side = PhotoSide.right,
  bool nextIsParagraph = false,
}) {
  return planFloat(
    measure: measure,
    em: em,
    side: side,
    size: size,
    aspect: aspect,
    nextIsParagraph: nextIsParagraph,
  );
}

PhotoPlan _float(
  PhotoSize size, {
  double measure = 560,
  double em = _em,
  double? aspect = 3 / 2,
}) =>
    _plan(
      size,
      measure: measure,
      em: em,
      aspect: aspect,
      nextIsParagraph: true,
    );

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

    test(
        'stacks whenever the next block is not a paragraph, whatever the '
        'measure', () {
      for (final double measure in <double>[320, 360, 462.4, 560, 840]) {
        for (final PhotoSize size in PhotoSize.values) {
          expect(_plan(size, measure: measure).isStacked, isTrue);
          expect(
            planFloat(
              measure: measure,
              em: _em,
              side: PhotoSide.right,
              size: size,
              aspect: 3 / 2,
            ),
            _plan(size, measure: measure),
          );
        }
      }
    });

    test('a stacked plan gives the text the whole measure', () {
      final PhotoPlan plan = _plan(PhotoSize.medium);

      expect(plan.band, 320);
      expect(plan.gutter, _em);
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

  group('planFloat float', () {
    test('sizes float in em: Small 8.5, Medium 12, Large 14.5, Full never', () {
      expect(PhotoSize.small.floatEm, 8.5);
      expect(PhotoSize.medium.floatEm, 12);
      expect(PhotoSize.large.floatEm, 14.5);
      expect(PhotoSize.full.floatEm, isNull);
    });

    test('Medium floats at 192pt beside a 352pt band on a 560 measure', () {
      final PhotoPlan plan = _float(PhotoSize.medium);

      expect(plan.isStacked, isFalse);
      expect(plan.width, 192);
      expect(plan.height, 128);
      expect(plan.gutter, _em);
      expect(plan.band, closeTo(352, 1e-9));
    });

    test(
        'is scale invariant: 1.5x text on an 840 measure floats Medium at '
        '288 beside 528', () {
      final PhotoPlan plan = _float(PhotoSize.medium, measure: 840, em: 24);

      expect(plan.isStacked, isFalse);
      expect(plan.width, closeTo(288, 1e-9));
      expect(plan.band, closeTo(528, 1e-9));
    });

    test('shrinks before it demotes: 192 holds to 518.4, then 136 at 462.4',
        () {
      expect(
          _float(PhotoSize.medium, measure: 518.4).width, closeTo(192, 1e-9));
      expect(_float(PhotoSize.medium, measure: 490).width,
          closeTo(490 - 20.4 * _em, 1e-9));
      expect(
          _float(PhotoSize.medium, measure: 462.41).width, closeTo(136, 0.02));
      expect(_float(PhotoSize.medium, measure: 462.39).isStacked, isTrue);
    });

    test('a shrinking photo keeps the band at the 19.4 em residual', () {
      for (final double measure in <double>[462.41, 480, 500, 518.4]) {
        expect(
          _float(PhotoSize.large, measure: measure).band,
          closeTo(photoBandResidualEm * _em, 1e-9),
        );
      }
    });

    test('Full never floats', () {
      for (final double measure in <double>[560, 840, 2000]) {
        expect(_float(PhotoSize.full, measure: measure).isStacked, isTrue);
      }
    });

    test('missing or unreadable dimensions never float', () {
      for (final double? aspect in <double?>[
        null,
        0,
        -1,
        double.nan,
        double.infinity,
      ]) {
        final PhotoPlan plan = _float(PhotoSize.medium, aspect: aspect);
        expect(plan.isStacked, isTrue, reason: '$aspect');
        expect(plan.width, closeTo(0.75 * 560, 1e-9));
      }
    });

    test('a panorama too short to hold one line of text stacks', () {
      expect(photoLineEm, 1.6);
      expect(_float(PhotoSize.medium, aspect: 7.4).isStacked, isFalse);
      expect(_float(PhotoSize.medium, aspect: 7.6).isStacked, isTrue);
      expect(_float(PhotoSize.small, aspect: 5).isStacked, isFalse);
      expect(_float(PhotoSize.small, aspect: 6).isStacked, isTrue);
      expect(_float(PhotoSize.large, aspect: 6).isStacked, isFalse);
    });

    test('a floated portrait is clamped to 1.6 times its width', () {
      final PhotoPlan plan = _float(PhotoSize.medium, aspect: 9 / 16);

      expect(plan.isStacked, isFalse);
      expect(plan.height, closeTo(photoHeightClamp * 192, 1e-9));
    });

    test('Side applies wherever the plan could float', () {
      expect(_float(PhotoSize.medium).sideApplies, isTrue);
      expect(_float(PhotoSize.medium, measure: 400).sideApplies, isFalse);
    });
  });

  group('noteMeasureFor', () {
    test('is the width up to 35 em and pins there', () {
      expect(noteMeasureFor(maxWidth: 320, em: _em), 320);
      expect(noteMeasureFor(maxWidth: 1280, em: _em), 560);
      expect(noteMeasureFor(maxWidth: 1280, em: 24), 840);
      expect(noteMeasureFor(maxWidth: double.infinity, em: _em), 560);
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
