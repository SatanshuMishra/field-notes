import 'dart:math' as math;
import 'dart:ui';

import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';

const double meadowGrassStillDepth = 2.2;

const double _bandStart = 330;
const double _bandEnd = 650;
const double _stepBase = 6;
const double _stepGrowth = 0.05;
const double _firstBlade = -6;
const double _lastBlade = 1406;
const double _minReach = 4;
const double _streamMargin = 0.004;
const double _edgeMargin = 0.05;
const double _nearMargin = 0.2;
const double _swayPeriodOffset = 9;
const MeadowRgb _farMeadow = MeadowRgb(168, 184, 150);
const List<double> _shades = <double>[0.8, 0.93, 1.08];

class MeadowGrassStroke {
  const MeadowGrassStroke({
    required this.start,
    required this.control,
    required this.end,
  });

  final Offset start;
  final Offset control;
  final Offset end;
}

class MeadowGrassBand {
  const MeadowGrassBand({
    required this.strokes,
    required this.colours,
    required this.strokeWidth,
    required this.top,
    required this.height,
    required this.sortKey,
    required this.depth,
    required this.animated,
    required this.delay,
  });

  final List<List<MeadowGrassStroke>> strokes;
  final List<Color> colours;
  final double strokeWidth;
  final double top;
  final double height;
  final double sortKey;
  final double depth;
  final bool animated;
  final double delay;
}

MeadowRgb _seasonAt(MeadowTerrain terrain, double z) {
  final double u = meadowProgressOfDepth(z);
  if (u < 0) {
    return terrain.ground.season
        .at(0)
        .mix(_farMeadow, (-u * 1.2).clamp(0.0, 0.5));
  }
  return terrain.ground.season.at(u);
}

List<MeadowGrassBand> buildMeadowGrass({
  required int seed,
  required MeadowTerrain terrain,
}) {
  final MeadowRandom random = MeadowRandom(
    meadowPartSeed(seed, MeadowPart.grass),
  );
  final MeadowWater water = terrain.water;
  final List<MeadowGrassBand> bands = <MeadowGrassBand>[];
  double y0 = _bandStart;
  while (y0 < _bandEnd) {
    final double step = _stepBase + (y0 - _bandStart) * _stepGrowth;
    final double y1 = y0 + step;
    final double zm = meadowDepthAtRow((y0 + y1) / 2);
    final double gap = 4.2 + 10 / zm;
    final MeadowRgb base = _seasonAt(terrain, zm);
    final List<Color> colours = <Color>[
      for (final double shade in _shades)
        MeadowRgb(
          math.min(255, base.red * shade),
          math.min(255, base.green * shade),
          math.min(255, base.blue * shade),
        ).toColour(),
    ];
    final List<List<MeadowGrassStroke>> strokes = <List<MeadowGrassStroke>>[
      <MeadowGrassStroke>[],
      <MeadowGrassStroke>[],
      <MeadowGrassStroke>[],
    ];
    double reach = _minReach;
    double x = _firstBlade;
    while (x < _lastBlade) {
      final double by = random.between(y0, y1);
      final double zb = meadowDepthAtRow(by);
      final double worldX = (x - meadowWorldWidth / 2) * zb / meadowSpread;
      if (!water.inLake(worldX, zb)) {
        final double dw = water.distanceToStream(worldX, zb);
        if (dw >= _streamMargin) {
          final bool edge = dw < _edgeMargin;
          final double heightFactor = edge
              ? random.between(0.35, 0.7)
              : dw < _nearMargin
              ? 0.6
              : 1;
          final double tall = random.next() < 0.12 ? 1.5 : 1;
          final double hg =
              random.between(9, 26) *
              meadowNearScale /
              zb *
              heightFactor *
              tall;
          double lean = (random.next() - 0.35) * hg * 0.45;
          if (edge) {
            lean =
                (worldX < water.streamCentre(zb) ? 1 : -1) *
                hg *
                random.between(0.2, 0.5);
          }
          reach = math.max(reach, hg);
          strokes[random.nextInt(3)].add(
            MeadowGrassStroke(
              start: Offset(x, by),
              control: Offset(x + lean * 0.25, by - hg * 0.55),
              end: Offset(x + lean, by - hg),
            ),
          );
        }
      }
      x += gap * random.between(0.5, 1.5);
    }
    final double top = (y0 - reach - 3).floorToDouble();
    final double height = (y1 - top + 3).ceilToDouble();
    final double u = meadowProgressOfDepth(zm).clamp(0.0, 1.0);
    bands.add(
      MeadowGrassBand(
        strokes: List<List<MeadowGrassStroke>>.unmodifiable(
          strokes.map(List<MeadowGrassStroke>.unmodifiable),
        ),
        colours: List<Color>.unmodifiable(colours),
        strokeWidth: math.max(0.55, 2.1 / zm),
        top: top,
        height: height,
        sortKey: y1 - 0.5,
        depth: zm,
        animated: zm < meadowGrassStillDepth,
        delay: -(_swayPeriodOffset - (u * 2.4 + 0.8)),
      ),
    );
    y0 = y1;
  }
  return List<MeadowGrassBand>.unmodifiable(bands);
}
