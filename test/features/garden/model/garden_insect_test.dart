import 'package:field_notes/design/flowers/garden_art_colors.dart';
import 'package:field_notes/features/garden/model/garden_insect.dart';
import 'package:flutter_test/flutter_test.dart';

void _expectOffset(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 1e-9));
  expect(actual.dy, closeTo(expected.dy, 1e-9));
}

void main() {
  test('desktop flies two butterflies and a bee, phone one of each', () {
    expect(desktopGardenInsects.map((GardenInsect i) => i.kind), <Object>[
      GardenInsectKind.butterfly,
      GardenInsectKind.butterfly,
      GardenInsectKind.bee,
    ]);
    expect(
      desktopGardenInsects.map(
        (GardenInsect i) => (i.anchor, i.size, i.loop, i.period),
      ),
      <Object>[
        (const Offset(0.11, 0.14), 24.0, flightLoopA, 15.0),
        (const Offset(0.84, 0.28), 22.0, flightLoopB, 18.0),
        (const Offset(0.46, 0.50), 18.0, flightLoopC, 9.0),
      ],
    );
    expect(desktopGardenInsects[0].wing, GardenArtColors.butterflyCoral);
    expect(desktopGardenInsects[1].wing, GardenArtColors.butterflyLilac);

    expect(
      phoneGardenInsects.map(
        (GardenInsect i) => (i.kind, i.anchor, i.size, i.loop),
      ),
      <Object>[
        (
          GardenInsectKind.butterfly,
          const Offset(0.14, 0.18),
          18.0,
          flightLoopA,
        ),
        (GardenInsectKind.bee, const Offset(0.52, 0.46), 14.0, flightLoopC),
      ],
    );
    expect(gardenInsectsFor(compact: false), same(desktopGardenInsects));
    expect(gardenInsectsFor(compact: true), same(phoneGardenInsects));
  });

  test('each flight loop passes its keyframes and returns home', () {
    _expectOffset(flightLoopA.poseAt(0).offset, Offset.zero);
    _expectOffset(flightLoopA.poseAt(0.25).offset, const Offset(74, -36));
    _expectOffset(flightLoopA.poseAt(0.5).offset, const Offset(158, 8));
    _expectOffset(flightLoopA.poseAt(0.75).offset, const Offset(94, 46));
    _expectOffset(flightLoopA.poseAt(1).offset, Offset.zero);

    _expectOffset(flightLoopB.poseAt(0.3).offset, const Offset(-64, 32));
    _expectOffset(flightLoopB.poseAt(0.6).offset, const Offset(-138, -12));
    _expectOffset(flightLoopB.poseAt(1).offset, Offset.zero);

    _expectOffset(flightLoopC.poseAt(0.5).offset, const Offset(46, -54));
    _expectOffset(flightLoopC.poseAt(1.5).offset, const Offset(46, -54));

    _expectOffset(
      desktopGardenInsects[2].poseAt(4.5).offset,
      const Offset(46, -54),
    );
  });

  test('flight eases in and out between keyframes', () {
    final double early = flightLoopC.poseAt(0.05).offset.dx;
    final double middle = flightLoopC.poseAt(0.25).offset.dx;
    expect(early, greaterThan(0));
    expect(early, lessThan(46 * 0.1));
    expect(middle, closeTo(23, 0.1));
  });

  test('nine seeded fireflies drift through the lower meadow', () {
    final List<GardenFirefly> flies = gardenFirefliesFor(2026);
    expect(flies, hasLength(gardenFireflyCount));
    expect(gardenFireflyCount, 9);
    for (final GardenFirefly fly in flies) {
      expect(fly.anchor.dx, inInclusiveRange(0.06, 0.90));
      expect(fly.anchor.dy, inInclusiveRange(0.44, 0.82));
      expect(fly.loopPeriod, inInclusiveRange(10, 20));
      expect(fly.pulsePeriod, inInclusiveRange(1.6, 3.6));
      expect(fly.glowAt(1.3), inInclusiveRange(0.45, 1));
    }
    expect(flies.map((GardenFirefly f) => f.loop).toSet(), <FlightLoop>{
      flightLoopA,
      flightLoopB,
      flightLoopC,
    });
    expect(
      gardenFirefliesFor(2026).map((GardenFirefly f) => f.anchor),
      flies.map((GardenFirefly f) => f.anchor),
    );
    expect(
      gardenFirefliesFor(2027).map((GardenFirefly f) => f.anchor),
      isNot(flies.map((GardenFirefly f) => f.anchor)),
    );
  });

  test('glow pulses between 45 % and full over its period', () {
    expect(glowPulse(0, 2), closeTo(0.45, 1e-9));
    expect(glowPulse(1, 2), closeTo(1, 1e-9));
    expect(glowPulse(2, 2), closeTo(0.45, 1e-9));
    for (int step = 0; step <= 40; step++) {
      expect(glowPulse(step / 10, 3.2), inInclusiveRange(0.45, 1));
    }
  });

  test('wings fold to 48 % and open again every 0.16 s', () {
    expect(wingSpreadAt(0), closeTo(1, 1e-9));
    expect(wingSpreadAt(0.08), closeTo(0.48, 1e-9));
    expect(wingSpreadAt(0.16), closeTo(1, 1e-9));
    expect(wingSpreadAt(0.04), inExclusiveRange(0.48, 1));
  });
}
