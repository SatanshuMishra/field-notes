import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_grass.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:flutter_test/flutter_test.dart';

const int _year = 2025;

MeadowYear _emptyYear() => MeadowYear.build(
  days: const [],
  entryCounts: const <String, int>{},
  year: _year,
  today: DateTime(_year + 1, 3, 1),
);

void main() {
  final MeadowYear year = _emptyYear();

  test('grass bands cover the ground without crossing water', () {
    for (int key = 1; key <= 12; key++) {
      final int seed = meadowSeed(key * 7919, _year);
      final MeadowTerrain terrain = buildMeadowTerrain(seed: seed, year: year);
      final List<MeadowGrassBand> bands = buildMeadowGrass(
        seed: seed,
        terrain: terrain,
      );

      expect(bands, isNotEmpty);
      expect(bands.first.sortKey, closeTo(335.5, 1e-9));
      expect(bands.last.sortKey, greaterThanOrEqualTo(639.5));
      for (int i = 1; i < bands.length; i++) {
        final double step = bands[i].sortKey - bands[i - 1].sortKey;
        expect(step, greaterThan(0), reason: 'seed $seed band $i');
        expect(
          step,
          closeTo(6 + (bands[i - 1].sortKey + 0.5 - 330) * 0.05, 1e-9),
          reason: 'seed $seed band $i leaves a gap',
        );
      }

      int blades = 0;
      for (final MeadowGrassBand band in bands) {
        expect(band.strokes, hasLength(3));
        expect(band.colours, hasLength(3));
        for (final List<MeadowGrassStroke> shade in band.strokes) {
          for (final MeadowGrassStroke stroke in shade) {
            blades++;
            final double depth = meadowDepthAtRow(stroke.start.dy);
            final double worldX =
                (stroke.start.dx - meadowWorldWidth / 2) * depth / meadowSpread;
            expect(
              terrain.water.inLake(worldX, depth),
              isFalse,
              reason: 'seed $seed blade at $worldX, $depth',
            );
            expect(
              terrain.water.distanceToStream(worldX, depth),
              greaterThanOrEqualTo(0.004),
              reason: 'seed $seed blade at $worldX, $depth',
            );
          }
        }
      }
      expect(blades, greaterThan(1000));
    }
  });

  test('only the near bands sway', () {
    for (int key = 1; key <= 6; key++) {
      final int seed = meadowSeed(key * 104729, _year);
      final List<MeadowGrassBand> bands = buildMeadowGrass(
        seed: seed,
        terrain: buildMeadowTerrain(seed: seed, year: year),
      );

      final List<MeadowGrassBand> swaying = bands
          .where((MeadowGrassBand band) => band.animated)
          .toList();
      expect(swaying.length, greaterThanOrEqualTo(8));
      for (final MeadowGrassBand band in bands) {
        if (band.animated) {
          expect(band.depth, lessThan(2.2));
        } else {
          expect(band.depth, greaterThanOrEqualTo(2.2));
        }
      }
    }
  });
}
