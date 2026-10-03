import 'dart:ui';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/render/meadow_creature_art.dart';
import 'package:field_notes/features/garden/render/meadow_layers.dart';
import 'package:field_notes/features/garden/render/meadow_plant_atlas.dart';
import 'package:field_notes/features/garden/render/meadow_rays.dart';
import 'package:field_notes/features/garden/render/meadow_stage_painter.dart';
import 'package:field_notes/features/garden/scene/meadow_grass.dart';
import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:field_notes/features/garden/scene/meadow_plants.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart'
    hide MeadowRange;
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const int _leapYear = 2028;
const int _meadowKey = 20280229;
const double _density = 0.5;

class _CountingCanvas implements Canvas {
  final List<String> calls = <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final String symbol = invocation.memberName.toString();
    calls.add(
      symbol.substring(symbol.indexOf('"') + 1, symbol.lastIndexOf('"')),
    );
    return null;
  }

  int count(String name) => calls.where((String call) => call == name).length;
}

MeadowYear _fullYear() => MeadowYear.build(
  days: <Day>[
    for (int i = 0; i < 366; i++)
      dayOf(
        captureDateKey(DateTime(_leapYear, 1, 1 + i)),
        mood: moodOrder[(i ~/ 5) % moodOrder.length],
      ),
  ],
  entryCounts: <String, int>{},
  year: _leapYear,
  today: DateTime(_leapYear + 1, 3, 1),
);

MeadowPalette _paletteAt(DateTime instant, MeadowYear year) =>
    MeadowPalette.from(
      sky: skySceneAt(instant, 53.55, -113.4667),
      morning: false,
      heavyShare: year.heavyShare,
    );

void main() {
  testWidgets('a noon frame and a midnight frame open no offscreen layer', (
    WidgetTester tester,
  ) async {
    final FragmentProgram? nightOverlay = await tester.runAsync(
      () => FragmentProgram.fromAsset('shaders/meadow_night_overlay.frag'),
    );
    expect(nightOverlay, isNotNull);
    final MeadowYear year = _fullYear();
    final int seed = meadowSeed(_meadowKey, _leapYear);
    final MeadowTerrain terrain = buildMeadowTerrain(seed: seed, year: year);
    final MeadowPlants plants = buildMeadowPlants(
      seed: seed,
      year: year,
      terrain: terrain,
    );
    final List<MeadowGrassBand> grass = buildMeadowGrass(
      seed: seed,
      terrain: terrain,
    );
    final MeadowPalette noon = _paletteAt(
      DateTime.utc(_leapYear, 6, 21, 19, 30),
      year,
    );
    final MeadowPalette midnight = _paletteAt(
      DateTime.utc(_leapYear, 1, 15, 7),
      year,
    );
    expect(noon.glintO, greaterThan(0));
    expect(midnight.overlayAlpha, greaterThan(0));
    final MeadowLayers layers = MeadowLayers(
      terrain: terrain,
      grass: grass,
      density: _density,
    );
    final MeadowPlantAtlas atlas = MeadowPlantAtlas(plants, density: _density)
      ..buildAll();
    final MeadowCreatureArt creatures = MeadowCreatureArt.build(
      density: _density,
    );
    final MeadowRays rays = MeadowRays(noon);
    addTearDown(() {
      layers.dispose();
      atlas.dispose();
      creatures.dispose();
      rays.dispose();
    });
    for (final (String name, MeadowPalette palette)
        in <(String, MeadowPalette)>[('noon', noon), ('midnight', midnight)]) {
      layers
        ..recolour(palette)
        ..buildAll();
      rays.recolour(palette);
      final _CountingCanvas canvas = _CountingCanvas();
      MeadowStagePainter(
        layers: layers,
        layersRevision: layers.revision,
        atlas: atlas,
        creatures: creatures,
        rays: rays,
        terrain: terrain,
        plants: plants,
        palette: palette,
        viewport: const MeadowViewport(scale: 1, offset: Offset.zero, pan: 0),
        time: 42.5,
        animate: true,
        growthPoint: year.limit,
        mode: MeadowSceneMode.page,
        heaviest: year.heaviest,
        nightOverlay: nightOverlay,
      ).paint(canvas, const Size(meadowWorldWidth, meadowWorldHeight));
      expect(canvas.count('saveLayer'), 0, reason: name);
    }
  });
}
