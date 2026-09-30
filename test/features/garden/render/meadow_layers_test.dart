import 'dart:typed_data';
import 'dart:ui';

import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/render/meadow_layers.dart';
import 'package:field_notes/features/garden/scene/meadow_grass.dart';
import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/meadow_pixels.dart';

const double _phoneRatio = 2.625;
const double _macRatio = 2;
const Size _phoneScreen = Size(1080 / _phoneRatio, 2280 / _phoneRatio);
const Size _sidebarCard = Size(1100, 502.9);
const Size _bottomBarCard = Size(400, 300);

int _changedPixels(Uint8List first, Uint8List second) {
  int changed = 0;
  for (int i = 0; i < first.length; i += 4) {
    if (first[i] != second[i] ||
        first[i + 1] != second[i + 1] ||
        first[i + 2] != second[i + 2] ||
        first[i + 3] != second[i + 3]) {
      changed++;
    }
  }
  return changed;
}

double _viewportDensity(
  Size box, {
  required bool cover,
  required double ratio,
}) => MeadowViewport.resolve(box: box, cover: cover, focusX: 700).scale * ratio;

List<Image> _pieces(MeadowLayers layers) => <Image>[
  layers.mountains.image,
  for (final MeadowImage tile in layers.water) tile.image,
  for (final MeadowFallLayer fall in layers.falls) fall.body.image,
  for (final MeadowCloudImage cloud in layers.clouds) cloud.image.image,
];

List<int> _redrawn(List<Image> before, List<Image> after) => <int>[
  for (int i = 0; i < before.length; i++)
    if (!identical(before[i], after[i])) i,
];

