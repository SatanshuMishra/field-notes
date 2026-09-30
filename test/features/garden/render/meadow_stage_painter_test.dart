import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/render/meadow_creature_art.dart';
import 'package:field_notes/features/garden/render/meadow_layers.dart';
import 'package:field_notes/features/garden/render/meadow_plant_atlas.dart';
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
const double _latitude = 53.55;
const double _longitude = -113.4667;
const Size _phoneScreen = Size(411.4, 868.6);
const double _phoneRatio = 2.625;
const int _drawBudget = 400;
const int _atlasBudget = 80;
const double _step = 1 / 60;
const double _settle = 40;
const Set<String> _atlasCalls = <String>{'drawAtlas', 'drawRawAtlas'};
const Set<String> _imageAndGradientDraws = <String>{
  'drawRect',
  'drawOval',
  'drawCircle',
  'drawImage',
  'drawImageRect',
  'drawAtlas',
  'drawRawAtlas',
  'drawVertices',
  'drawParagraph',
  'drawPaint',
};

String _dateOf(int index) => captureDateKey(DateTime(_leapYear, 1, 1 + index));

int _indexOf(int month, int day) => DateTime.utc(
  _leapYear,
  month,
  day,
).difference(DateTime.utc(_leapYear)).inDays;

MeadowYear _fullYear() => MeadowYear.build(
  days: <Day>[
    for (int i = 0; i < 366; i++)
      dayOf(_dateOf(i), mood: moodOrder[(i ~/ 5) % moodOrder.length]),
  ],
  entryCounts: <String, int>{
    for (int i = 0; i < 366; i++) _dateOf(i): 1 + i % 4,
  },
  year: _leapYear,
  today: DateTime(_leapYear + 1, 3, 1),
);

MeadowPalette _paletteAt(DateTime instant, MeadowYear year) =>
    MeadowPalette.from(
      sky: skySceneAt(instant, _latitude, _longitude),
      morning: false,
      heavyShare: year.heavyShare,
    );

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

  Iterable<_Call> named(Set<String> names) =>
      calls.where((_Call call) => names.contains(call.name));

  int count(String name) => named(<String>{name}).length;

  List<_Call> get draws => <_Call>[
    for (final _Call call in calls)
      if (call.name.startsWith('draw')) call,
  ];

  List<(int, int)> get layers {
    final List<(int, bool)> open = <(int, bool)>[];
    final List<(int, int)> spans = <(int, int)>[];
    for (int i = 0; i < calls.length; i++) {
      switch (calls[i].name) {
        case 'save':
          open.add((i, false));
        case 'saveLayer':
          open.add((i, true));
        case 'restore':
          final (int start, bool layer) = open.removeLast();
          if (layer) {
            spans.add((start, i));
          }
      }
    }
    return spans;
  }
}

bool _masksWithDstIn(_Call call) =>
    call.name == 'drawImageRect' &&
    (call.arguments[3]! as Paint).blendMode == BlendMode.dstIn;

class _Sprite {
  const _Sprite({
    required this.image,
    required this.source,
    required this.scale,
    required this.alpha,
  });

  final Image image;
  final Rect source;
  final double scale;
  final double alpha;
}

List<_Sprite> _spritesOf(_Call call) {
  final Image image = call.arguments[0]! as Image;
  if (call.name == 'drawRawAtlas') {
    final Float32List transforms = call.arguments[1]! as Float32List;
    final Float32List rects = call.arguments[2]! as Float32List;
    final Int32List? colours = call.arguments[3] as Int32List?;
    return <_Sprite>[
      for (int i = 0; i < rects.length ~/ 4; i++)
        _Sprite(
          image: image,
          source: Rect.fromLTRB(
            rects[i * 4],
            rects[i * 4 + 1],
            rects[i * 4 + 2],
            rects[i * 4 + 3],
          ),
          scale: math.sqrt(
            transforms[i * 4] * transforms[i * 4] +
                transforms[i * 4 + 1] * transforms[i * 4 + 1],
          ),
          alpha: colours == null ? 1 : (colours[i] >> 24 & 0xFF) / 255,
        ),
    ];
  }
  final List<RSTransform> transforms = call.arguments[1]! as List<RSTransform>;
  final List<Rect> rects = call.arguments[2]! as List<Rect>;
  final List<Color>? colours = call.arguments[3] as List<Color>?;
  return <_Sprite>[
    for (int i = 0; i < rects.length; i++)
      _Sprite(
        image: image,
        source: rects[i],
        scale: math.sqrt(
          transforms[i].scos * transforms[i].scos +
              transforms[i].ssin * transforms[i].ssin,
        ),
        alpha: colours == null ? 1 : colours[i].a,
      ),
  ];
}

