import 'dart:isolate';
import 'dart:ui';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const int _year = 2025;

List<Day> _run(int first, int length, Mood mood) => <Day>[
  for (int i = 0; i < length; i++)
    dayOf(captureDateKey(DateTime(_year, 1, 1 + first + i)), mood: mood),
];

MeadowYear _meadowYear(List<Day> days) => MeadowYear.build(
  days: days,
  entryCounts: const <String, int>{},
  year: _year,
  today: DateTime(_year + 1, 3, 1),
);

List<int> _seeds(int count) => <int>[
  for (int key = 1; key <= count; key++) meadowSeed(key * 7919, _year),
];

List<Offset> _ridges(MeadowTerrain terrain) => <Offset>[
  ...terrain.mountains.far.ridge,
  ...terrain.mountains.high.ridge,
  ...terrain.mountains.massif.ridge,
];

List<(double, double, double, double, bool, int)> _trees(
  MeadowTerrain terrain,
) => <(double, double, double, double, bool, int)>[
  for (final MeadowTree tree in terrain.forest.trees)
    (tree.x, tree.y, tree.depth, tree.height, tree.aspen, tree.side),
];

List<(Rect, double, double, double, int)> _clouds(MeadowTerrain terrain) =>
    <(Rect, double, double, double, int)>[
      for (final MeadowCloud cloud in terrain.sky.clouds)
        (
          cloud.bounds,
          cloud.opacity,
          cloud.period,
          cloud.phase,
          cloud.puffs.length,
        ),
    ];

List<(Offset, double, double)> _puffs(MeadowTerrain terrain) =>
    <(Offset, double, double)>[
      for (final MeadowCloud cloud in terrain.sky.clouds)
        for (final MeadowEllipse puff in cloud.puffs)
          (puff.centre, puff.radiusX, puff.radiusY),
    ];

