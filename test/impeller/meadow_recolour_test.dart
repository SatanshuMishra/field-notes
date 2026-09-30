import 'dart:typed_data';
import 'dart:ui';

import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/render/meadow_layers.dart';
import 'package:field_notes/features/garden/scene/meadow_grass.dart';
import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/garden/support/meadow_pixels.dart';

void main() {
  test(
    'the recoloured mountains match drawing the prototype layers directly on Impeller',
    () async {
      final MeadowYear year = meadowPixelsLeapYear();
      final int seed = meadowSeed(20280229, meadowPixelsYear);
      final MeadowTerrain terrain = buildMeadowTerrain(seed: seed, year: year);
      final MeadowLayers layers = MeadowLayers(
        terrain: terrain,
        grass: buildMeadowGrass(seed: seed, terrain: terrain),
        density: 1,
      );
      addTearDown(layers.dispose);
      layers.buildAll();
      for (final MapEntry<String, MeadowPalette> entry in meadowPixelsPalettes(
        year,
      ).entries) {
        layers.recolour(entry.value);
        final Uint8List recoloured = await rgbaOf(layers.mountains.image);
        final Image direct = layers.drawMountainsDirectly(entry.value);
        final Uint8List drawn = await rgbaOf(direct);
        direct.dispose();
        final List<int> worst = sortedPixelDifferences(drawn, recoloured);
        final int median = percentileOf(worst, 0.5);
        final int nearlyAll = percentileOf(worst, 0.995);
        printOnFailure('${entry.key} median $median p99.5 $nearlyAll');
        expect(median, lessThanOrEqualTo(1), reason: entry.key);
        expect(nearlyAll, lessThanOrEqualTo(6), reason: entry.key);
      }
    },
  );
}