class _Scene {
  _Scene._({
    required this.year,
    required this.terrain,
    required this.plants,
    required this.layers,
    required this.atlas,
    required this.creatures,
    required this.viewport,
    required this.noon,
    required this.midnight,
    required this.dayPoses,
    required this.nightPoses,
  });

  factory _Scene.build() {
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
    final MeadowViewport viewport = MeadowViewport.resolve(
      box: _phoneScreen,
      cover: true,
      focusX: terrain.sky.focusX,
    );
    final double density = viewport.scale * _phoneRatio;
    final MeadowPalette noon = _paletteAt(
      DateTime.utc(_leapYear, 6, 21, 19, 30),
      year,
    );
    final MeadowPalette midnight = _paletteAt(
      DateTime.utc(_leapYear, 1, 15, 7),
      year,
    );
    final MeadowLayers layers =
        MeadowLayers(
            terrain: terrain,
            grass: grass,
            density: MeadowLayers.fitDensity(
              terrain: terrain,
              grass: grass,
              density: density,
              maxBytes: meadowLayerBudget,
            ),
          )
          ..buildAll()
          ..recolour(noon);
    final MeadowPlantAtlas atlas = MeadowPlantAtlas(plants, density: density)
      ..buildAll();
    List<MeadowPlant> targets() => <MeadowPlant>[
      for (final MeadowPlant plant in plants.plants)
        if (!plant.hidden && plant.mood != null) plant,
    ];
    _Poses settle(MeadowPalette palette) {
      final MeadowAmbience ambience = MeadowAmbience(
        seed: seed,
        terrain: terrain,
        plants: plants,
        year: year,
      );
      for (double t = 0; t < _settle; t += _step) {
        ambience.step(
          _step,
          targets: targets(),
          dayLife: palette.dayLife,
          fireflies: palette.fireflies,
        );
      }
      return _Poses(
        bees: ambience.bees,
        butterflies: ambience.butterflies,
        fireflies: ambience.fireflies,
      );
    }

    return _Scene._(
      year: year,
      terrain: terrain,
      plants: plants,
      layers: layers,
      atlas: atlas,
      creatures: MeadowCreatureArt.build(density: density),
      viewport: viewport,
      noon: noon,
      midnight: midnight,
      dayPoses: settle(noon),
      nightPoses: settle(midnight),
    );
  }

  final MeadowYear year;
  final MeadowTerrain terrain;
  final MeadowPlants plants;
  final MeadowLayers layers;
  final MeadowPlantAtlas atlas;
  final MeadowCreatureArt creatures;
  final MeadowViewport viewport;
  final MeadowPalette noon;
  final MeadowPalette midnight;
  final _Poses dayPoses;
  final _Poses nightPoses;

  late final Map<(Image, double, double), int> _dayOfSprite =
      <(Image, double, double), int>{
        for (final MeadowPlantSprite sprite in atlas.sprites)
          (atlas.imageOf(sprite.sheet)!, sprite.source.left, sprite.source.top):
              sprite.dayIndex,
      };

  List<int> visibleDays(int growthPoint) => <int>[
    for (final MeadowPlant plant in plants.plants)
      if (!plant.hidden && plant.dayIndex < growthPoint) plant.dayIndex,
  ]..sort();

