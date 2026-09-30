import 'dart:math' as math;
import 'dart:ui';

import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_mountains.dart';
import 'package:field_notes/features/garden/scene/meadow_water.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';

const MeadowRgb meadowHaze = MeadowRgb(176, 196, 198);

const MeadowRgb _spruceBody = MeadowRgb(42, 76, 62);
const MeadowRgb _spruceLit = MeadowRgb(66, 104, 80);
const MeadowRgb _oldSpruceBody = MeadowRgb(38, 70, 58);
const MeadowRgb _oldSpruceLit = MeadowRgb(62, 100, 76);
const MeadowRgb _aspenDark = MeadowRgb(132, 160, 82);
const MeadowRgb _aspenLight = MeadowRgb(160, 184, 100);
const MeadowRgb _aspenBark = MeadowRgb(222, 218, 204);
const Color _spruceTrunk = Color(0xFF4A3A2C);
const Color _spruceInk = Color(0xFF253D33);
const Color _aspenInk = Color(0xFF3D5A2E);
const Color _hiveCord = Color(0xFF3F3024);
const Color _hiveFill = Color(0xFFC9A15A);
const Color _hiveInk = Color(0xFF6B4A24);
const Color _spruceShadow = Color(0xFF1E2C1E);

const int _attempts = 210;
const int _shoreAttempts = 26;
const double _streamClearance = 0.14;
const double _inkDepth = 4.4;

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _worldX(double x, double z) =>
    (x - meadowWorldWidth / 2) * z / meadowSpread;

double _hazeOf(double z) => ((z - 2.2) / 8).clamp(0.0, 1.0) * 0.55;

class MeadowWings {
  const MeadowWings({
    required this.leftNear,
    required this.leftFar,
    required this.rightNear,
    required this.rightFar,
    required this.phase,
  });

  final double leftNear;
  final double leftFar;
  final double rightNear;
  final double rightFar;
  final double phase;

  double innerAt(int side, double z) {
    final double t = ((z - 2.3) / 6.5).clamp(0.0, 1.0);
    final double near = side < 0 ? leftNear : rightNear;
    final double far = side < 0 ? leftFar : rightFar;
    return _lerp(near, far, math.sqrt(t)) +
        (side < 0 ? 1 : -1) * 18 * math.sin(z * 2.3 + phase);
  }
}

class MeadowTree {
  const MeadowTree({
    required this.x,
    required this.y,
    required this.worldX,
    required this.depth,
    required this.height,
    required this.aspen,
    required this.side,
    required this.art,
  });

  final double x;
  final double y;
  final double worldX;
  final double depth;
  final double height;
  final bool aspen;
  final int side;
  final List<MeadowShape> art;

  double get top => y - height;
}

class MeadowOldSpruce {
  const MeadowOldSpruce({
    required this.x,
    required this.y,
    required this.depth,
    required this.height,
    required this.width,
    required this.side,
    required this.day,
    required this.hive,
    required this.centre,
    required this.artAtOrigin,
    required this.frameAtOrigin,
  });

  final double x;
  final double y;
  final double depth;
  final double height;
  final double width;
  final int side;
  final int day;
  final Offset hive;
  final Offset centre;
  final List<MeadowShape> artAtOrigin;
  final Rect frameAtOrigin;

  double get top => y - height;

  List<Offset> get clip => List<Offset>.unmodifiable(<Offset>[
    Offset(x - width / 2, y),
    Offset(x, y - height - 4),
    Offset(x + width / 2, y),
  ]);

  bool displaces(double treeX, double treeY) =>
      (treeX - x).abs() < width * 0.55 && treeY > y - 30 && treeY < y + 24;
}

class MeadowForest {
  const MeadowForest({
    required this.wings,
    required this.trees,
    required this.oldSpruce,
  });

