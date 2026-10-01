@Tags(<String>['golden'])
library;

import 'dart:ui';

import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/render/meadow_layers.dart';
import 'package:field_notes/features/garden/scene/meadow_grass.dart';
import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/meadow_pixels.dart';

void main() {
  test('the recoloured lake and waterfall match their references', () async {
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
      layers
        ..recolour(entry.value)
        ..buildAll();
      final Image lake = layers.water.first.image;
      final Image fall = layers.falls.first.body.image;
      await expectLater(
        lake,
        matchesGoldenFile('goldens/meadow_lake_${entry.key}.png'),
      );
      await expectLater(
        fall,
        matchesGoldenFile('goldens/meadow_fall_${entry.key}.png'),
      );
    }
  });
}