void main() {
  final MeadowYear mixed = _meadowYear(<Day>[
    ..._run(20, 9, Mood.calm),
    ..._run(120, 5, Mood.sad),
    ..._run(240, 3, Mood.hopeful),
  ]);

  test(
    'the same seed builds the same terrain and another seed a different one',
    () {
      final int seed = meadowSeed(424242, _year);
      final MeadowTerrain first = buildMeadowTerrain(seed: seed, year: mixed);
      final MeadowTerrain again = buildMeadowTerrain(seed: seed, year: mixed);
      final MeadowTerrain other = buildMeadowTerrain(
        seed: meadowSeed(424243, _year),
        year: mixed,
      );

      expect(first.water.lakeOutline, hasLength(90));
      expect(first.mountains.far.ridge, hasLength(129));
      expect(first.mountains.high.ridge, hasLength(129));
      expect(first.mountains.massif.ridge, hasLength(129));
      expect(first.forest.trees, isNotEmpty);
      expect(first.sky.clouds, isNotEmpty);

      expect(again.water.lakeOutline, first.water.lakeOutline);
      expect(_ridges(again), _ridges(first));
      expect(_trees(again), _trees(first));
      expect(_clouds(again), _clouds(first));
      expect(_puffs(again), _puffs(first));

      expect(other.water.lakeOutline, isNot(first.water.lakeOutline));
      expect(_ridges(other), isNot(_ridges(first)));
      expect(_trees(other), isNot(_trees(first)));
      expect(_clouds(other), isNot(_clouds(first)));
    },
  );

  test('no tree stands in the lake or the stream', () {
    for (final int seed in _seeds(20)) {
      final MeadowTerrain terrain = buildMeadowTerrain(seed: seed, year: mixed);
      final MeadowWater water = terrain.water;
      expect(terrain.forest.trees, isNotEmpty);
      for (final MeadowTree tree in terrain.forest.trees) {
        final MeadowPoint drawn = meadowProject(tree.worldX, tree.depth);
        expect(drawn.x, closeTo(tree.x, 1e-6));
        expect(drawn.y, closeTo(tree.y, 1e-6));
        expect(
          water.inLake(tree.worldX, tree.depth),
          isFalse,
          reason: 'seed $seed tree at ${tree.worldX}, ${tree.depth}',
        );
        expect(
          water.distanceToStream(tree.worldX, tree.depth),
          greaterThanOrEqualTo(0.14),
          reason: 'seed $seed tree at ${tree.worldX}, ${tree.depth}',
        );
      }
    }
  });

  test('the old spruce stands only for a run of seven days or more', () {
    final MeadowYear six = _meadowYear(_run(40, 6, Mood.warm));
    final MeadowYear seven = _meadowYear(_run(40, 7, Mood.warm));
    expect(six.longestRun.length, 6);
    expect(seven.longestRun.length, 7);

    int displacedSomewhere = 0;
    for (final int seed in _seeds(12)) {
      final MeadowTerrain without = buildMeadowTerrain(seed: seed, year: six);
      final MeadowTerrain withSpruce = buildMeadowTerrain(
        seed: seed,
        year: seven,
      );
      expect(without.forest.oldSpruce, isNull);

      final MeadowOldSpruce spruce = withSpruce.forest.oldSpruce!;
      expect(spruce.day, 46);
      expect(
        spruce.depth,
        closeTo(meadowDepthOf(43 / 364).clamp(2.4, 4.2), 1e-12),
      );
      expect(
        spruce.side,
        withSpruce.water.streamCentre(spruce.depth) > 0 ? -1 : 1,
      );
      expect(
        withSpruce.forest.trees.where(
          (MeadowTree tree) => spruce.displaces(tree.x, tree.y),
        ),
        isEmpty,
      );

      final int displaced = without.forest.trees
          .where((MeadowTree tree) => spruce.displaces(tree.x, tree.y))
          .length;
      expect(
        withSpruce.forest.trees.length,
        without.forest.trees.length - displaced,
      );
      displacedSomewhere += displaced;
    }
    expect(displacedSomewhere, greaterThan(0));
  });

  test('one or two waterfalls and clouds from the share of heavy days', () {
    final MeadowYear clear = _meadowYear(_run(10, 10, Mood.happy));
    final MeadowYear heavy = _meadowYear(<Day>[
      ..._run(10, 6, Mood.sad),
      ..._run(30, 4, Mood.happy),
    ]);
    expect(clear.heavyShare, 0);
    expect(heavy.heavyShare, closeTo(0.6, 1e-12));

    final Set<int> fallCounts = <int>{};
    final Map<MeadowYear, List<int>> cloudCounts = <MeadowYear, List<int>>{
      clear: <int>[],
      heavy: <int>[],
    };
    for (final MeadowYear year in <MeadowYear>[clear, heavy]) {
      final int fewest = (2 + 5 * year.heavyShare).round();
      final int most = (4 + 5 * year.heavyShare).round();
      for (final int seed in _seeds(20)) {
        final MeadowTerrain terrain = buildMeadowTerrain(
          seed: seed,
          year: year,
        );
        final int falls = terrain.mountains.falls.length;
        expect(falls, inInclusiveRange(1, 2), reason: 'seed $seed');
        fallCounts.add(falls);
        for (final MeadowFall fall in terrain.mountains.falls) {
          expect(fall.base, terrain.water.lakeTopAt(fall.x) + 1);
          expect(fall.top, lessThan(fall.bend));
          expect(fall.bend, lessThan(fall.base));
          expect(fall.centreLine, hasLength(25));
        }
        final int clouds = terrain.sky.clouds.length;
        expect(clouds, inInclusiveRange(fewest, most), reason: 'seed $seed');
        cloudCounts[year]!.add(clouds);
      }
    }
    expect(fallCounts, <int>{1, 2});
    expect(
      cloudCounts[heavy]!.reduce((int a, int b) => a < b ? a : b),
      greaterThan(cloudCounts[clear]!.reduce((int a, int b) => a > b ? a : b)),
    );
  });

  test('the terrain builds in a background isolate', () async {
    final int seed = meadowSeed(31337, _year);
    final MeadowTerrain local = buildMeadowTerrain(seed: seed, year: mixed);
    final MeadowTerrain sent = await Isolate.run(
      () => buildMeadowTerrain(seed: seed, year: mixed),
    );

    expect(sent.water.lakeOutline, local.water.lakeOutline);
    expect(_ridges(sent), _ridges(local));
    expect(_trees(sent), _trees(local));
    expect(_clouds(sent), _clouds(local));
  });
}
