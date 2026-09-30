import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/render/meadow_layers.dart';
import 'package:field_notes/features/garden/scene/meadow_grass.dart';
import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const int _year = 2028;
const double _latitude = 53.55;
const double _longitude = -113.4667;
const double _phoneRatio = 2.625;
const double _macRatio = 2;
const Size _phoneScreen = Size(1080 / _phoneRatio, 2280 / _phoneRatio);
const Size _sidebarCard = Size(1100, 502.9);
const Size _bottomBarCard = Size(400, 300);

MeadowYear _leapYear() => MeadowYear.build(
  days: <Day>[
    for (int i = 0; i < 366; i++)
      dayOf(
        captureDateKey(DateTime(_year, 1, 1 + i)),
        mood: moodOrder[(i ~/ 5) % moodOrder.length],
      ),
  ],
  entryCounts: const <String, int>{},
  year: _year,
  today: DateTime(_year + 1, 3, 1),
);

MeadowPalette _paletteAt(DateTime instant, MeadowYear year) =>
    MeadowPalette.from(
      sky: skySceneAt(instant, _latitude, _longitude),
      morning: false,
      heavyShare: year.heavyShare,
    );

Future<Uint8List> _pixels(Image image) async {
  final ByteData data = (await image.toByteData(
    format: ImageByteFormat.rawRgba,
  ))!;
  return data.buffer.asUint8List();
}

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

void main() {
  final MeadowYear year = _leapYear();
  final int seed = meadowSeed(20280229, _year);
  final MeadowTerrain terrain = buildMeadowTerrain(seed: seed, year: year);
  final List<MeadowGrassBand> grass = buildMeadowGrass(
    seed: seed,
    terrain: terrain,
  );
  final MeadowPalette noon = _paletteAt(
    DateTime.utc(_year, 6, 21, 19, 30),
    year,
  );
  final MeadowPalette dusk = _paletteAt(
    DateTime.utc(_year, 6, 22, 4, 10),
    year,
  );
  final MeadowPalette midnight = _paletteAt(
    DateTime.utc(_year, 1, 15, 7),
    year,
  );

  test('a sky change recolours the landscape without rebuilding it', () async {
    final MeadowLayers layers = MeadowLayers(
      terrain: terrain,
      grass: grass,
      density: 0.5,
    );
    addTearDown(layers.dispose);
    layers
      ..buildAll()
      ..recolour(noon);
    expect(layers.isReady, isTrue);
    final int recorded = layers.geometryRecordings;
    expect(recorded, greaterThan(0));
    final Uint8List day = await _pixels(layers.mountains.image);

    layers.recolour(midnight);

    expect(layers.geometryRecordings, recorded);
    final Uint8List night = await _pixels(layers.mountains.image);
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
        ..buildAll()
        ..recolour(noon);

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
        layers.recolour(palette);
        final Uint8List recoloured = await _pixels(layers.mountains.image);
        final Image direct = layers.drawMountainsDirectly(palette);
        final Uint8List drawn = await _pixels(direct);
        direct.dispose();
        final List<int> worst = <int>[];
        for (int i = 0; i < drawn.length; i += 4) {
          int difference = 0;
          for (int channel = 0; channel < 4; channel++) {
            difference = math.max(
              difference,
              (drawn[i + channel] - recoloured[i + channel]).abs(),
            );
          }
          worst.add(difference);
        }
        worst.sort();
        final int median = worst[worst.length ~/ 2];
        final int nearlyAll = worst[(worst.length * 0.995).floor()];
        expect(median, lessThanOrEqualTo(1));
        expect(nearlyAll, lessThanOrEqualTo(4));
      }
    },
  );
}
