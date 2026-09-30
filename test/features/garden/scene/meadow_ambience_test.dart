import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/render/meadow_creature_art.dart';
import 'package:field_notes/features/garden/scene/meadow_ambience.dart';
import 'package:field_notes/features/garden/scene/meadow_plants.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const int _leapYear = 2028;
const double _frame = 1 / 60;
const int _brightFirst = 150;
const int _heavyFirst = 280;
const int _windowDays = 16;

String _dateOf(int index) => captureDateKey(DateTime(_leapYear, 1, 1 + index));

const List<List<Mood>> _seasons = <List<Mood>>[
  <Mood>[Mood.tired, Mood.sad, Mood.calm, Mood.tired, Mood.anxious],
  <Mood>[Mood.calm, Mood.hopeful, Mood.anxious, Mood.tired, Mood.hopeful],
  <Mood>[Mood.hopeful, Mood.warm, Mood.calm, Mood.grateful, Mood.happy],
  <Mood>[Mood.warm, Mood.happy, Mood.grateful, Mood.love, Mood.calm],
  <Mood>[Mood.grateful, Mood.calm, Mood.tired, Mood.hopeful, Mood.warm],
  <Mood>[Mood.tired, Mood.sad, Mood.anxious, Mood.calm, Mood.angry],
];

Mood _moodOf(int index) {
  if (index >= _brightFirst && index < _brightFirst + _windowDays) {
    return Mood.happy;
  }
  if (index >= _heavyFirst && index < _heavyFirst + _windowDays) {
    return Mood.sad;
  }
  final List<Mood> season = _seasons[index * _seasons.length ~/ 366];
  return season[(index * 7 + index ~/ 3) % season.length];
}

MeadowYear _meadowYear() => MeadowYear.build(
  days: <Day>[
    for (int index = 0; index < 366; index++)
      dayOf(_dateOf(index), mood: _moodOf(index)),
  ],
  entryCounts: const <String, int>{},
  year: _leapYear,
  today: DateTime(_leapYear + 1, 3, 1),
);

class _Meadow {
  factory _Meadow() {
    final int seed = meadowSeed(424242, _leapYear);
    final MeadowYear year = _meadowYear();
    final MeadowTerrain terrain = buildMeadowTerrain(seed: seed, year: year);
    final MeadowPlants plants = buildMeadowPlants(
      seed: seed,
      year: year,
      terrain: terrain,
    );
    return _Meadow._(
      year: year,
      terrain: terrain,
      plants: plants,
      ambience: MeadowAmbience(
        seed: seed,
        terrain: terrain,
        plants: plants,
        year: year,
      ),
    );
  }

  const _Meadow._({
    required this.year,
    required this.terrain,
    required this.plants,
    required this.ambience,
  });

  final MeadowYear year;
  final MeadowTerrain terrain;
  final MeadowPlants plants;
  final MeadowAmbience ambience;

  List<MeadowPlant> get targets => <MeadowPlant>[
    for (final MeadowPlant plant in plants.plants)
      if (!plant.hidden && plant.mood != null) plant,
  ];

  MeadowPlant plantOf(int day) =>
      plants.plants.firstWhere((MeadowPlant plant) => plant.dayIndex == day);
}

double _nearestHead(MeadowPlant plant, Offset point) =>
    plant.heads.map((Offset head) => (head - point).distance).reduce(math.min);

List<double> _peakTimes(
  List<List<double>> samples,
  int firefly,
  int from,
  int to,
) {
  int best = from;
  for (int i = from; i < to; i++) {
    if (samples[i][firefly] > samples[best][firefly]) {
      best = i;
    }
  }
  return <double>[best * _frame, samples[best][firefly]];
}

Future<int> _inkedPixels(
  MeadowCreatureArt art, {
  required double wingPhase,
}) async {
  const int side = 64;
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  art.paintFlyers(
    Canvas(recorder),
    bees: const <MeadowFlyerPose>[],
    butterflies: <MeadowFlyerPose>[
      MeadowFlyerPose(
        position: const Offset(side / 2, side / 2),
        scale: 2,
        facing: 1,
        rotation: 0,
        opacity: 1,
        wingPeriod: 1.7,
        wingPhase: wingPhase,
        variant: 0,
        activity: MeadowFlyerActivity.perched,
        flower: null,
      ),
    ],
    opacity: 1,
  );
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = picture.toImageSync(side, side);
  picture.dispose();
  final ByteData bytes = (await image.toByteData())!;
  image.dispose();
  int inked = 0;
  for (int i = 3; i < bytes.lengthInBytes; i += 4) {
    if (bytes.getUint8(i) > 0) {
      inked++;
    }
  }
  return inked;
}

