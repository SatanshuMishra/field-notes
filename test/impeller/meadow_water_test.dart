import 'dart:io';
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

const String _references = 'test/features/garden/render/goldens';

Future<Uint8List> _reference(String name) async {
  final Codec codec = await instantiateImageCodec(
    File('$_references/$name.png').readAsBytesSync(),
  );
  final FrameInfo frame = await codec.getNextFrame();
  final Uint8List rgba = await rgbaOf(frame.image);
  frame.image.dispose();
  codec.dispose();
  return rgba;
}

void main() {
  test(
    'the recoloured lake and waterfall match their Skia references',
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
        final List<int> lake = sortedPixelDifferences(
          await rgbaOf(layers.water.first.image),
          await _reference('meadow_lake_${entry.key}'),
        );
        final List<int> fall = sortedPixelDifferences(
          await rgbaOf(layers.falls.first.body.image),
          await _reference('meadow_fall_${entry.key}'),
        );
        printOnFailure(
          '${entry.key} lake median ${percentileOf(lake, 0.5)} '
          'fall p95 ${percentileOf(fall, 0.95)}',
        );
        expect(
          percentileOf(lake, 0.5),
          lessThanOrEqualTo(1),
          reason: entry.key,
        );
        expect(
          percentileOf(fall, 0.95),
          lessThanOrEqualTo(4),
          reason: entry.key,
        );
      }
    },
  );
}
