import 'dart:isolate';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_plants.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const int _leapYear = 2028;

String _dateOf(int index) => captureDateKey(DateTime(_leapYear, 1, 1 + index));

List<Day> _days(Iterable<int> indices, {Mood Function(int index)? mood}) =>
    <Day>[
      for (final int index in indices)
        dayOf(
          _dateOf(index),
          mood: (mood ?? (int i) => Mood.values[i % Mood.values.length])(index),
        ),
    ];

MeadowYear _meadowYear(
  List<Day> days, {
  Map<String, int> entries = const <String, int>{},
  DateTime? today,
}) => MeadowYear.build(
  days: days,
  entryCounts: entries,
  year: _leapYear,
  today: today ?? DateTime(_leapYear + 1, 3, 1),
);

MeadowPlants _plantsFor(int seed, MeadowYear year) => buildMeadowPlants(
  seed: seed,
  year: year,
  terrain: buildMeadowTerrain(seed: seed, year: year),
);

double _worldX(MeadowPlant plant) =>
    (plant.x - meadowWorldWidth / 2) * plant.z / meadowSpread;

List<Object> _signature(MeadowPlant plant) => <Object>[
  plant.dayIndex,
  plant.x,
  plant.y,
  plant.scale,
  plant.z,
  plant.u,
  plant.swayPhase,
  plant.hidden,
  plant.month,
  ...plant.heads,
  plant.art.bounds,
  plant.art.layers.length,
  plant.art.placements.length,
  plant.art.shift,
  plant.art.nodDegrees,
  for (final MeadowPlantLayer layer in plant.art.layers) layer.transform,
];

Map<int, List<Object>> _byDay(MeadowPlants plants) => <int, List<Object>>{
  for (final MeadowPlant plant in plants.plants)
    plant.dayIndex: _signature(plant),
};

