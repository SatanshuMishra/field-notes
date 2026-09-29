import 'dart:math' as math;
import 'dart:ui' show Color, Offset;

import 'package:flutter/animation.dart' show Curves;

import 'package:field_notes/design/flowers/garden_art_colors.dart';

const int gardenFireflyCount = 9;
const double wingBeatSeconds = 0.16;
const double wingFoldedSpread = 0.48;
const double glowDimOpacity = 0.45;

const int _fireflySeedSalt = 313;

class FlightKeyframe {
  const FlightKeyframe(this.at, this.offset, {this.turnDegrees = 0});

  final double at;
  final Offset offset;
  final double turnDegrees;
}

class FlightPose {
  const FlightPose(this.offset, this.turnDegrees);

  final Offset offset;
  final double turnDegrees;
}

class FlightLoop {
  const FlightLoop(this.keyframes);

  final List<FlightKeyframe> keyframes;

  FlightPose poseAt(double progress) {
    final double t = progress - progress.floorToDouble();
    int i = 0;
    while (i < keyframes.length - 2 && t >= keyframes[i + 1].at) {
      i++;
    }
    final FlightKeyframe from = keyframes[i];
    final FlightKeyframe to = keyframes[i + 1];
    final double k = Curves.easeInOut.transform(
      ((t - from.at) / (to.at - from.at)).clamp(0.0, 1.0),
    );
    return FlightPose(
      Offset.lerp(from.offset, to.offset, k)!,
      from.turnDegrees + (to.turnDegrees - from.turnDegrees) * k,
    );
  }
}

const FlightLoop flightLoopA = FlightLoop(<FlightKeyframe>[
  FlightKeyframe(0, Offset.zero, turnDegrees: -6),
  FlightKeyframe(0.25, Offset(74, -36), turnDegrees: 9),
  FlightKeyframe(0.5, Offset(158, 8), turnDegrees: -4),
  FlightKeyframe(0.75, Offset(94, 46), turnDegrees: 8),
  FlightKeyframe(1, Offset.zero, turnDegrees: -6),
]);

const FlightLoop flightLoopB = FlightLoop(<FlightKeyframe>[
  FlightKeyframe(0, Offset.zero, turnDegrees: 5),
  FlightKeyframe(0.3, Offset(-64, 32), turnDegrees: -9),
  FlightKeyframe(0.6, Offset(-138, -12), turnDegrees: 6),
  FlightKeyframe(1, Offset.zero, turnDegrees: 5),
]);

const FlightLoop flightLoopC = FlightLoop(<FlightKeyframe>[
  FlightKeyframe(0, Offset.zero),
  FlightKeyframe(0.5, Offset(46, -54)),
  FlightKeyframe(1, Offset.zero),
]);

const List<FlightLoop> _fireflyLoops = <FlightLoop>[
  flightLoopA,
  flightLoopB,
  flightLoopC,
];

enum GardenInsectKind { butterfly, bee }

class GardenInsect {
  const GardenInsect({
    required this.kind,
    required this.anchor,
    required this.size,
    required this.loop,
    required this.period,
    this.wing = GardenArtColors.beeWing,
    this.hindWing = GardenArtColors.beeWing,
  });

  final GardenInsectKind kind;
  final Offset anchor;
  final double size;
  final FlightLoop loop;
  final double period;
  final Color wing;
  final Color hindWing;

  FlightPose poseAt(double seconds) => loop.poseAt(seconds / period);
}

const List<GardenInsect> desktopGardenInsects = <GardenInsect>[
  GardenInsect(
    kind: GardenInsectKind.butterfly,
    anchor: Offset(0.11, 0.14),
    size: 24,
    loop: flightLoopA,
    period: 15,
    wing: GardenArtColors.butterflyCoral,
    hindWing: GardenArtColors.butterflyCoralHind,
  ),
  GardenInsect(
    kind: GardenInsectKind.butterfly,
    anchor: Offset(0.84, 0.28),
    size: 22,
    loop: flightLoopB,
    period: 18,
    wing: GardenArtColors.butterflyLilac,
    hindWing: GardenArtColors.butterflyLilacHind,
  ),
  GardenInsect(
    kind: GardenInsectKind.bee,
    anchor: Offset(0.46, 0.50),
    size: 18,
    loop: flightLoopC,
    period: 9,
  ),
];

const List<GardenInsect> phoneGardenInsects = <GardenInsect>[
  GardenInsect(
    kind: GardenInsectKind.butterfly,
    anchor: Offset(0.14, 0.18),
    size: 18,
    loop: flightLoopA,
    period: 15,
    wing: GardenArtColors.butterflyCoral,
    hindWing: GardenArtColors.butterflyCoralHind,
  ),
  GardenInsect(
    kind: GardenInsectKind.bee,
    anchor: Offset(0.52, 0.46),
    size: 14,
    loop: flightLoopC,
    period: 9,
  ),
];

List<GardenInsect> gardenInsectsFor({required bool compact}) =>
    compact ? phoneGardenInsects : desktopGardenInsects;

class GardenFirefly {
  const GardenFirefly({
    required this.anchor,
    required this.loop,
    required this.loopPeriod,
    required this.loopPhase,
    required this.pulsePeriod,
    required this.pulsePhase,
  });

  final Offset anchor;
  final FlightLoop loop;
  final double loopPeriod;
  final double loopPhase;
  final double pulsePeriod;
  final double pulsePhase;

  Offset driftAt(double seconds) =>
      loop.poseAt((seconds + loopPhase) / loopPeriod).offset;

  double glowAt(double seconds) => glowPulse(seconds + pulsePhase, pulsePeriod);
}

double _between(math.Random rng, double from, double to) =>
    from + rng.nextDouble() * (to - from);

List<GardenFirefly> gardenFirefliesFor(int seed) {
  final math.Random rng = math.Random(seed + _fireflySeedSalt);
  return List<GardenFirefly>.unmodifiable(<GardenFirefly>[
    for (int i = 0; i < gardenFireflyCount; i++)
      GardenFirefly(
        anchor: Offset(_between(rng, 0.06, 0.90), _between(rng, 0.44, 0.82)),
        loop: _fireflyLoops[i % _fireflyLoops.length],
        loopPeriod: _between(rng, 10, 20),
        loopPhase: _between(rng, 0, 8),
        pulsePeriod: _between(rng, 1.6, 3.6),
        pulsePhase: _between(rng, 0, 2),
      ),
  ]);
}

double glowPulse(double seconds, double period) {
  final double t = seconds / period;
  final double half = (t - t.floorToDouble()) * 2;
  final double rise = half <= 1 ? half : 2 - half;
  return glowDimOpacity +
      (1 - glowDimOpacity) * Curves.easeInOut.transform(rise.clamp(0.0, 1.0));
}

double wingSpreadAt(double seconds) {
  final double t = seconds / wingBeatSeconds;
  final double half = (t - t.floorToDouble()) * 2;
  final double fold = half <= 1 ? half : 2 - half;
  return 1 -
      (1 - wingFoldedSpread) * Curves.easeInOut.transform(fold.clamp(0.0, 1.0));
}