  static MeadowForest build(
    MeadowRandom random, {
    required MeadowWater water,
    required MeadowMountains mountains,
    required MeadowYear year,
  }) {
    final double leftNear = random.between(190, 320);
    final double leftFar = random.between(380, 500);
    final double rightNear = meadowWorldWidth - random.between(190, 320);
    final double rightFar = meadowWorldWidth - random.between(380, 500);
    final bool widenLeft = random.next() < 0.5;
    final double widenNear = random.between(50, 110);
    final double widenFar = random.between(60, 140);
    final MeadowWings wings = MeadowWings(
      leftNear: widenLeft ? leftNear - widenNear : leftNear,
      leftFar: widenLeft ? leftFar - widenFar : leftFar,
      rightNear: widenLeft ? rightNear : rightNear + widenNear,
      rightFar: widenLeft ? rightFar : rightFar + widenFar,
      phase: mountains.skirtPhases[0],
    );

    final List<_Stand> stands = <_Stand>[];
    for (int i = 0; i < _attempts; i++) {
      final int side = random.next() < 0.5 ? -1 : 1;
      final double z = 1 / random.between(1 / 9.5, 1 / 2.3);
      final double inner = wings.innerAt(side, z);
      final double u = math.pow(random.next(), 0.75).toDouble();
      final double x = side < 0
          ? -40 + (inner + 40) * u
          : meadowWorldWidth + 40 - (meadowWorldWidth + 40 - inner) * u;
      final double worldX = _worldX(x, z);
      if (water.inLake(worldX, z) ||
          water.inStream(worldX, z, _streamClearance)) {
        continue;
      }
      final MeadowPoint q = meadowProject(worldX, z);
      final double height =
          random.between(0.42, 0.82) *
          meadowSpread /
          z *
          (random.next() < 0.25 ? 0.6 : 1);
      stands.add(
        _Stand(
          x: q.x,
          y: q.y,
          worldX: worldX,
          depth: z,
          height: height,
          aspen: random.next() < 0.07,
          side: side,
        ),
      );
    }
    for (int i = 0; i < _shoreAttempts; i++) {
      final double angle = random.next() * math.pi * 2;
      final double worldX =
          water.lakeCentreX + water.lakeRadiusX * math.cos(angle) * 1.06;
      final double z =
          water.lakeCentreDepth +
          water.lakeRadiusDepth * math.sin(angle) * 1.06;
      if (z < meadowMouthDepth + 0.6 ||
          (worldX - water.streamCentre(z)).abs() < 0.4) {
        continue;
      }
      final MeadowPoint q = meadowProject(worldX, z);
      final double height = random.between(0.3, 0.6) * meadowSpread / z;
      stands.add(
        _Stand(
          x: q.x,
          y: q.y,
          worldX: worldX,
          depth: z,
          height: height,
          aspen: random.next() < 0.2,
          side: worldX < 0 ? -1 : 1,
        ),
      );
    }

    final MeadowOldSpruce? oldSpruce = year.hasSpruce
        ? _oldSpruce(random, water: water, wings: wings, year: year)
        : null;
    final List<_Stand> kept = <_Stand>[
      for (final _Stand stand in stands)
        if (oldSpruce == null || !oldSpruce.displaces(stand.x, stand.y)) stand,
    ];
    final List<int> order = List<int>.generate(kept.length, (int i) => i)
      ..sort((int a, int b) {
        final int byRow = kept[a].y.compareTo(kept[b].y);
        return byRow != 0 ? byRow : a.compareTo(b);
      });
    final List<MeadowTree> trees = <MeadowTree>[
      for (final int index in order) kept[index].grow(random),
    ];
    return MeadowForest(
      wings: wings,
      trees: List<MeadowTree>.unmodifiable(trees),
      oldSpruce: oldSpruce,
    );
  }

  final MeadowWings wings;
  final List<MeadowTree> trees;
  final MeadowOldSpruce? oldSpruce;

  double innerAt(int side, double z) => wings.innerAt(side, z);
}

class _Stand {
  const _Stand({
    required this.x,
    required this.y,
    required this.worldX,
    required this.depth,
    required this.height,
    required this.aspen,
    required this.side,
  });

  final double x;
  final double y;
  final double worldX;
  final double depth;
  final double height;
  final bool aspen;
  final int side;

  MeadowTree grow(MeadowRandom random) => MeadowTree(
    x: x,
    y: y,
    worldX: worldX,
    depth: depth,
    height: height,
    aspen: aspen,
    side: side,
    art: aspen
        ? _aspenArt(random, x, y, height, depth)
        : _spruceArt(random, x, y, height, depth),
  );
}

MeadowOldSpruce _oldSpruce(
  MeadowRandom random, {
  required MeadowWater water,
  required MeadowWings wings,
  required MeadowYear year,
}) {
  final MeadowRun run = year.longestRun;
  final double middle = (run.first + run.last) / 2 / (year.daysInYear - 1);
  final double z = meadowDepthOf(middle).clamp(2.4, 4.2);
  final int side = water.streamCentre(z) > 0 ? -1 : 1;
  final double x =
      wings.innerAt(side, z) +
      (side < 0 ? random.between(-20, 20) : -random.between(-20, 20));
  final MeadowPoint q = meadowProject(_worldX(x, z), z);
  final double height = math.min(390, 1.05 * meadowSpread / z);
  final double width = height * 0.34;
  final List<MeadowShape> body = _spruceArt(
    random,
    0,
    0,
    height,
    math.min(z, 4),
    body: _oldSpruceBody,
    lit: _oldSpruceLit,
  );
  final Offset hive = Offset(-side * width * 0.18, -height * 0.3);
  final MeadowEllipse comb = MeadowEllipse(
    centre: hive,
    radiusX: height * 0.018,
    radiusY: height * 0.024,
  );
  return MeadowOldSpruce(
    x: q.x,
    y: q.y,
    depth: z,
    height: height,
    width: width,
    side: side,
    day: run.last,
    hive: Offset(q.x + hive.dx, q.y + hive.dy),
    centre: Offset(q.x, q.y - height * 0.5),
    artAtOrigin: List<MeadowShape>.unmodifiable(<MeadowShape>[
      MeadowShape.fill(
        MeadowEllipse(
          centre: const Offset(0, 2),
          radiusX: width * 0.62,
          radiusY: height * 0.02,
        ),
        colour: _spruceShadow,
        opacity: 0.25,
      ),
      ...body,
      MeadowShape.stroke(
        MeadowOutline.polyline(<Offset>[
          hive + Offset(0, -height * 0.03),
          hive + Offset(0, -height * 0.01),
        ]),
        colour: _hiveCord,
        width: height * 0.004,
      ),
      MeadowShape.fill(comb, colour: _hiveFill),
      MeadowShape.stroke(comb, colour: _hiveInk, width: height * 0.0035),
      MeadowShape.stroke(
        MeadowOutline(
          List<MeadowSegment>.unmodifiable(<MeadowSegment>[
            MeadowSegment.move(hive + Offset(-height * 0.016, -height * 0.006)),
            MeadowSegment.line(hive + Offset(height * 0.016, -height * 0.006)),
            MeadowSegment.move(hive + Offset(-height * 0.017, height * 0.008)),
            MeadowSegment.line(hive + Offset(height * 0.017, height * 0.008)),
          ]),
        ),
        colour: _hiveInk,
        width: height * 0.003,
      ),
    ]),
    frameAtOrigin: Rect.fromLTWH(
      -width * 0.7,
      -height - 4,
      width * 1.4,
      height + 10,
    ),
  );
}

