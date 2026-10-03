import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/garden_motion.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/render/meadow_layers.dart';
import 'package:field_notes/features/garden/render/meadow_stage_painter.dart';
import 'package:field_notes/features/garden/scene/meadow_grass.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart'
    hide MeadowRange;
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const int _meadowKey = 20280229;
const int _buildFrames = 6000;
const Size _macWindow = Size(1148, 772);
const Size _phoneScreen = Size(411.4, 868.6);

final SkyScene _noon = skySceneAt(
  DateTime.utc(2028, 6, 21, 19, 30),
  53.55,
  -113.4667,
);

MeadowYear _leapYear() => MeadowYear.build(
  days: <Day>[
    for (int i = 0; i < 366; i++)
      dayOf(
        captureDateKey(DateTime(2028, 1, 1 + i)),
        mood: moodOrder[(i ~/ 5) % moodOrder.length],
      ),
  ],
  entryCounts: <String, int>{
    for (int i = 0; i < 366; i++)
      captureDateKey(DateTime(2028, 1, 1 + i)): 1 + i % 4,
  },
  year: 2028,
  today: DateTime(2029, 3, 1),
);

Future<MeadowStageState> _pumpStage(
  WidgetTester tester, {
  required Size box,
  required double ratio,
  required bool compact,
  required MeadowSceneMode mode,
}) async {
  final MeadowYear year = _leapYear();
  tester.view.physicalSize = box * ratio;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(
        platform: compact ? TargetPlatform.android : TargetPlatform.macOS,
      ),
      home: MeadowStage(
        year: year,
        seed: meadowSeed(_meadowKey, year.year),
        sky: _noon,
        morning: false,
        mode: mode,
        compact: compact,
        motion: GardenMotionProfile.reduced,
        cover: true,
      ),
    ),
  );
  return tester.state<MeadowStageState>(find.byType(MeadowStage));
}

List<MeadowStagePainter> _stagePainters(WidgetTester tester) =>
    <MeadowStagePainter>[
      for (final CustomPaint paint in tester.widgetList<CustomPaint>(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is CustomPaint && widget.painter is MeadowStagePainter,
        ),
      ))
        paint.painter! as MeadowStagePainter,
    ];

bool _atScreen(MeadowStagePainter painter, double screen) =>
    (painter.layers.density - screen).abs() < 1e-9 &&
    (painter.atlas.density - screen).abs() < 1e-9;

