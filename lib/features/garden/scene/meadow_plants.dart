import 'dart:math' as math;
import 'dart:ui';

import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_plant_art.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';

export 'package:field_notes/features/garden/scene/meadow_plant_art.dart';

const int _ambienceItem = 100000;
const int _driftSpan = 6;
const int _driftGap = 3;
const double _flipChance = 0.7;
const double _wingDepth = 2.25;
const double _shoreClearance = 0.05;
const double _swayPeriod = 9;
const int _pocketCount = 5;
const int _pocketMinimum = 3;
const int _homesPerPocket = 4;
const int _streamHomes = 14;
const double _pocketHomeScale = 0.6;

class MeadowPlant {
  const MeadowPlant({
    required this.dayIndex,
    required this.mood,
    required this.entries,
    required this.valence,
    required this.x,
    required this.y,
    required this.scale,
    required this.z,
    required this.u,
    required this.month,
    required this.heads,
    required this.hidden,
    required this.swayPhase,
    required this.art,
  });

  final int dayIndex;
  final Mood? mood;
  final int entries;
  final double valence;
  final double x;
  final double y;
  final double scale;
  final double z;
  final double u;
  final int month;
  final List<Offset> heads;
  final bool hidden;
  final double swayPhase;
  final MeadowPlantArt art;

  bool get isSprout => mood == null;

  Offset get base => Offset(x, y);
}

