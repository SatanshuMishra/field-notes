import 'dart:typed_data';
import 'dart:ui';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/render/meadow_creature_art.dart';
import 'package:field_notes/features/garden/render/meadow_layers.dart';
import 'package:field_notes/features/garden/render/meadow_motion.dart';
import 'package:field_notes/features/garden/render/meadow_plant_atlas.dart';
import 'package:field_notes/features/garden/render/meadow_rays.dart';
import 'package:field_notes/features/garden/render/meadow_stage_painter.dart';
import 'package:field_notes/features/garden/scene/meadow_ambience.dart';
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
const double _step = 1 / 60;
const double _watch = 300;
const double _landingJump = 1.25;
const double _landingTurn = 0.06;
const int _settleFrames = 3;

class _Call {
  const _Call(this.name, this.arguments);

  final String name;
  final List<Object?> arguments;
}

class _RecordingCanvas implements Canvas {
  final List<_Call> calls = <_Call>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final String symbol = invocation.memberName.toString();
    calls.add(
      _Call(
        symbol.substring(symbol.indexOf('"') + 1, symbol.lastIndexOf('"')),
        invocation.positionalArguments,
      ),
    );
    return null;
  }
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

class _Scene {
  _Scene() {
    year = _fullYear();
    seed = meadowSeed(_meadowKey, _leapYear);
    terrain = buildMeadowTerrain(seed: seed, year: year);
    plants = buildMeadowPlants(seed: seed, year: year, terrain: terrain);
    final List<MeadowGrassBand> grass = buildMeadowGrass(
      seed: seed,
      terrain: terrain,
    );
    noon = MeadowPalette.from(
      sky: skySceneAt(DateTime.utc(_leapYear, 6, 21, 19, 30), 53.55, -113.4667),
      morning: false,
      heavyShare: year.heavyShare,
    );
    layers = MeadowLayers(terrain: terrain, grass: grass, density: _density)
      ..recolour(noon)
      ..buildAll();
    atlas = MeadowPlantAtlas(plants, density: _density)..buildAll();
    creatures = MeadowCreatureArt.build(density: _density);
    rays = MeadowRays(noon);
  }

  late final MeadowYear year;
  late final int seed;
  late final MeadowTerrain terrain;
  late final MeadowPlants plants;
  late final MeadowPalette noon;
  late final MeadowLayers layers;
  late final MeadowPlantAtlas atlas;
  late final MeadowCreatureArt creatures;
  late final MeadowRays rays;

  List<MeadowPlant> get targets => <MeadowPlant>[
    for (final MeadowPlant plant in plants.plants)
      if (!plant.hidden && plant.mood != null) plant,
  ];

  _RecordingCanvas paint(
    double time, {
    List<MeadowFlyerPose> bees = const <MeadowFlyerPose>[],
    List<MeadowFlyerPose> butterflies = const <MeadowFlyerPose>[],
  }) {
    final _RecordingCanvas canvas = _RecordingCanvas();
    MeadowStagePainter(
      layers: layers,
      layersRevision: layers.revision,
      atlas: atlas,
      creatures: creatures,
      rays: rays,
      terrain: terrain,
      plants: plants,
      palette: noon,
      viewport: const MeadowViewport(scale: 1, offset: Offset.zero, pan: 0),
      time: time,
      animate: true,
      growthPoint: year.limit,
      mode: MeadowSceneMode.full,
      bees: bees,
      butterflies: butterflies,
    ).paint(canvas, const Size(meadowWorldWidth, meadowWorldHeight));
    return canvas;
  }

  Offset drawnHead(_RecordingCanvas canvas, MeadowPlant plant, Offset head) {
    final MeadowPlantSprite sprite = atlas.spriteOf(plant.dayIndex)!;
    final RSTransform rest = atlas.placement(sprite);
    final double x = (head.dx - rest.tx) / rest.scos;
    final double y = (head.dy - rest.ty) / rest.scos;
    for (final _Call call in canvas.calls) {
      if (call.name != 'drawRawAtlas') {
        continue;
      }
      final Float32List transforms = call.arguments[1]! as Float32List;
      final Float32List rects = call.arguments[2]! as Float32List;
      for (int i = 0; i < rects.length ~/ 4; i++) {
        if (rects[i * 4] == sprite.source.left &&
            rects[i * 4 + 1] == sprite.source.top &&
            rects[i * 4 + 2] == sprite.source.right &&
            rects[i * 4 + 3] == sprite.source.bottom) {
          final double scos = transforms[i * 4];
          final double ssin = transforms[i * 4 + 1];
          return Offset(
            scos * x - ssin * y + transforms[i * 4 + 2],
            ssin * x + scos * y + transforms[i * 4 + 3],
          );
        }
      }
    }
    throw StateError('flower ${plant.dayIndex} was not drawn');
  }