void main() {
  final MeadowYear year = meadowPixelsLeapYear();
  final int seed = meadowSeed(20280229, meadowPixelsYear);
  final MeadowTerrain terrain = buildMeadowTerrain(seed: seed, year: year);
  final List<MeadowGrassBand> grass = buildMeadowGrass(
    seed: seed,
    terrain: terrain,
  );
  final Map<String, MeadowPalette> palettes = meadowPixelsPalettes(year);
  final MeadowPalette noon = palettes['noon']!;
  final MeadowPalette dusk = palettes['dusk']!;
  final MeadowPalette midnight = palettes['midnight']!;

  test('a sky change recolours the landscape without rebuilding it', () async {
    final MeadowLayers layers = MeadowLayers(
      terrain: terrain,
      grass: grass,
      density: 0.5,
    );
    addTearDown(layers.dispose);
    layers
      ..recolour(noon)
      ..buildAll();
    expect(layers.isReady, isTrue);
    final int recorded = layers.geometryRecordings;
    expect(recorded, greaterThan(0));
    final Uint8List day = await rgbaOf(layers.mountains.image);

    layers
      ..recolour(midnight)
      ..buildAll();

    expect(layers.geometryRecordings, recorded);
    final Uint8List night = await rgbaOf(layers.mountains.image);
    expect(night, hasLength(day.length));
    expect(_changedPixels(day, night), greaterThan(day.length ~/ 4 ~/ 4));
  });

  test('the landscape images fit the memory ceiling', () {
    final List<(String, double, int)> views = <(String, double, int)>[
      (
        'full screen on the phone',
        _viewportDensity(_phoneScreen, cover: true, ratio: _phoneRatio),
        meadowLayerBudget,
      ),
      (
        'sidebar page',
        _viewportDensity(_sidebarCard, cover: false, ratio: _macRatio),
        meadowLayerPageBudget,
      ),
      (
        'bottom-bar page',
        _viewportDensity(_bottomBarCard, cover: true, ratio: _phoneRatio),
        meadowLayerPageBudget,
      ),
    ];
    for (final (String name, double wanted, int budget) in views) {
      final double density = MeadowLayers.fitDensity(
        terrain: terrain,
        grass: grass,
        density: wanted,
        maxBytes: budget,
      );
      final MeadowLayers layers = MeadowLayers(
        terrain: terrain,
        grass: grass,
        density: density,
      );
      layers
        ..recolour(noon)
        ..buildAll();

      expect(layers.imageBytes, lessThanOrEqualTo(budget), reason: name);
      expect(
        layers.imageBytes,
        MeadowLayers.bytesAt(terrain: terrain, grass: grass, density: density),
        reason: name,
      );
      expect(density, lessThanOrEqualTo(wanted), reason: name);

      layers.dispose();
      expect(layers.imageBytes, 0, reason: name);
    }
  });

  test(
    'the recoloured mountains match drawing the prototype layers directly',
    () async {
      final MeadowLayers layers = MeadowLayers(
        terrain: terrain,
        grass: grass,
        density: 1,
      );
      addTearDown(layers.dispose);
      layers.buildAll();
      for (final MeadowPalette palette in <MeadowPalette>[
        noon,
        dusk,
        midnight,
        noon,
      ]) {
        layers
          ..recolour(palette)
          ..buildAll();
        final Uint8List recoloured = await rgbaOf(layers.mountains.image);
        final Image direct = layers.drawMountainsDirectly(palette);
        final Uint8List drawn = await rgbaOf(direct);
        direct.dispose();
        final List<int> worst = sortedPixelDifferences(drawn, recoloured);
        final int median = percentileOf(worst, 0.5);
        final int nearlyAll = percentileOf(worst, 0.995);
        expect(median, lessThanOrEqualTo(1));
        expect(nearlyAll, lessThanOrEqualTo(4));
      }
    },
  );

  test(
    'a recolour redraws one piece per step, the mountains first and the lake straight after',
    () {
      final MeadowLayers layers = MeadowLayers(
        terrain: terrain,
        grass: grass,
        density: 0.5,
      );
      addTearDown(layers.dispose);
      layers
        ..recolour(noon)
        ..buildAll();
      expect(layers.isReady, isTrue);
      final List<Image> before = _pieces(layers);

      layers.recolour(midnight);

      expect(
        _redrawn(before, _pieces(layers)),
        isEmpty,
        reason: 'the recolour call itself redraws nothing',
      );
      final List<int> order = <int>[];
      List<Image> previous = before;
      bool more = true;
      while (more && order.length <= before.length) {
        more = layers.step();
        final List<Image> now = _pieces(layers);
        final List<int> redrawn = _redrawn(previous, now);
        expect(redrawn, hasLength(1), reason: 'step ${order.length + 1}');
        order.add(redrawn.single);
        previous = now;
      }
      expect(order, <int>[for (int i = 0; i < before.length; i++) i]);
      expect(layers.step(), isFalse);
      expect(_redrawn(previous, _pieces(layers)), isEmpty);
    },
  );

  test('the layers are not ready until every piece has its first colours', () {
    final MeadowLayers layers = MeadowLayers(
      terrain: terrain,
      grass: grass,
      density: 0.5,
    );
    addTearDown(layers.dispose);
    layers.recolour(noon);
    while (!layers.isBuilt) {
      layers.step();
    }

    expect(layers.isReady, isFalse, reason: 'built but not yet coloured');
    int pieces = 0;
    while (!layers.isReady && pieces < 100) {
      layers.step();
      pieces++;
    }
    expect(layers.isReady, isTrue);
    expect(pieces, _pieces(layers).length);
  });

  test(
    'while the sky keeps changing every piece keeps up and the lake follows the mountains',
    () async {
      final MeadowLayers layers = MeadowLayers(
        terrain: terrain,
        grass: grass,
        density: 0.5,
      );
      addTearDown(layers.dispose);
      layers
        ..recolour(noon)
        ..buildAll();
      final int count = _pieces(layers).length;
      final int lakeTiles = layers.water.length;
      final List<MeadowPalette> sweep = <MeadowPalette>[dusk, midnight, noon];
      final List<int> lastDrawn = List<int>.filled(count, 0);
      final List<int> order = <int>[];
      List<Image> previous = _pieces(layers);
      for (int step = 1; step <= 3 * count; step++) {
        layers.recolour(sweep[step % sweep.length]);
        expect(
          _redrawn(previous, _pieces(layers)),
          isEmpty,
          reason: 'the recolour call at step $step',
        );
        layers.step();
        final List<Image> now = _pieces(layers);
        final List<int> redrawn = _redrawn(previous, now);
        expect(redrawn, hasLength(1), reason: 'step $step');
        lastDrawn[redrawn.single] = step;
        order.add(redrawn.single);
        if (step >= count) {
          for (int i = 0; i < count; i++) {
            expect(
              step - lastDrawn[i],
              lessThan(count),
              reason: 'piece $i at step $step',
            );
          }
        }
        previous = now;
      }
      for (int i = 0; i < order.length; i++) {
        if (order[i] == 0) {
          for (
            int tile = 1;
            tile <= lakeTiles && i + tile < order.length;
            tile++
          ) {
            expect(
              order[i + tile],
              tile,
              reason: 'after the mountains at ${i + 1}',
            );
          }
        }
      }

      layers.recolour(midnight);
      int calls = 0;
      bool more = true;
      while (more && calls <= count + lakeTiles) {
        more = layers.step();
        calls++;
      }
      expect(more, isFalse);
      expect(calls, lessThanOrEqualTo(count + lakeTiles));

      final MeadowLayers fresh = MeadowLayers(
        terrain: terrain,
        grass: grass,
        density: 0.5,
      );
      addTearDown(fresh.dispose);
      fresh
        ..recolour(midnight)
        ..buildAll();
      final List<Image> settled = _pieces(layers);
      final List<Image> direct = _pieces(fresh);
      for (int i = 0; i < count; i++) {
        expect(
          await rgbaOf(settled[i]),
          await rgbaOf(direct[i]),
          reason: 'piece $i',
        );
      }
    },
  );
}