  _RecordingCanvas paint({
    required double time,
    MeadowPalette? palette,
    _Poses? poses,
    int? growthPoint,
    bool growAnimated = false,
    Map<int, double> reveals = const <int, double>{},
    MeadowRange? highlight,
    double highlightSince = double.negativeInfinity,
    Offset? spot,
  }) {
    final MeadowPalette light = palette ?? noon;
    final _Poses creaturePoses = poses ?? dayPoses;
    final int point = growthPoint ?? year.limit;
    layers.recolour(light);
    final _RecordingCanvas canvas = _RecordingCanvas();
    MeadowStagePainter(
      layers: layers,
      atlas: atlas,
      creatures: creatures,
      terrain: terrain,
      plants: plants,
      heaviest: year.heaviest,
      palette: light,
      viewport: viewport,
      time: time,
      animate: true,
      growthPoint: point,
      growAnimated: growAnimated,
      reveals: reveals,
      highlight: highlight,
      highlightSince: highlightSince,
      spot: spot,
      bees: creaturePoses.bees,
      butterflies: creaturePoses.butterflies,
      fireflies: creaturePoses.fireflies,
      mode: MeadowSceneMode.page,
      caption: meadowStageCaption(
        year: _leapYear,
        growthPoint: point,
        daysInYear: year.daysInYear,
        mode: MeadowSceneMode.page,
      ),
    ).paint(canvas, _phoneScreen);
    return canvas;
  }

  Map<int, _Sprite> flowers(_RecordingCanvas canvas) {
    final Map<int, _Sprite> byDay = <int, _Sprite>{};
    for (final _Call call in canvas.named(_atlasCalls)) {
      for (final _Sprite sprite in _spritesOf(call)) {
        final int? day =
            _dayOfSprite[(sprite.image, sprite.source.left, sprite.source.top)];
        if (day != null) {
          expect(byDay.containsKey(day), isFalse, reason: 'day $day twice');
          byDay[day] = sprite;
        }
      }
    }
    return byDay;
  }

  void dispose() {
    layers.dispose();
    atlas.dispose();
    creatures.dispose();
  }
}

class _Poses {
  const _Poses({
    required this.bees,
    required this.butterflies,
    required this.fireflies,
  });

  final List<MeadowFlyerPose> bees;
  final List<MeadowFlyerPose> butterflies;
  final List<MeadowFireflyPose> fireflies;
}

