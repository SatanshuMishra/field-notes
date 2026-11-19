import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/flowers/bloom_part.dart';
import 'package:field_notes/design/flowers/garden_plant_geometry.dart';
import 'package:field_notes/features/opening/opening_plan.dart';

const double _exact = 1e-9;

final List<BloomDisc> _discs = peonyPlantParts.whereType<BloomDisc>().toList(
  growable: false,
);

const Map<OpeningInk, int> _discOf = <OpeningInk, int>{
  OpeningInk.disc0: 0,
  OpeningInk.disc1: 1,
  OpeningInk.disc2: 2,
  OpeningInk.disc3: 3,
  OpeningInk.disc4: 4,
  OpeningInk.disc5: 5,
};

double _distanceTo(Offset point, BloomDisc disc) =>
    (point - Offset(disc.cx, disc.cy)).distance;

double _lastEnd(OpeningPlan plan, Set<OpeningInk> inks) => plan.strokes
    .where((OpeningStroke stroke) => inks.contains(stroke.ink))
    .map((OpeningStroke stroke) => stroke.end)
    .reduce(math.max);

void main() {
  test('the pen inks the core, the crease, the petals front to back, the stem, '
      'the mound and tufts, then each leaf and its vein', () {
    final OpeningPlan plan = openingPlan();

    expect(
      plan.strokes.map((OpeningStroke stroke) => stroke.ink).toList(),
      <OpeningInk>[
        OpeningInk.disc5,
        OpeningInk.crease,
        OpeningInk.disc3,
        OpeningInk.disc4,
        OpeningInk.disc1,
        OpeningInk.disc2,
        OpeningInk.disc0,
        OpeningInk.stem,
        OpeningInk.mound,
        OpeningInk.tuft,
        OpeningInk.tuft,
        OpeningInk.tuft,
        OpeningInk.tuft,
        OpeningInk.leftLeaf,
        OpeningInk.leftVein,
        OpeningInk.rightLeaf,
        OpeningInk.rightVein,
      ],
    );
    expect(plan.strokes.first.start, closeTo(0.05, _exact));
  });

  test('one pen draws one stroke at a time', () {
    final List<OpeningStroke> strokes = openingPlan().strokes;

    for (int i = 1; i < strokes.length; i++) {
      final OpeningStroke previous = strokes[i - 1];
      final double lift = previous.ink == OpeningInk.tuft ? 0.012 : 0.022;
      expect(
        strokes[i].start,
        closeTo(previous.end + lift, _exact),
        reason: 'stroke $i (${strokes[i].ink})',
      );
    }
  });

  test('no petal line is drawn where a petal in front covers it', () {
    final List<OpeningStroke> discStrokes = openingPlan().strokes
        .where((OpeningStroke stroke) => _discOf.containsKey(stroke.ink))
        .toList();
    expect(discStrokes, hasLength(6));

    for (final OpeningStroke stroke in discStrokes) {
      final int index = _discOf[stroke.ink]!;
      for (int later = index + 1; later < _discs.length; later++) {
        for (final Offset point in stroke.points) {
          expect(
            _distanceTo(point, _discs[later]),
            greaterThanOrEqualTo(_discs[later].r - 0.1),
            reason: '${stroke.ink} at $point lies inside disc$later',
          );
        }
      }
    }
  });

  test('every visible petal outline is drawn', () {
    final List<OpeningStroke> strokes = openingPlan().strokes;

    for (int index = 0; index < _discs.length; index++) {
      final BloomDisc disc = _discs[index];
      final List<Offset> drawn = <Offset>[
        for (final OpeningStroke stroke in strokes)
          if (_discOf[stroke.ink] == index) ...stroke.points,
      ];
      final List<Offset> showing =
          <Offset>[
            for (int k = 0; k < 720; k++)
              Offset(
                disc.cx + disc.r * math.cos(2 * math.pi * k / 720),
                disc.cy + disc.r * math.sin(2 * math.pi * k / 720),
              ),
          ].where((Offset point) {
            for (int later = index + 1; later < _discs.length; later++) {
              if (_distanceTo(point, _discs[later]) < _discs[later].r + 0.5) {
                return false;
              }
            }
            return true;
          }).toList();
      expect(showing, isNotEmpty, reason: 'disc$index shows nothing');

      final int covered = showing
          .where(
            (Offset point) =>
                drawn.any((Offset ink) => (ink - point).distance <= 0.6),
          )
          .length;
      expect(
        covered / showing.length,
        greaterThanOrEqualTo(0.97),
        reason: 'disc$index draws $covered of ${showing.length} showing points',
      );
    }
  });

  test('the stem line stops at the flower and at the soil', () {
    final OpeningStroke stem = openingPlan().strokes.singleWhere(
      (OpeningStroke stroke) => stroke.ink == OpeningInk.stem,
    );

    for (final Offset point in stem.points) {
      expect(point.dy, lessThan(184.2), reason: '$point reaches the soil');
      for (final BloomDisc disc in _discs) {
        expect(
          _distanceTo(point, disc),
          greaterThanOrEqualTo(disc.r + 1),
          reason: '$point reaches the flower',
        );
      }
    }
    expect(stem.points.first.dy, lessThan(stem.points.last.dy));
  });

  test('every stroke moves at one pen speed', () {
    for (final OpeningStroke stroke in openingPlan().strokes) {
      double summed = 0;
      for (int i = 1; i < stroke.points.length; i++) {
        summed += (stroke.points[i] - stroke.points[i - 1]).distance;
      }
      expect(stroke.length, closeTo(summed, 1e-6), reason: '${stroke.ink}');
      expect(
        stroke.end - stroke.start,
        closeTo(math.max(0.035, stroke.length / 1250), _exact),
        reason: '${stroke.ink}',
      );
    }
  });

  test('the colour of each part washes in after the pen leaves it', () {
    final OpeningPlan plan = openingPlan();
    final Map<OpeningInk, Set<OpeningInk>> owned =
        <OpeningInk, Set<OpeningInk>>{
          OpeningInk.disc0: <OpeningInk>{OpeningInk.disc0},
          OpeningInk.disc1: <OpeningInk>{OpeningInk.disc1},
          OpeningInk.disc2: <OpeningInk>{OpeningInk.disc2},
          OpeningInk.disc3: <OpeningInk>{OpeningInk.disc3},
          OpeningInk.disc4: <OpeningInk>{OpeningInk.disc4},
          OpeningInk.disc5: <OpeningInk>{OpeningInk.disc5, OpeningInk.crease},
          OpeningInk.leftLeaf: <OpeningInk>{
            OpeningInk.leftLeaf,
            OpeningInk.leftVein,
          },
          OpeningInk.rightLeaf: <OpeningInk>{
            OpeningInk.rightLeaf,
            OpeningInk.rightVein,
          },
          OpeningInk.mound: <OpeningInk>{OpeningInk.mound, OpeningInk.tuft},
        };

    expect(plan.washes.keys.toSet(), owned.keys.toSet());
    for (final MapEntry<OpeningInk, Set<OpeningInk>> part in owned.entries) {
      final OpeningSpan wash = plan.washes[part.key]!;
      expect(
        wash.start,
        closeTo(_lastEnd(plan, part.value) + 0.04, _exact),
        reason: '${part.key}',
      );
      expect(
        wash.end - wash.start,
        closeTo(0.36, _exact),
        reason: '${part.key}',
      );
    }
  });

  test(
    'the wind starts as the last colour settles and curls in three gusts',
    () {
      final OpeningPlan plan = openingPlan();
      final double lastWashEnd = plan.washes.values
          .map((OpeningSpan wash) => wash.end)
          .reduce(math.max);

      expect(plan.windStart, closeTo(lastWashEnd - 0.3, _exact));
      expect(plan.gustStarts, hasLength(3));
      expect(plan.gustStarts[0], closeTo(plan.windStart, _exact));
      expect(plan.gustStarts[1], closeTo(plan.windStart + 0.09, _exact));
      expect(plan.gustStarts[2], closeTo(plan.windStart + 0.18, _exact));
      expect(plan.windArrival, closeTo(plan.windStart + 0.33, _exact));
      expect(plan.bend.start, closeTo(plan.windArrival - 0.08, _exact));
      expect(plan.bend.end, closeTo(plan.windArrival + 0.25, _exact));
    },
  );

  test('the petals and leaves shed in order', () {
    final OpeningPlan plan = openingPlan();
    final double s = plan.windArrival + 0.1;
    final Map<OpeningInk, double> expected = <OpeningInk, double>{
      OpeningInk.disc1: s,
      OpeningInk.disc0: s + 0.06,
      OpeningInk.disc3: s + 0.12,
      OpeningInk.disc2: s + 0.18,
      OpeningInk.disc4: s + 0.24,
      OpeningInk.disc5: s + 0.3,
      OpeningInk.leftLeaf: s + 0.22,
      OpeningInk.rightLeaf: s + 0.33,
    };

    expect(plan.sheds.keys.toSet(), expected.keys.toSet());
    for (final MapEntry<OpeningInk, double> shed in expected.entries) {
      expect(
        plan.sheds[shed.key],
        closeTo(shed.value, _exact),
        reason: '${shed.key}',
      );
    }
    expect(plan.bendRelease, closeTo(s + 0.33 + 0.06, _exact));
  });

  test('Today is revealed in under three seconds', () {
    final OpeningPlan plan = openingPlan();
    final double lastShed = plan.sheds.values.reduce(math.max);

    expect(plan.reveal.start, closeTo(lastShed + 0.08, _exact));
    expect(plan.reveal.end, closeTo(lastShed + 0.62, _exact));
    expect(plan.reveal.end, inInclusiveRange(2.4, 2.9));
    expect(plan.total, closeTo(plan.reveal.end + 0.55, _exact));
  });

  test(
    'reduce motion draws everything at once and crossfades in 0.3 seconds',
    () {
      final OpeningPlan moving = openingPlan();
      final OpeningPlan still = openingPlan(still: true);

      expect(still.still, isTrue);
      expect(still.strokes, hasLength(moving.strokes.length));
      for (int i = 0; i < still.strokes.length; i++) {
        expect(still.strokes[i].ink, moving.strokes[i].ink);
        expect(still.strokes[i].points, moving.strokes[i].points);
        expect(still.strokes[i].start, 0);
        expect(still.strokes[i].end, 0);
      }
      expect(still.washes.keys.toSet(), moving.washes.keys.toSet());
      for (final OpeningSpan wash in still.washes.values) {
        expect(wash.start, 0);
        expect(wash.end, 0);
      }
      expect(still.gustStarts, isEmpty);
      expect(still.sheds, isEmpty);
      expect(still.reveal.start, closeTo(0.4, _exact));
      expect(still.reveal.end, closeTo(0.7, _exact));
      expect(still.total, closeTo(0.7, _exact));
    },
  );
}