  List<Offset> flyerPositions(_RecordingCanvas canvas) {
    final List<Offset> positions = <Offset>[];
    for (int i = 0; i < canvas.calls.length; i++) {
      final _Call call = canvas.calls[i];
      if (call.name == 'save' &&
          i + 1 < canvas.calls.length &&
          canvas.calls[i + 1].name == 'translate') {
        final int draw = canvas.calls.indexWhere(
          (_Call c) => c.name == 'drawImageRect' || c.name == 'restore',
          i + 2,
        );
        if (draw >= 0 &&
            canvas.calls[draw].name == 'drawImageRect' &&
            identical(canvas.calls[draw].arguments[0], creatures.image)) {
          final List<Object?> at = canvas.calls[i + 1].arguments;
          positions.add(Offset(at[0]! as double, at[1]! as double));
        }
      }
    }
    return positions;
  }

  List<(Offset, double)> flyerPoses(_RecordingCanvas canvas) {
    final List<(Offset, double)> poses = <(Offset, double)>[];
    for (int i = 0; i + 1 < canvas.calls.length; i++) {
      if (canvas.calls[i].name != 'save' ||
          canvas.calls[i + 1].name != 'translate') {
        continue;
      }
      final int draw = canvas.calls.indexWhere(
        (_Call c) => c.name == 'drawImageRect' || c.name == 'restore',
        i + 2,
      );
      if (draw < 0 ||
          canvas.calls[draw].name != 'drawImageRect' ||
          !identical(canvas.calls[draw].arguments[0], creatures.image)) {
        continue;
      }
      final List<Object?> at = canvas.calls[i + 1].arguments;
      final double turn = canvas.calls[i + 2].name == 'rotate'
          ? canvas.calls[i + 2].arguments[0]! as double
          : 0;
      poses.add((Offset(at[0]! as double, at[1]! as double), turn));
    }
    return poses;
  }

  double? flyerRotation(_RecordingCanvas canvas) {
    for (int i = 0; i + 2 < canvas.calls.length; i++) {
      if (canvas.calls[i].name == 'save' &&
          canvas.calls[i + 1].name == 'translate') {
        final int draw = canvas.calls.indexWhere(
          (_Call c) => c.name == 'drawImageRect' || c.name == 'restore',
          i + 2,
        );
        if (draw >= 0 &&
            canvas.calls[draw].name == 'drawImageRect' &&
            identical(canvas.calls[draw].arguments[0], creatures.image)) {
          return canvas.calls[i + 2].name == 'rotate'
              ? canvas.calls[i + 2].arguments[0]! as double
              : 0;
        }
      }
    }
    return null;
  }

  void dispose() {
    layers.dispose();
    atlas.dispose();
    creatures.dispose();
    rays.dispose();
  }
}

MeadowFlyerPose _perchedBee(Offset at, int flower) => MeadowFlyerPose(
  position: at,
  scale: 0.6,
  facing: 1,
  rotation: 0,
  opacity: 1,
  wingPeriod: 0.13,
  wingPhase: 0,
  variant: 0,
  activity: MeadowFlyerActivity.perched,
  flower: flower,
);