void main() {
  late _Scene scene;

  setUpAll(() {
    scene = _Scene.build();
  });

  tearDownAll(() {
    scene.dispose();
  });

  test(
    'a 366-flower frame stays within the draw budget and draws no vector shapes',
    () {
      expect(scene.year.daysInYear, 366);
      expect(scene.plants.plants, hasLength(366));
      final Offset head = scene.plants.plants
          .firstWhere((MeadowPlant plant) => !plant.hidden)
          .heads
          .last;
      for (final (MeadowPalette palette, _Poses poses)
          in <(MeadowPalette, _Poses)>[
            (scene.noon, scene.dayPoses),
            (scene.midnight, scene.nightPoses),
          ]) {
        final _RecordingCanvas frame = scene.paint(
          time: 42.5,
          palette: palette,
          poses: poses,
          spot: head,
        );

        expect(frame.draws.length, lessThanOrEqualTo(_drawBudget));
        expect(frame.count('drawPath'), 0);
        expect(frame.count('drawPicture'), 0);
        expect(
          frame.draws.map((_Call call) => call.name).toSet(),
          everyElement(isIn(_imageAndGradientDraws)),
        );
        expect(frame.count('clipPath'), 0);
        expect(frame.count('clipRRect'), 0);
        expect(frame.count('saveLayer'), lessThanOrEqualTo(3));

        final int atlasCalls = frame.named(_atlasCalls).length;
        expect(atlasCalls, greaterThan(0));
        expect(atlasCalls, lessThanOrEqualTo(_atlasBudget));
        expect(
          scene.flowers(frame).keys.toList()..sort(),
          scene.visibleDays(scene.year.limit),
        );
      }
    },
  );

  test(
    'the water marks draw in one layer masked to the water without colour filters',
    () {
      for (final (MeadowPalette palette, _Poses poses, bool glints)
          in <(MeadowPalette, _Poses, bool)>[
            (scene.noon, scene.dayPoses, true),
            (scene.midnight, scene.nightPoses, false),
          ]) {
        final _RecordingCanvas frame = scene.paint(
          time: 42.5,
          palette: palette,
          poses: poses,
        );
        final List<int> marks = <int>[
          for (int i = 0; i < frame.calls.length; i++)
            if (frame.calls[i].name == 'drawOval') i,
        ];
        for (final int mark in marks) {
          final Paint paint = frame.calls[mark].arguments[1]! as Paint;
          expect(paint.colorFilter, isNull, reason: 'drawOval $mark');
          expect(paint.shader, isNull, reason: 'drawOval $mark');
        }
        if (!glints) {
          continue;
        }
        expect(palette.glintO, greaterThan(0));
        expect(marks, isNotEmpty);
        final List<(int, int)> masked = <(int, int)>[
          for (final (int start, int end) in frame.layers)
            if (frame.calls.sublist(start, end).any(_masksWithDstIn))
              (start, end),
        ];
        for (final int mark in marks) {
          expect(
            masked.any(
              ((int, int) layer) => layer.$1 < mark && mark < layer.$2,
            ),
            isTrue,
            reason: 'drawOval $mark',
          );
        }
      }
    },
  );

  test('days past the growth point are hidden and new days grow in', () {
    final _RecordingCanvas held = scene.paint(time: 12, growthPoint: 100);
    final List<int> shown = scene.flowers(held).keys.toList()..sort();
    expect(shown.where((int day) => day >= 100), isEmpty);
    expect(shown, scene.visibleDays(100));

    final MeadowPlant hundredth = scene.plants.plants.firstWhere(
      (MeadowPlant plant) => plant.dayIndex == 100,
    );
    expect(hundredth.hidden, isFalse);
    const double revealed = 20;
    double scaleAt(double time) {
      final _RecordingCanvas frame = scene.paint(
        time: time,
        growthPoint: 101,
        growAnimated: true,
        reveals: const <int, double>{100: revealed},
      );
      final Map<int, _Sprite> flowers = scene.flowers(frame);
      expect(flowers.keys.where((int day) => day > 100), isEmpty);
      return flowers[100]!.scale * scene.atlas.density;
    }

    expect(scaleAt(revealed), closeTo(0.04, 0.002));
    expect(scaleAt(revealed + 0.5), inExclusiveRange(0.04, 1.1));
    expect(scaleAt(revealed + 1), closeTo(1, 1e-4));
  });

  test('a highlighted range dims every other flower to a fifth', () {
    final MeadowRange june = MeadowRange(
      first: _indexOf(6, 1),
      last: _indexOf(6, 30),
      key: 'june',
    );
    const double since = 30;
    Map<int, _Sprite> flowersAt(double time) => scene.flowers(
      scene.paint(time: time, highlight: june, highlightSince: since),
    );

    final Map<int, _Sprite> easing = flowersAt(since + 0.1);
    final Map<int, _Sprite> settled = flowersAt(since + 0.35);

    expect(settled.keys.toList()..sort(), scene.visibleDays(scene.year.limit));
    for (final MapEntry<int, _Sprite> flower in settled.entries) {
      final bool inJune = flower.key >= june.first && flower.key <= june.last;
      expect(
        flower.value.alpha,
        closeTo(inJune ? 1 : meadowDimmedOpacity, 0.003),
        reason: 'day ${flower.key}',
      );
      if (!inJune) {
        expect(
          easing[flower.key]!.alpha,
          inExclusiveRange(meadowDimmedOpacity, 1),
        );
      }
    }
    expect(
      settled.keys.where((int day) => day >= june.first && day <= june.last),
      isNotEmpty,
    );
  });
}
