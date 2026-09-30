import 'dart:math' as math;
import 'dart:ui';

import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/scene/meadow_mountains.dart';
import 'package:field_notes/features/garden/scene/meadow_water.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';

const List<double> meadowSeasonOffsets = <double>[0, 0.18, 0.4, 0.62, 0.82, 1];
const List<MeadowRgb> _seasonColours = <MeadowRgb>[
  MeadowRgb(172, 176, 122),
  MeadowRgb(160, 182, 106),
  MeadowRgb(136, 170, 88),
  MeadowRgb(130, 162, 82),
  MeadowRgb(148, 160, 86),
  MeadowRgb(144, 144, 82),
];
const MeadowRgb _farGround = MeadowRgb(150, 170, 140);
const double meadowGroundTop = 300;
const double meadowGroundBottom = 640;

const Color _mossMottle = Color(0xFF425C28);
const Color _paleMottle = Color(0xFFF0ECC4);
const Color _stone = Color(0xFFA39B84);
const Color _stoneInk = Color(0xFF6D6450);
const Color _stoneLight = Color(0xFFC6BEA6);
const Color _reedDark = Color(0xFF6F8A4E);
const Color _reedLight = Color(0xFF7F9A4F);
const Color _cattail = Color(0xFF7A5634);
const Color _wetShore = Color(0xFF857A52);
const Color _pebbleLight = Color(0xFFB3AA90);
const Color _pebbleDark = Color(0xFF9A9078);
const Color _farShore = Color(0xFFECF6F0);
const Color _streamEdge = Color(0xFFF0F8F4);

Offset _project(double x, double z) {
  final MeadowPoint p = meadowProject(x, z);
  return Offset(p.x, p.y);
}

class MeadowSeasonStop {
  const MeadowSeasonStop(this.offset, this.colour);

  final double offset;
  final MeadowRgb colour;
}

class MeadowSeason {
  const MeadowSeason(this.stops);

  factory MeadowSeason.lush(double lush) => MeadowSeason(
    List<MeadowSeasonStop>.unmodifiable(<MeadowSeasonStop>[
      for (int i = 0; i < meadowSeasonOffsets.length; i++)
        MeadowSeasonStop(
          meadowSeasonOffsets[i],
          MeadowRgb(
            _seasonColours[i].red,
            _seasonColours[i].green + lush,
            _seasonColours[i].blue,
          ),
        ),
    ]),
  );

  final List<MeadowSeasonStop> stops;

  MeadowRgb at(double u) {
    final double v = u.clamp(0.0, 1.0);
    int i = 0;
    while (i < stops.length - 2 && v > stops[i + 1].offset) {
      i++;
    }
    final MeadowSeasonStop a = stops[i];
    final MeadowSeasonStop b = stops[i + 1];
    return a.colour.mix(b.colour, (v - a.offset) / (b.offset - a.offset));
  }
}

class MeadowGradientStop {
  const MeadowGradientStop(this.offset, this.colour);

  final double offset;
  final Color colour;
}

class MeadowGlint {
  const MeadowGlint({
    required this.ellipse,
    required this.period,
    required this.phase,
  });

  final MeadowEllipse ellipse;
  final double period;
  final double phase;
}

class MeadowRipple {
  const MeadowRipple({
    required this.ellipse,
    required this.onLake,
    required this.period,
    required this.phase,
  });

  static const double strokeWidth = 0.9;

  final MeadowEllipse ellipse;
  final bool onLake;
  final double period;
  final double phase;
}

class MeadowFlowMark {
  const MeadowFlowMark({
    required this.ellipse,
    required this.period,
    required this.phase,
  });

  final MeadowEllipse ellipse;
  final double period;
  final double phase;
}

class MeadowGroundDressing {
  const MeadowGroundDressing({
    required this.lush,
    required this.season,
    required this.groundStops,
    required this.groundOutline,
    required this.mottles,
    required this.stones,
    required this.reeds,
    required this.wetShore,
    required this.pebbles,
    required this.lakeRipples,
    required this.farShore,
    required this.streamEdges,
    required this.glare,
    required this.glints,
    required this.ripples,
    required this.flows,
  });