Future<MeadowStagePainter> _sharpScene(
  WidgetTester tester,
  MeadowStageState state,
  double screen,
) async {
  for (int i = 0; i < _buildFrames; i++) {
    if (state.debugIsReady) {
      for (final MeadowStagePainter painter in _stagePainters(tester)) {
        if (_atScreen(painter, screen)) {
          return painter;
        }
      }
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(state.debugIsReady, isTrue, reason: 'the meadow never finished');
  return _stagePainters(tester).last;
}

Future<void> _ready(WidgetTester tester, MeadowStageState state) async {
  for (int i = 0; i < _buildFrames && !state.debugIsReady; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(state.debugIsReady, isTrue, reason: 'the meadow never finished');
}

int _bytesOf(MeadowStagePainter painter) =>
    painter.layers.imageBytes +
    painter.atlas.imageBytes +
    painter.creatures.imageBytes +
    painter.rays.imageBytes;

Finder _paintOf(MeadowStagePainter painter) => find.byWidgetPredicate(
  (Widget widget) =>
      widget is CustomPaint && identical(widget.painter, painter),
);

Finder _fadesOver(MeadowStagePainter painter) =>
    find.ancestor(of: _paintOf(painter), matching: find.byType(FadeTransition));

void main() {
  for (final (
        String name,
        Size box,
        double ratio,
        bool compact,
        MeadowSceneMode mode,
      )
      in <(String, Size, double, bool, MeadowSceneMode)>[
        ('a Mac window', _macWindow, 1, false, MeadowSceneMode.page),
        ('a phone page', _phoneScreen, 1, true, MeadowSceneMode.page),
        (
          'a phone in full screen',
          _phoneScreen,
          1.25,
          true,
          MeadowSceneMode.full,
        ),
      ]) {
    testWidgets(
      'the landscape and the flowers are baked at the screen resolution on '
      '$name',
      (WidgetTester tester) async {
        final MeadowStageState state = await _pumpStage(
          tester,
          box: box,
          ratio: ratio,
          compact: compact,
          mode: mode,
        );
        final double screen =
            MeadowViewport.resolve(box: box, cover: true, focusX: 0).scale *
            ratio;
        final MeadowStagePainter painter = await _sharpScene(
          tester,
          state,
          screen,
        );
        expect(painter.layers.density, closeTo(screen, 1e-9));
        expect(painter.atlas.density, closeTo(screen, 1e-9));
      },
    );
  }

  testWidgets(
    'the quick scene shows first and the sharp scene fades in over it',
    (WidgetTester tester) async {
      final MeadowYear year = _leapYear();
      final int seed = meadowSeed(_meadowKey, year.year);
      final MeadowTerrain terrain = buildMeadowTerrain(seed: seed, year: year);
      final List<MeadowGrassBand> grass = buildMeadowGrass(
        seed: seed,
        terrain: terrain,
      );
      final double screen = MeadowViewport.resolve(
        box: _phoneScreen,
        cover: true,
        focusX: 0,
      ).scale;
      expect(screen, closeTo(1.3571875, 1e-9));
      final double quick = MeadowLayers.fitDensity(
        terrain: terrain,
        grass: grass,
        density: 1.3571875,
        maxBytes: meadowLayerPageBudget,
      );
      expect(quick, lessThan(screen));

      final MeadowStageState state = await _pumpStage(
        tester,
        box: _phoneScreen,
        ratio: 1,
        compact: true,
        mode: MeadowSceneMode.page,
      );
      await _ready(tester, state);
      final MeadowStagePainter first = _stagePainters(tester).single;
      expect(first.layers.density, closeTo(quick, 1e-9));
      final MeadowLayers quickLayers = first.layers;

      for (
        int i = 0;
        i < _buildFrames && _stagePainters(tester).length < 2;
        i++
      ) {
        expect(
          identical(_stagePainters(tester).single.layers, quickLayers),
          isTrue,
          reason: 'frame $i shows the quick scene while the sharp one bakes',
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_stagePainters(tester), hasLength(2));

      final List<double> opacities = <double>[];
      int frames = 0;
      while (_stagePainters(tester).length == 2 && frames < 120) {
        final List<MeadowStagePainter> painters = _stagePainters(tester);
        final MeadowStagePainter under = painters.first;
        final MeadowStagePainter over = painters.last;
        final String reason = 'crossfade frame $frames';
        expect(identical(under.layers, quickLayers), isTrue, reason: reason);
        expect(_atScreen(over, screen), isTrue, reason: reason);
        expect(
          state.debugImageBytes,
          _bytesOf(under) + _bytesOf(over),
          reason: reason,
        );
        final Finder fade = _fadesOver(over).first;
        expect(
          find.descendant(of: fade, matching: _paintOf(under)),
          findsNothing,
          reason: reason,
        );
        opacities.add(tester.widget<FadeTransition>(fade).opacity.value);
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
      }
      expect(
        (frames - 1) * 16,
        greaterThanOrEqualTo(250),
        reason: 'both scenes were painted for ${(frames - 1) * 16} ms',
      );
      expect(opacities.first, lessThan(0.1), reason: '$opacities');
      expect(opacities.last, greaterThan(0.9), reason: '$opacities');
      for (int i = 1; i < opacities.length; i++) {
        expect(
          opacities[i],
          greaterThanOrEqualTo(opacities[i - 1]),
          reason: '$opacities',
        );
      }

      final MeadowStagePainter sharp = _stagePainters(tester).single;
      expect(_atScreen(sharp, screen), isTrue);
      expect(sharp.layers.density, closeTo(1.3571875, 1e-9));
      expect(
        tester
            .widgetList<FadeTransition>(_fadesOver(sharp))
            .map((FadeTransition fade) => fade.opacity.value),
        everyElement(1),
      );
      expect(quickLayers.isReady, isFalse);
      expect(state.debugImageBytes, _bytesOf(sharp));

      await tester.pumpWidget(const SizedBox());
      const Size small = Size(400, 300);
      final double fits = MeadowViewport.resolve(
        box: small,
        cover: true,
        focusX: 0,
      ).scale;
      expect(
        MeadowLayers.bytesAt(terrain: terrain, grass: grass, density: fits),
        lessThanOrEqualTo(meadowLayerPageBudget),
      );
      final MeadowStageState once = await _pumpStage(
        tester,
        box: small,
        ratio: 1,
        compact: true,
        mode: MeadowSceneMode.page,
      );
      await _ready(tester, once);
      final MeadowStagePainter only = _stagePainters(tester).single;
      expect(_atScreen(only, fits), isTrue);
      for (int i = 0; i < 120; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
        await tester.pump(const Duration(milliseconds: 16));
        final List<MeadowStagePainter> painters = _stagePainters(tester);
        expect(painters, hasLength(1), reason: 'frame $i');
        expect(
          identical(painters.single.layers, only.layers),
          isTrue,
          reason: 'frame $i',
        );
        expect(
          identical(painters.single.atlas, only.atlas),
          isTrue,
          reason: 'frame $i',
        );
      }
      expect(once.debugImageBytes, _bytesOf(only));
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );
}