class MeadowMistPocket {
  const MeadowMistPocket({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.period,
    required this.phase,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double period;
  final double phase;

  Rect get bounds =>
      Rect.fromCenter(center: Offset(x, y), width: width, height: height);
}

class MeadowFireflyHome {
  const MeadowFireflyHome({
    required this.x,
    required this.y,
    required this.scale,
    required this.sync,
  });

  final double x;
  final double y;
  final double scale;
  final bool sync;
}

class MeadowPlants {
  const MeadowPlants({
    required this.plants,
    required this.pockets,
    required this.fireflyHomes,
  });

  final List<MeadowPlant> plants;
  final List<MeadowMistPocket> pockets;
  final List<MeadowFireflyHome> fireflyHomes;
}

MeadowPlants buildMeadowPlants({
  required int seed,
  required MeadowYear year,
  required MeadowTerrain terrain,
}) {
  final int plantSeed = meadowPartSeed(seed, MeadowPart.plants);
  final int driftSeed = meadowPartSeed(seed, MeadowPart.drifts);
  final List<MeadowPlant> plants = <MeadowPlant>[];
  _Drift? drift;
  for (final MeadowDay day in year.days.nonNulls) {
    if (day.index >= year.limit) {
      continue;
    }
    final _Drift? previous = drift;
    final _Drift current =
        previous == null ||
            day.index - previous.start > _driftSpan ||
            day.index - previous.last > _driftGap
        ? _Drift.start(driftSeed, day.index, previous)
        : previous.through(day.index);
    drift = current;
    plants.add(
      _plant(
        MeadowRandom(meadowItemSeed(plantSeed, day.index)),
        day: day,
        drift: current,
        year: year,
        terrain: terrain,
      ),
    );
  }
  final MeadowRandom ambience = MeadowRandom(
    meadowItemSeed(plantSeed, _ambienceItem),
  );
  final List<MeadowMistPocket> pockets = _pockets(ambience, plants, year);
  return MeadowPlants(
    plants: List<MeadowPlant>.unmodifiable(plants),
    pockets: pockets,
    fireflyHomes: _fireflyHomes(ambience, pockets, terrain.water),
  );
}

class _Drift {
  const _Drift({
    required this.start,
    required this.last,
    required this.side,
    required this.distance,
    required this.hue,
    required this.lightness,
  });

  factory _Drift.start(int driftSeed, int day, _Drift? previous) {
    final MeadowRandom random = MeadowRandom(meadowItemSeed(driftSeed, day));
    final int side = previous == null
        ? (random.next() < 0.5 ? -1 : 1)
        : (random.next() < _flipChance ? -previous.side : previous.side);
    final double distance =
        0.12 + math.pow(random.next(), 1.35).toDouble() * 1.5;
    final double hue = random.between(-5, 5);
    final double lightness = random.between(-0.025, 0.025);
    return _Drift(
      start: day,
      last: day,
      side: side,
      distance: distance,
      hue: hue,
      lightness: lightness,
    );
  }

  final int start;
  final int last;
  final int side;
  final double distance;
  final double hue;
  final double lightness;

  _Drift through(int day) => _Drift(
    start: start,
    last: day,
    side: side,
    distance: distance,
    hue: hue,
    lightness: lightness,
  );
}

double _screenX(double worldX, double z) =>
    meadowWorldWidth / 2 + worldX * meadowSpread / z;

double _worldX(double screenX, double z) =>
    (screenX - meadowWorldWidth / 2) * z / meadowSpread;

MeadowPlant _plant(
  MeadowRandom random, {
  required MeadowDay day,
  required _Drift drift,
  required MeadowYear year,
  required MeadowTerrain terrain,
}) {
  final MeadowWater water = terrain.water;
  final double u =
      (meadowDayProgress(day.index, year.daysInYear) +
              (random.next() - 0.5) * 0.012)
          .clamp(0.0, 1.0);
  final double z = meadowDepthOf(u);
  final double centre = water.streamCentre(z);
  final double limit = 0.96 * z;
  final double offset = water.halfWidth(z) + 0.05;
  double worldX =
      centre +
      drift.side * (offset + drift.distance) +
      (random.next() - 0.5) * 0.42;
  if (worldX.abs() > limit) {
    worldX =
        centre -
        drift.side * (offset + drift.distance * 0.6) +
        (random.next() - 0.5) * 0.3;
  }
  if (z > _wingDepth) {
    final double screenX = _screenX(worldX, z);
    final double innerLeft = terrain.forest.innerAt(-1, z) - 6;
    final double innerRight = terrain.forest.innerAt(1, z) + 6;
    if (screenX < innerLeft) {
      worldX = _worldX(innerLeft + random.between(10, 90), z);
    } else if (screenX > innerRight) {
      worldX = _worldX(innerRight - random.between(10, 90), z);
    }
  }
  worldX = worldX.clamp(-limit, limit);
  if (water.distanceToStream(worldX, z) < _shoreClearance) {
    final int side = worldX >= centre ? 1 : -1;
    worldX =
        centre +
        side *
            (water.sideWidth(z, side) +
                water.bank(z, side) +
                0.04 +
                random.next() * 0.1);
  }
  final MeadowPoint point = meadowProject(worldX, z);
  final double scale = point.scale * random.between(0.92, 1.06);
  final MeadowPlantArt art = buildMeadowPlantArt(
    mood: day.mood,
    entries: day.entries,
    valence: day.valence,
    random: random,
    driftHue: drift.hue,
    driftLightness: drift.lightness,
  );
  final double swayPhase =
      -(_swayPeriod - (u * 2.4 + point.x / meadowWorldWidth * 1.6)) +
      random.next() * 0.5 -
      0.25;
  final MeadowOldSpruce? spruce = terrain.forest.oldSpruce;
  return MeadowPlant(
    dayIndex: day.index,
    mood: day.mood,
    entries: day.entries,
    valence: day.valence,
    x: point.x,
    y: point.y,
    scale: scale,
    z: z,
    u: u,
    month: DateTime.utc(year.year, 1, 1 + day.index).month,
    heads: List<Offset>.unmodifiable(<Offset>[
      for (final Offset head in art.heads)
        Offset(point.x + head.dx * scale, point.y + head.dy * scale),
    ]),
    hidden:
        spruce != null &&
        (point.x - spruce.x).abs() < spruce.width * 0.3 &&
        (point.y - spruce.y).abs() < 6,
    swayPhase: swayPhase,
    art: art,
  );
}

List<MeadowMistPocket> _pockets(
  MeadowRandom random,
  List<MeadowPlant> plants,
  MeadowYear year,
) {
  final MeadowWindow? heaviest = year.heaviest;
  if (heaviest == null) {
    return const <MeadowMistPocket>[];
  }
  final List<MeadowPlant> inside = <MeadowPlant>[
    for (final MeadowPlant plant in plants)
      if (plant.dayIndex >= heaviest.first && plant.dayIndex <= heaviest.last)
        plant,
  ];
  if (inside.length < _pocketMinimum) {
    return const <MeadowMistPocket>[];
  }
  double mean(double Function(MeadowPlant plant) of) =>
      inside.map(of).reduce((double a, double b) => a + b) / inside.length;
  final double meanX = mean((MeadowPlant plant) => plant.x);
  final double meanY = mean((MeadowPlant plant) => plant.y);
  final double meanScale = mean((MeadowPlant plant) => plant.scale);
  final double spread = inside
      .map((MeadowPlant plant) => (plant.x - meanX).abs())
      .reduce(math.max);
  return List<MeadowMistPocket>.unmodifiable(
    List<MeadowMistPocket>.generate(_pocketCount, (int i) {
      final double width =
          random.between(240, 360) * (meanScale / meadowNearScale) +
          140 +
          spread * 0.6;
      final double height = width * random.between(0.2, 0.28);
      final double x =
          meanX + random.between(-0.4, 0.4) * math.max(width, spread);
      final double y = meanY - height * random.between(0.25, 0.7);
      final double period = random.between(26, 44);
      final double phase = random.between(0, 30);
      return MeadowMistPocket(
        x: x,
        y: y,
        width: width,
        height: height,
        period: period,
        phase: phase,
      );
    }),
  );
}

List<MeadowFireflyHome> _fireflyHomes(
  MeadowRandom random,
  List<MeadowMistPocket> pockets,
  MeadowWater water,
) {
  final List<MeadowFireflyHome> homes = <MeadowFireflyHome>[
    for (final MeadowMistPocket pocket in pockets)
      for (int i = 0; i < _homesPerPocket; i++) _pocketHome(random, pocket),
  ];
  for (int i = 0; i < _streamHomes; i++) {
    final MeadowStreamSample sample =
        water.centreSamples[10 + random.nextInt(60)];
    final int side = random.next() < 0.5 ? -1 : 1;
    final double reach = sample.halfWidth + random.between(0.02, 0.2);
    final MeadowPoint point = meadowProject(
      water.streamCentre(sample.depth) + side * reach,
      sample.depth,
    );
    final double lift = random.between(8, 40) * point.scale / 0.4;
    homes.add(
      MeadowFireflyHome(
        x: point.x,
        y: point.y - lift,
        scale: point.scale / meadowNearScale,
        sync: false,
      ),
    );
  }
  return List<MeadowFireflyHome>.unmodifiable(homes);
}

MeadowFireflyHome _pocketHome(MeadowRandom random, MeadowMistPocket pocket) {
  final double x = pocket.x + random.between(-0.4, 0.4) * pocket.width;
  final double y = pocket.y + random.between(-10, 20);
  return MeadowFireflyHome(x: x, y: y, scale: _pocketHomeScale, sync: true);
}