  static MeadowGroundDressing build(
    MeadowRandom random, {
    required MeadowWater water,
    required MeadowMountains mountains,
  }) {
    final double lush = random.between(-8, 8);
    final MeadowSeason season = MeadowSeason.lush(lush);
    final List<MeadowGradientStop> groundStops =
        List<MeadowGradientStop>.unmodifiable(<MeadowGradientStop>[
          MeadowGradientStop(0, season.at(0).mix(_farGround, 0.35).toColour()),
          for (final double u in meadowSeasonOffsets)
            MeadowGradientStop(
              (meadowHorizonY +
                      meadowFocal / meadowDepthOf(u) -
                      meadowGroundTop) /
                  (meadowGroundBottom - meadowGroundTop),
              season.at(u).toColour(),
            ),
          MeadowGradientStop(1, season.at(1).scale(0.9).toColour()),
        ]);
    final List<Offset> groundOutline = List<Offset>.unmodifiable(<Offset>[
      const Offset(0, meadowGroundBottom),
      Offset(0, mountains.skirtAt(0) + 14),
      for (final Offset q in mountains.skirtLine)
        Offset(q.dx, math.max(q.dy + 14, 334)),
      const Offset(meadowWorldWidth, meadowGroundBottom),
    ]);

    final List<MeadowShape> mottles = <MeadowShape>[];
    for (int i = 0; i < 40; i++) {
      final double z = 1 / random.between(1 / 7, 1 / 0.9);
      final double x = random.between(-1.2, 1.2) * z;
      if (water.inLake(x, z)) {
        continue;
      }
      final double rx = random.between(0.25, 0.75) * meadowSpread / z;
      final double ry = rx * random.between(0.05, 0.09);
      final bool moss = random.next() < 0.55;
      mottles.add(
        MeadowShape.fill(
          MeadowEllipse(centre: _project(x, z), radiusX: rx, radiusY: ry),
          colour: moss ? _mossMottle : _paleMottle,
          opacity: moss ? 0.07 : 0.08,
        ),
      );
    }

    final List<MeadowShape> stones = <MeadowShape>[];
    for (int i = 0; i < 12; i++) {
      final MeadowStreamSample c =
          water.centreSamples[24 + (random.next() * 64).floor()];
      final int side = random.next() < 0.5 ? -1 : 1;
      final double x =
          water.streamCentre(c.depth) +
          side *
              (water.sideWidth(c.depth, side) +
                  water.bank(c.depth, side) * random.between(0.2, 0.9));
      final Offset q = _project(x, c.depth);
      final double size = random.between(0.01, 0.026) * meadowSpread / c.depth;
      final MeadowEllipse body = MeadowEllipse(
        centre: q,
        radiusX: size,
        radiusY: size * 0.55,
      );
      stones.addAll(<MeadowShape>[
        MeadowShape.fill(body, colour: _stone),
        MeadowShape.stroke(
          body,
          colour: _stoneInk,
          width: math.max(0.5, size * 0.08),
        ),
        MeadowShape.fill(
          MeadowEllipse(
            centre: q + Offset(-size * 0.25, -size * 0.2),
            radiusX: size * 0.45,
            radiusY: size * 0.2,
          ),
          colour: _stoneLight,
        ),
      ]);
    }

    List<MeadowShape> reedAt(double x, double y, double size, int count) {
      final List<MeadowShape> clump = <MeadowShape>[];
      for (int i = 0; i < count; i++) {
        final double dx = random.between(-size * 0.35, size * 0.35);
        final double height = size * random.between(0.6, 1.1);
        final double lx = x + dx;
        final double lean = random.between(-0.25, 0.25) * height;
        clump.add(
          MeadowShape.stroke(
            MeadowOutline(
              List<MeadowSegment>.unmodifiable(<MeadowSegment>[
                MeadowSegment.move(Offset(lx, y)),
                MeadowSegment.quad(
                  Offset(lx + lean * 0.3, y - height * 0.6),
                  Offset(lx + lean, y - height),
                ),
              ]),
            ),
            colour: random.next() < 0.5 ? _reedDark : _reedLight,
            width: math.max(0.7, size * 0.06),
            rounded: true,
          ),
        );
        if (random.next() < 0.3) {
          final double turn = lean * 2 * math.pi / 180;
          final double drop = size * 0.08;
          clump.add(
            MeadowShape.fill(
              MeadowEllipse(
                centre: Offset(
                  lx + lean - drop * math.sin(turn),
                  y - height + drop * math.cos(turn),
                ),
                radiusX: size * 0.045 + 0.4,
                radiusY: size * 0.12,
                rotation: turn,
              ),
              colour: _cattail,
            ),
          );
        }
      }
      return clump;
    }

    final List<MeadowShape> reeds = <MeadowShape>[];
    final List<Offset> lake = water.lakeOutline;
    for (int i = 0; i < lake.length; i++) {
      final double th = i / lake.length * math.pi * 2;
      if (math.sin(th) > -0.3 || random.next() > 0.28) {
        continue;
      }
      final double size = random.between(9, 18);
      final int count = 4 + (random.next() * 5).floor();
      reeds.addAll(reedAt(lake[i].dx, lake[i].dy + 1, size, count));
    }
    for (int i = 0; i < 9; i++) {
      final MeadowStreamSample c =
          water.centreSamples[6 + (random.next() * 50).floor()];
      final int side = random.next() < 0.5 ? -1 : 1;
      final MeadowPoint q = meadowProject(
        water.streamCentre(c.depth) +
            side *
                (water.sideWidth(c.depth, side) +
                    water.bank(c.depth, side) * 0.8),
        c.depth,
      );
      final double size = random.between(20, 34) * q.scale / 0.35;
      final int count = 4 + (random.next() * 4).floor();
      reeds.addAll(reedAt(q.x, q.y, size, count));
    }

    const double mouthDepth = meadowMouthDepth + 0.2;
    final double mouth = meadowProject(
      water.streamCentre(mouthDepth),
      meadowMouthDepth + 0.1,
    ).x;
    final double mouthHalf =
        (water.leftWidth(mouthDepth) + water.rightWidth(mouthDepth)) *
            meadowSpread /
            (meadowMouthDepth + 0.1) *
            0.75 +
        10;
    final List<Offset> farShore = <Offset>[
      for (int i = 0; i < lake.length; i++)
        if (math.sin(i / lake.length * math.pi * 2) > 0) lake[i],
    ];
    final List<Offset> nearShore = <Offset>[
      for (int i = 0; i < lake.length; i++)
        if (math.sin(i / lake.length * math.pi * 2) < 0.05 &&
            (lake[i].dx - mouth).abs() > mouthHalf)
          lake[i],
    ];
    final List<MeadowShape> wetShore = <MeadowShape>[
      for (final Offset q in nearShore)
        MeadowShape.fill(
          MeadowEllipse(
            centre: q + const Offset(0, 1),
            radiusX: random.between(10, 20),
            radiusY: random.between(1.6, 3),
          ),
          colour: _wetShore,
          opacity: 0.4,
        ),
    ];

    final List<MeadowShape> pebbles = <MeadowShape>[];
    for (int i = 0; i < 70; i++) {
      final MeadowStreamSample c =
          water.centreSamples[20 + (random.next() * 70).floor()];
      final int side = random.next() < 0.5 ? -1 : 1;
      final double x =
          water.streamCentre(c.depth) +
          side *
              (water.sideWidth(c.depth, side) +
                  water.bank(c.depth, side) * random.between(0, 0.9));
      final double size = random.between(0.003, 0.008) * meadowSpread / c.depth;
      pebbles.add(
        MeadowShape.fill(
          MeadowEllipse(
            centre: _project(x, c.depth),
            radiusX: size,
            radiusY: size * 0.55,
          ),
          colour: random.next() < 0.5 ? _pebbleLight : _pebbleDark,
        ),
      );
    }

    final List<({double x, double z})> patches = <({double x, double z})>[
      for (int i = 0; i < 4; i++)
        _pointInLake(random, water, spreadX: 0.8, spreadDepth: 0.7),
    ];
    final List<MeadowShape> lakeRipples = <MeadowShape>[];
    for (int i = 0; i < 90; i++) {
      final ({double x, double z}) patch = patches[i % 4];
      final double x = patch.x + random.between(-0.9, 0.9);
      final double z = patch.z + random.between(-0.5, 0.5);
      if (!water.inLake(x * 1.02, z)) {
        continue;
      }
      final Offset q = _project(x, z);
      final double length = random.between(0.08, 0.3) * meadowSpread / z;
      final double weight = math.max(0.4, 0.9 * 4 / z);
      lakeRipples.add(
        MeadowShape.stroke(
          MeadowOutline(
            List<MeadowSegment>.unmodifiable(<MeadowSegment>[
              MeadowSegment.move(q + Offset(-length / 2, 0)),
              MeadowSegment.quad(
                q + Offset(0, -weight * 0.6),
                q + Offset(length / 2, 0),
              ),
            ]),
          ),
          role: MeadowRole.lkHi,
          width: weight,
          opacity: random.between(0.1, 0.3),
          rounded: true,
        ),
      );
    }

    final List<MeadowShape> streamEdges = <MeadowShape>[
      MeadowShape.stroke(
        MeadowOutline.polyline(water.edgeRight),
        colour: _streamEdge,
        width: 1,
        opacity: 0.5,
        dash: _dashes(random),
      ),
      MeadowShape.stroke(
        MeadowOutline.polyline(water.edgeLeft),
        colour: _streamEdge,
        width: 0.8,
        opacity: 0.38,
        dash: _dashes(random),
      ),
    ];

    final double far = water.lakeFarY;
    final List<MeadowGlint> glints = <MeadowGlint>[];
    for (int i = 0; i < 54; i++) {
      final double y = random.between(far + 2, water.lakeNearY - 1);
      final double spread = 8 + (y - far) * 1.5;
      final double x = (random.next() - 0.5) * 2 * spread * random.next();
      final double w = random.between(3, 10) * (0.6 + (y - far) / 50);
      glints.add(
        MeadowGlint(
          ellipse: MeadowEllipse(
            centre: Offset(x, y),
            radiusX: w,
            radiusY: 0.8,
          ),
          period: random.between(1.2, 3),
          phase: random.between(0, 3),
        ),
      );
    }

    final List<MeadowRipple> ripples = <MeadowRipple>[];
    for (int i = 0; i < 8; i++) {
      final bool onLake = i < 5;
      final Offset q;
      if (onLake) {
        final ({double x, double z}) spot = _pointInLake(
          random,
          water,
          spreadX: 0.7,
          spreadDepth: 0.6,
        );
        q = _project(spot.x, spot.z);
      } else {
        final MeadowStreamSample c =
            water.centreSamples[14 + (random.next() * 44).floor()];
        q = _project(
          water.streamCentre(c.depth) + random.between(-0.4, 0.4) * c.halfWidth,
          c.depth,
        );
      }
      final double rx =
          random.between(0.05, 0.09) * meadowSpread / meadowDepthAtRow(q.dy);
      ripples.add(
        MeadowRipple(
          ellipse: MeadowEllipse(centre: q, radiusX: rx, radiusY: rx * 0.2),
          onLake: onLake,
          period: random.between(7, 12),
          phase: random.between(0, 10),
        ),
      );
    }

    final List<MeadowFlowMark> flows = <MeadowFlowMark>[];
    for (int i = 0; i < 70; i++) {
      final MeadowStreamSample c =
          water.centreSamples[2 + (random.next() * 88).floor()];
      if (c.depth > meadowMouthDepth) {
        continue;
      }
      final Offset q = _project(
        water.streamCentre(c.depth) +
            random.between(-0.5, 0.5) * math.min(c.halfWidth, 0.09),
        c.depth,
      );
      final double rx = random.between(3, 10) / c.depth;
      flows.add(
        MeadowFlowMark(
          ellipse: MeadowEllipse(
            centre: q,
            radiusX: rx,
            radiusY: math.max(0.5, rx * 0.14),
          ),
          period: random.between(2.4, 4.2),
          phase: random.between(0, 4),
        ),
      );
    }

    return MeadowGroundDressing(
      lush: lush,
      season: season,
      groundStops: groundStops,
      groundOutline: groundOutline,
      mottles: List<MeadowShape>.unmodifiable(mottles),
      stones: List<MeadowShape>.unmodifiable(stones),
      reeds: List<MeadowShape>.unmodifiable(reeds),
      wetShore: List<MeadowShape>.unmodifiable(wetShore),
      pebbles: List<MeadowShape>.unmodifiable(pebbles),
      lakeRipples: List<MeadowShape>.unmodifiable(lakeRipples),
      farShore: MeadowShape.stroke(
        MeadowOutline.polyline(farShore),
        colour: _farShore,
        width: 1,
        opacity: 0.28,
      ),
      streamEdges: List<MeadowShape>.unmodifiable(streamEdges),
      glare: MeadowEllipse(centre: Offset(0, far + 5), radiusX: 34, radiusY: 3),
      glints: List<MeadowGlint>.unmodifiable(glints),
      ripples: List<MeadowRipple>.unmodifiable(ripples),
      flows: List<MeadowFlowMark>.unmodifiable(flows),
    );
  }