List<MeadowShape> _spruceArt(
  MeadowRandom random,
  double x,
  double y,
  double height,
  double z, {
  MeadowRgb body = _spruceBody,
  MeadowRgb lit = _spruceLit,
}) {
  final double haze = _hazeOf(z);
  final int levels = 7 + (random.next() * 4).floor();
  final double w = height * random.between(0.28, 0.36);
  final double trunk = height * 0.07;
  final double step = (height - trunk) / levels;
  final List<Offset> left = <Offset>[];
  final List<Offset> right = <Offset>[];
  for (int i = 1; i <= levels; i++) {
    final double t = i / levels;
    final double row = y - trunk - (height - trunk) * (1 - t);
    final double half =
        w / 2 * math.pow(t, 0.85) * (1 + random.between(-0.1, 0.1));
    final double inner = half * 0.58;
    left.add(Offset(x - half, row));
    right.add(Offset(x + half * (1 + random.between(-0.08, 0.08)), row));
    if (i < levels) {
      left.add(Offset(x - inner, row - step * 0.32));
      right.add(Offset(x + inner, row - step * 0.32));
    }
  }
  final Offset top = Offset(x, y - height);
  final MeadowOutline crown = MeadowOutline.polygon(<Offset>[
    top,
    ...right,
    ...left.reversed,
  ]);
  return List<MeadowShape>.unmodifiable(<MeadowShape>[
    MeadowShape.stroke(
      MeadowOutline.polyline(<Offset>[
        Offset(x, y),
        Offset(x, y - trunk * 1.6),
      ]),
      colour: _spruceTrunk,
      width: math.max(0.8, height * 0.028),
    ),
    MeadowShape.fill(crown, colour: body.mix(meadowHaze, haze).toColour()),
    if (z < _inkDepth)
      MeadowShape.stroke(
        crown,
        colour: _spruceInk,
        width: math.max(0.5, height * 0.005),
        rounded: true,
      ),
    MeadowShape.fill(
      MeadowOutline.polygon(<Offset>[top, ...left, Offset(x, y - trunk)]),
      colour: lit.mix(meadowHaze, haze).toColour(),
      opacity: 0.55,
    ),
  ]);
}

List<MeadowShape> _aspenArt(
  MeadowRandom random,
  double x,
  double y,
  double height,
  double z,
) {
  final double haze = _hazeOf(z);
  final Color dark = _aspenDark.mix(meadowHaze, haze).toColour();
  final Color light = _aspenLight.mix(meadowHaze, haze).toColour();
  final List<MeadowShape> shapes = <MeadowShape>[
    MeadowShape.stroke(
      MeadowOutline.polyline(<Offset>[
        Offset(x, y),
        Offset(x + height * 0.02, y - height * 0.72),
      ]),
      colour: _aspenBark.mix(meadowHaze, haze).toColour(),
      width: math.max(0.8, height * 0.035),
      rounded: true,
    ),
  ];
  for (int i = 0; i < 7; i++) {
    final double cx = x + random.between(-0.1, 0.1) * height;
    final double cy = y - height * random.between(0.45, 0.92);
    final double rx = height * random.between(0.06, 0.1);
    final MeadowEllipse crown = MeadowEllipse(
      centre: Offset(cx, cy),
      radiusX: rx,
      radiusY: rx * 1.25,
    );
    shapes.add(MeadowShape.fill(crown, colour: i.isOdd ? dark : light));
    if (z < _inkDepth) {
      shapes.add(
        MeadowShape.stroke(
          crown,
          colour: _aspenInk,
          width: math.max(0.5, height * 0.004),
        ),
      );
    }
  }
  return List<MeadowShape>.unmodifiable(shapes);
}