void main() {
  final int seed = meadowSeed(90210, _leapYear);

  test('every grown day gets exactly one plant', () {
    final MeadowYear full = _meadowYear(
      _days(List<int>.generate(366, (i) => i)),
    );
    final MeadowPlants grown = _plantsFor(seed, full);
    expect(full.daysInYear, 366);
    expect(grown.plants, hasLength(366));
    expect(
      grown.plants.map((MeadowPlant plant) => plant.dayIndex).toSet(),
      Set<int>.from(List<int>.generate(366, (int i) => i)),
    );

    final MeadowYear partial = _meadowYear(
      _days(List<int>.generate(366, (int i) => i)),
      today: DateTime(_leapYear, 6, 30),
    );
    final MeadowPlants sofar = _plantsFor(seed, partial);
    expect(partial.limit, 182);
    expect(sofar.plants, hasLength(182));
    expect(
      sofar.plants.every((MeadowPlant plant) => plant.dayIndex < 182),
      isTrue,
    );

    final MeadowYear gappy = _meadowYear(
      _days(<int>[for (int i = 0; i < 366; i += 3) i]),
      entries: <String, int>{_dateOf(10): 2, _dateOf(11): 1},
    );
    final MeadowPlants sparse = _plantsFor(seed, gappy);
    expect(
      sparse.plants.map((MeadowPlant plant) => plant.dayIndex).toList(),
      gappy.days.nonNulls.map((MeadowDay day) => day.index).toList(),
    );
    expect(
      sparse.plants
          .where((MeadowPlant plant) => plant.dayIndex == 11)
          .single
          .isSprout,
      isTrue,
    );
  });

  test('plants stay out of the water and the tree wings', () {
    final MeadowYear full = _meadowYear(
      _days(List<int>.generate(366, (i) => i)),
    );
    for (int key = 1; key <= 20; key++) {
      final int yearSeed = meadowSeed(key * 7919, _leapYear);
      final MeadowTerrain terrain = buildMeadowTerrain(
        seed: yearSeed,
        year: full,
      );
      final MeadowPlants grown = buildMeadowPlants(
        seed: yearSeed,
        year: full,
        terrain: terrain,
      );
      expect(grown.plants, hasLength(366));
      for (final MeadowPlant plant in grown.plants) {
        final double worldX = _worldX(plant);
        final String reason = 'seed $key, day ${plant.dayIndex}';
        expect(
          terrain.water.distanceToStream(worldX, plant.z),
          greaterThanOrEqualTo(0.04),
          reason: reason,
        );
        if (plant.z > 2.25) {
          expect(
            plant.x,
            inInclusiveRange(
              terrain.forest.innerAt(-1, plant.z) - 6,
              terrain.forest.innerAt(1, plant.z) + 6,
            ),
            reason: reason,
          );
        }
      }
    }
  });

  test('january grows at the far lake and december in front', () {
    final MeadowYear full = _meadowYear(
      _days(List<int>.generate(366, (i) => i)),
    );
    for (int key = 1; key <= 5; key++) {
      final MeadowPlants grown = _plantsFor(
        meadowSeed(key * 104729, _leapYear),
        full,
      );
      double meanDepth(int month) {
        final List<double> depths = <double>[
          for (final MeadowPlant plant in grown.plants)
            if (plant.month == month) plant.z,
        ];
        return depths.reduce((double a, double b) => a + b) / depths.length;
      }

      expect(meanDepth(1), greaterThan(meanDepth(12)));
      expect(meanDepth(1), greaterThan(3));
      expect(meanDepth(12), lessThan(1.2));
    }
  });

  test('changing one past day moves only its own drift', () {
    final List<int> clusters = <int>[
      for (int start = 0; start < 360; start += 10)
        for (int i = 0; i < 4; i++) start + i,
    ];
    final MeadowYear base = _meadowYear(_days(clusters));
    final Map<int, List<Object>> before = _byDay(_plantsFor(seed, base));
    expect(before, hasLength(clusters.length));
    bool inDrift(int day) => day >= 180 && day <= 184;

    final MeadowYear richer = _meadowYear(
      _days(clusters),
      entries: <String, int>{_dateOf(183): 3},
    );
    final MeadowPlants changed = _plantsFor(seed, richer);
    final Map<int, List<Object>> afterEntries = _byDay(changed);
    expect(afterEntries.keys, before.keys);
    for (final int day in before.keys.where((int day) => !inDrift(day))) {
      expect(afterEntries[day], before[day], reason: 'day $day');
    }
    expect(afterEntries[183], isNot(before[183]));
    expect(
      changed.plants
          .singleWhere((MeadowPlant plant) => plant.dayIndex == 183)
          .art
          .placements,
      hasLength(2),
    );

    final MeadowYear longer = _meadowYear(_days(<int>[...clusters, 184]));
    final Map<int, List<Object>> afterAdding = _byDay(_plantsFor(seed, longer));
    expect(afterAdding, hasLength(before.length + 1));
    for (final int day in before.keys.where((int day) => !inDrift(day))) {
      expect(afterAdding[day], before[day], reason: 'day $day');
    }
    expect(afterAdding[184], isNotNull);
  });

  test('mist pockets and firefly homes follow the heaviest stretch', () {
    final MeadowYear heavy = _meadowYear(
      _days(
        List<int>.generate(366, (int i) => i),
        mood: (int i) => i >= 200 && i < 216 ? Mood.sad : Mood.happy,
      ),
    );
    final MeadowPlants misty = _plantsFor(seed, heavy);
    expect(heavy.heaviest, isNotNull);
    expect(misty.pockets, hasLength(5));
    final List<MeadowPlant> hollow = misty.plants
        .where(
          (MeadowPlant plant) =>
              plant.dayIndex >= heavy.heaviest!.first &&
              plant.dayIndex <= heavy.heaviest!.last,
        )
        .toList();
    final double meanY =
        hollow.map((MeadowPlant plant) => plant.y).reduce((a, b) => a + b) /
        hollow.length;
    for (final MeadowMistPocket pocket in misty.pockets) {
      expect(pocket.y, lessThan(meanY));
      expect(pocket.height / pocket.width, inInclusiveRange(0.2, 0.28));
      expect(pocket.period, inInclusiveRange(26, 44));
      expect(pocket.phase, inInclusiveRange(0, 30));
    }
    expect(misty.fireflyHomes, hasLength(5 * 4 + 14));
    expect(
      misty.fireflyHomes.where((MeadowFireflyHome home) => home.sync),
      hasLength(20),
    );

    final MeadowYear quiet = _meadowYear(_days(<int>[3, 4, 5]));
    final MeadowPlants clear = _plantsFor(seed, quiet);
    expect(quiet.heaviest, isNull);
    expect(clear.pockets, isEmpty);
    expect(clear.fireflyHomes, hasLength(14));
    expect(
      clear.fireflyHomes.every((MeadowFireflyHome home) => !home.sync),
      isTrue,
    );

    final MeadowPlants again = _plantsFor(seed, heavy);
    expect(
      <Offset>[
        for (final MeadowFireflyHome home in again.fireflyHomes)
          Offset(home.x, home.y),
      ],
      <Offset>[
        for (final MeadowFireflyHome home in misty.fireflyHomes)
          Offset(home.x, home.y),
      ],
    );
  });

  test('plants cross to the main isolate unchanged', () async {
    final MeadowYear full = _meadowYear(
      _days(List<int>.generate(366, (int i) => i)),
    );
    final MeadowPlants here = _plantsFor(seed, full);
    final MeadowPlants there = await Isolate.run(() => _plantsFor(seed, full));
    expect(there.plants, hasLength(here.plants.length));
    expect(_byDay(there), _byDay(here));
    expect(there.fireflyHomes, hasLength(here.fireflyHomes.length));
  });
}