void main() {
  test('bees leave the hive, visit flowers and go home', () {
    final _Meadow meadow = _Meadow();
    final MeadowAmbience ambience = meadow.ambience;
    final Offset hive = meadow.terrain.forest.oldSpruce!.hive;
    final List<MeadowPlant> targets = meadow.targets;
    expect(ambience.bees, hasLength(4));
    for (final MeadowFlyerPose bee in ambience.bees) {
      expect(bee.activity, MeadowFlyerActivity.away);
      expect((bee.position - hive).distance, lessThan(0.001));
    }
    final List<bool> reached = List<bool>.filled(ambience.bees.length, false);
    final List<bool> visited = List<bool>.filled(ambience.bees.length, false);
    double? reachedAll;
    double? cameHome;
    for (int frame = 1; frame <= 240 * 60; frame++) {
      ambience.step(_frame, targets: targets, dayLife: 1, fireflies: 0);
      final double time = frame * _frame;
      for (int i = 0; i < ambience.bees.length; i++) {
        final MeadowFlyerPose bee = ambience.bees[i];
        final int? flower = bee.flower;
        if (bee.activity == MeadowFlyerActivity.perched && flower != null) {
          expect(bee.opacity, 1);
          expect(
            _nearestHead(meadow.plantOf(flower), bee.position),
            lessThan(6),
          );
          reached[i] = true;
          visited[i] = true;
        }
        if (visited[i] &&
            bee.activity == MeadowFlyerActivity.away &&
            (bee.position - hive).distance < 0.001) {
          cameHome ??= time;
        }
      }
      if (reachedAll == null && reached.every((bool done) => done)) {
        reachedAll = time;
      }
    }
    expect(reachedAll, isNotNull);
    expect(reachedAll, lessThanOrEqualTo(60));
    expect(cameHome, isNotNull);
    expect(cameHome, lessThanOrEqualTo(240));
  });

  test('butterflies favour the brightest stretch', () {
    final _Meadow meadow = _Meadow();
    final MeadowAmbience ambience = meadow.ambience;
    final MeadowWindow bright = meadow.year.brightest!;
    expect(bright.first, _brightFirst);
    expect(bright.mean, greaterThan(0.6));
    expect(ambience.butterflies, hasLength(3));
    final List<MeadowPlant> targets = meadow.targets;
    final List<MeadowFlyerActivity> before = <MeadowFlyerActivity>[
      for (final MeadowFlyerPose butterfly in ambience.butterflies)
        butterfly.activity,
    ];
    int landings = 0;
    int inside = 0;
    int insidePlants = 0;
    for (final MeadowPlant plant in targets) {
      if (plant.dayIndex >= bright.first && plant.dayIndex <= bright.last) {
        insidePlants++;
      }
    }
    for (int frame = 1; frame <= 600 * 60; frame++) {
      ambience.step(_frame, targets: targets, dayLife: 1, fireflies: 0);
      for (int i = 0; i < ambience.butterflies.length; i++) {
        final MeadowFlyerPose butterfly = ambience.butterflies[i];
        final int? flower = butterfly.flower;
        if (before[i] == MeadowFlyerActivity.flying &&
            butterfly.activity == MeadowFlyerActivity.perched &&
            flower != null) {
          landings++;
          if (flower >= bright.first && flower <= bright.last) {
            inside++;
          }
        }
        before[i] = butterfly.activity;
      }
    }
    expect(insidePlants / targets.length, lessThan(0.1));
    expect(landings, greaterThan(30));
    expect(inside / landings, greaterThan(0.5));
  });

  test('fireflies show only at night and flash together in the mist', () {
    final _Meadow meadow = _Meadow();
    final MeadowAmbience ambience = meadow.ambience;
    final List<MeadowPlant> targets = meadow.targets;
    expect(meadow.plants.pockets, isNotEmpty);
    expect(ambience.fireflies, hasLength(28));
    for (int frame = 0; frame < 10 * 60; frame++) {
      ambience.step(_frame, targets: targets, dayLife: 0, fireflies: 0);
      for (final MeadowFireflyPose firefly in ambience.fireflies) {
        expect(firefly.opacity, 0);
      }
    }
    final List<int> pocket = <int>[
      for (int i = 0; i < ambience.fireflies.length; i++)
        if (ambience.fireflies[i].inMist) i,
    ];
    expect(pocket.length, greaterThanOrEqualTo(2));
    final List<List<double>> samples = <List<double>>[];
    for (int frame = 0; frame < 3 * 126; frame++) {
      ambience.step(_frame, targets: targets, dayLife: 0, fireflies: 1);
      samples.add(<double>[
        for (final MeadowFireflyPose firefly in ambience.fireflies)
          firefly.opacity,
      ]);
    }
    final double first = _peakTimes(samples, pocket.first, 126, 252).first;
    final int around = (first / _frame).round();
    final List<double> peaks = <double>[
      for (final int i in pocket)
        _peakTimes(samples, i, around - 63, around + 63).first,
    ];
    for (final int i in pocket) {
      expect(
        _peakTimes(samples, i, around - 63, around + 63).last,
        greaterThan(0.95),
      );
    }
    expect(peaks.reduce(math.max) - peaks.reduce(math.min), lessThan(0.15));
  });

  test('creature images flap with their phase and stay small', () async {
    final MeadowCreatureArt page = MeadowCreatureArt.build(
      density: 1100 / 1400 * 2,
    );
    final MeadowCreatureArt full = MeadowCreatureArt.build(
      density: 868.6 / 640 * 2.625,
    );
    expect(page.imageBytes, lessThan(300 * 1024));
    expect(full.imageBytes, lessThan(300 * 1024));
    expect(meadowWingSpread(0), 1);
    expect(meadowWingSpread(0.5), closeTo(0.42, 1e-9));
    expect(meadowWingSpread(0.2), closeTo(meadowWingSpread(0.8), 1e-9));
    final int open = await _inkedPixels(full, wingPhase: 0);
    final int closed = await _inkedPixels(full, wingPhase: 0.5);
    expect(open, greaterThan(0));
    expect(closed, lessThan(open * 0.8));
    final _Meadow meadow = _Meadow();
    meadow.ambience.step(
      _frame,
      targets: meadow.targets,
      dayLife: 1,
      fireflies: 1,
    );
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    full.paintFlyers(
      canvas,
      bees: meadow.ambience.bees,
      butterflies: meadow.ambience.butterflies,
      opacity: 1,
    );
    full.paintFireflies(canvas, meadow.ambience.fireflies);
    recorder.endRecording().dispose();
    page.dispose();
    full.dispose();
  });
}
