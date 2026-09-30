import 'dart:math' as math;
import 'dart:ui';

import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_forest.dart';
import 'package:field_notes/features/garden/scene/meadow_mountains.dart';
import 'package:field_notes/features/garden/scene/meadow_water.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';

const int _starCount = 150;
const double _focusDepth = 1.25;
const double _cloudHeight = 80;

class MeadowStar {
  const MeadowStar({
    required this.centre,
    required this.radius,
    required this.opacity,
  });

  static const Color colour = Color(0xFFFFFBEA);

  final Offset centre;
  final double radius;
  final double opacity;
}

class MeadowCloud {
  const MeadowCloud({
    required this.bounds,
    required this.puffs,
    required this.opacity,
    required this.period,
    required this.phase,
  });

  final Rect bounds;
  final List<MeadowEllipse> puffs;
  final double opacity;
  final double period;
  final double phase;

  double get gradientTop => bounds.top + 30;

  double get gradientBottom => bounds.top + 72;
}

class MeadowSkyDressing {
  const MeadowSkyDressing({
    required this.stars,
    required this.clouds,
    required this.butterflyHomes,
    required this.milkyWayAngle,
    required this.shootingStar,
    required this.nightClip,
    required this.lakeMist,
    required this.focusX,
  });

  static MeadowSkyDressing build(
    MeadowRandom random, {
    required MeadowWater water,
    required MeadowMountains mountains,
    required MeadowForest forest,
    required MeadowYear year,
  }) {
    final List<MeadowStar> stars = <MeadowStar>[
      for (int i = 0; i < _starCount; i++)
        MeadowStar(
          centre: Offset(
            random.between(0, 1400),
            math.pow(random.next(), 1.3) * 285,
          ),
          radius: random.between(0.45, 1.35),
          opacity: random.between(0.4, 1),
        ),
    ];

    final int cloudCount = (2 + 5 * year.heavyShare + random.next() * 2)
        .round();
    final List<MeadowCloud> clouds = <MeadowCloud>[
      for (int i = 0; i < cloudCount; i++) _cloud(random),
    ];

    final List<Offset> butterflyHomes = List<Offset>.unmodifiable(<Offset>[
      Offset(-40, random.between(380, 480)),
      Offset(1440, random.between(380, 480)),
    ]);
    final double milkyWayAngle = random.between(-32, -10);
    final double shootingX = random.between(700, 1300);
    final double shootingY = random.between(30, 120);

    final List<Offset> far = mountains.far.ridge;
    final List<Offset> high = mountains.high.ridge;
    final List<Offset> massif = mountains.massif.ridge;
    final MeadowOldSpruce? oldSpruce = forest.oldSpruce;
    final List<List<Offset>> nightClip = <List<Offset>>[
      List<Offset>.unmodifiable(<Offset>[
        const Offset(-20, 640),
        for (int i = 0; i < far.length; i++)
          Offset(
            far[i].dx,
            math.min(far[i].dy, math.min(high[i].dy, massif[i].dy)),
          ),
        const Offset(1420, 640),
      ]),
      ?oldSpruce?.clip,
      for (final MeadowTree tree in forest.trees)
        if (tree.top < mountains.high.ridgeAt(tree.x) + 30)
          List<Offset>.unmodifiable(<Offset>[
            Offset(tree.x - tree.height * 0.2, tree.y),
            Offset(tree.x, tree.y - tree.height - 1),
            Offset(tree.x + tree.height * 0.2, tree.y),
          ]),
    ];

    return MeadowSkyDressing(
      stars: List<MeadowStar>.unmodifiable(stars),
      clouds: List<MeadowCloud>.unmodifiable(clouds),
      butterflyHomes: butterflyHomes,
      milkyWayAngle: milkyWayAngle,
      shootingStar: Offset(shootingX, shootingY),
      nightClip: List<List<Offset>>.unmodifiable(nightClip),
      lakeMist: Rect.fromLTWH(
        water.lakeLeftX - 80,
        water.lakeFarY - 22,
        water.lakeRightX - water.lakeLeftX + 160,
        water.lakeNearY - water.lakeFarY + 36,
      ),
      focusX: meadowProject(water.streamCentre(_focusDepth), _focusDepth).x,
    );
  }

  final List<MeadowStar> stars;
  final List<MeadowCloud> clouds;
  final List<Offset> butterflyHomes;
  final double milkyWayAngle;
  final Offset shootingStar;
  final List<List<Offset>> nightClip;
  final Rect lakeMist;
  final double focusX;
}

MeadowCloud _cloud(MeadowRandom random) {
  final double cx = random.between(-60, 1460);
  final double cy = random.between(40, 170);
  final double w = random.between(140, 320);
  final int count = 5 + (random.next() * 5).floor();
  final Offset origin = Offset(cx - w / 2 - 40, cy - 70);
  final List<MeadowEllipse> puffs = <MeadowEllipse>[];
  for (int j = 0; j < count; j++) {
    final double t = j / (count - 1);
    final double ry = random.between(9, 20) * (1 - (t - 0.5).abs() * 0.9) + 6;
    final double rx = random.between(22, 42);
    puffs.add(
      MeadowEllipse(
        centre: origin + Offset(40 + t * w, 70 - ry * 0.9),
        radiusX: rx,
        radiusY: ry,
      ),
    );
  }
  final double period = random.between(90, 170);
  final double phase = random.between(0, 90);
  final double opacity = random.between(0.55, 0.9);
  return MeadowCloud(
    bounds: Rect.fromLTWH(origin.dx, origin.dy, w + 80, _cloudHeight),
    puffs: List<MeadowEllipse>.unmodifiable(puffs),
    opacity: opacity,
    period: period,
    phase: phase,
  );
}