void main() {
  late _Scene scene;

  setUpAll(() {
    scene = _Scene();
  });

  tearDownAll(() {
    scene.dispose();
  });

  test(
    'a perched insect rides the sway of its flower, tilts with it, and lands '
    'and leaves without a jump',
    () {
      final MeadowPlant plant = scene.targets.firstWhere(
        (MeadowPlant plant) =>
            plant.heads.isNotEmpty &&
            scene.atlas.spriteOf(plant.dayIndex) != null,
      );
      final Offset head = plant.heads.last;
      double widest = 0;
      double narrowest = 0;
      double widestAngle = -1;
      double narrowestAngle = 1;
      for (double t = 0; t < meadowSwayPeriod; t += 0.05) {
        final double angle = meadowSwayAngle(t - plant.swayPhase);
        if (angle > widestAngle) {
          widestAngle = angle;
          widest = t;
        }
        if (angle < narrowestAngle) {
          narrowestAngle = angle;
          narrowest = t;
        }
      }
      final List<Offset> heads = <Offset>[];
      for (final double time in <double>[widest, narrowest]) {
        final _RecordingCanvas frame = scene.paint(
          time,
          bees: <MeadowFlyerPose>[_perchedBee(head, plant.dayIndex)],
        );
        final Offset drawn = scene.drawnHead(frame, plant, head);
        heads.add(drawn);
        final List<Offset> bees = scene.flyerPositions(frame);
        expect(bees, hasLength(1));
        expect(
          (bees.single - drawn).distance,
          lessThan(0.01),
          reason: 'at $time',
        );
        expect(
          scene.flyerRotation(frame),
          closeTo(meadowSwayAngle(time - plant.swayPhase), 1e-6),
          reason: 'at $time',
        );
      }
      expect((heads.first - heads.last).distance, greaterThan(0.5));
      final MeadowAmbience ambience = MeadowAmbience(
        seed: scene.seed,
        terrain: scene.terrain,
        plants: scene.plants,
        year: scene.year,
      );
      final List<MeadowPlant> targets = scene.targets;
      List<MeadowFlyerPose> flyers(MeadowAmbience a) => <MeadowFlyerPose>[
        ...a.bees,
        ...a.butterflies,
      ];
      Map<int, (Offset, double)> drawn(
        double time,
        List<MeadowFlyerPose> poses,
      ) {
        final int bees = ambience.bees.length;
        final List<(Offset, double)> shownPoses = scene.flyerPoses(
          scene.paint(
            time,
            bees: poses.sublist(0, bees),
            butterflies: poses.sublist(bees),
          ),
        );
        final List<int> shown = <int>[
          for (int i = 0; i < poses.length; i++)
            if (poses[i].opacity > 0) i,
        ];
        expect(shownPoses, hasLength(shown.length));
        return <int, (Offset, double)>{
          for (int k = 0; k < shown.length; k++) shown[k]: shownPoses[k],
        };
      }

      double time = 0;
      List<MeadowFlyerPose> before = flyers(ambience);
      Map<int, (Offset, double)> drawnBefore = drawn(time, before);
      final Map<int, (int, String)> settling = <int, (int, String)>{};
      int landings = 0;
      int takeOffs = 0;
      while (time < _watch) {
        ambience.step(_step, targets: targets, dayLife: 1, fireflies: 0);
        time += _step;
        final List<MeadowFlyerPose> after = flyers(ambience);
        final Map<int, (Offset, double)> drawnAfter = drawn(time, after);
        for (int i = 0; i < after.length; i++) {
          final MeadowFlyerActivity was = before[i].activity;
          final MeadowFlyerActivity now = after[i].activity;
          if (was == MeadowFlyerActivity.flying &&
              now == MeadowFlyerActivity.perched) {
            landings++;
            settling[i] = (_settleFrames, 'landing');
          } else if (was == MeadowFlyerActivity.perched &&
              now == MeadowFlyerActivity.flying) {
            takeOffs++;
            settling[i] = (_settleFrames, 'leaving');
          }
          final (int, String)? window = settling[i];
          final (Offset, double)? from = drawnBefore[i];
          final (Offset, double)? to = drawnAfter[i];
          if (window == null) {
            continue;
          }
          if (from != null && to != null) {
            expect(
              (to.$1 - from.$1).distance,
              lessThanOrEqualTo(_landingJump),
              reason: '${window.$2} flyer $i at $time',
            );
            expect(
              (to.$2 - from.$2).abs(),
              lessThanOrEqualTo(_landingTurn),
              reason: '${window.$2} flyer $i turning at $time',
            );
          }
          if (window.$1 <= 1) {
            settling.remove(i);
          } else {
            settling[i] = (window.$1 - 1, window.$2);
          }
        }
        before = after;
        drawnBefore = drawnAfter;
      }
      expect(landings, greaterThan(0));
      expect(takeOffs, greaterThan(0));
    },
  );
}