  static const double glareOpacity = 0.55;

  final double lush;
  final MeadowSeason season;
  final List<MeadowGradientStop> groundStops;
  final List<Offset> groundOutline;
  final List<MeadowShape> mottles;
  final List<MeadowShape> stones;
  final List<MeadowShape> reeds;
  final List<MeadowShape> wetShore;
  final List<MeadowShape> pebbles;
  final List<MeadowShape> lakeRipples;
  final MeadowShape farShore;
  final List<MeadowShape> streamEdges;
  final MeadowEllipse glare;
  final List<MeadowGlint> glints;
  final List<MeadowRipple> ripples;
  final List<MeadowFlowMark> flows;
}

({double x, double z}) _pointInLake(
  MeadowRandom random,
  MeadowWater water, {
  required double spreadX,
  required double spreadDepth,
}) {
  double x;
  double z;
  int tries = 0;
  do {
    x =
        water.lakeCentreX +
        random.between(-spreadX, spreadX) * water.lakeRadiusX;
    z =
        water.lakeCentreDepth +
        random.between(-spreadDepth, spreadDepth) * water.lakeRadiusDepth;
    tries++;
  } while (!water.inLake(x, z) && tries < 20);
  return (x: x, z: z);
}

List<double> _dashes(MeadowRandom random) => List<double>.unmodifiable(<double>[
  for (int i = 0; i < 14; i++) ...<double>[
    random.between(4, 26),
    random.between(8, 40),
  ],
]);
