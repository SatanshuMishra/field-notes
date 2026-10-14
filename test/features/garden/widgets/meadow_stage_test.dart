import 'dart:async';
import 'dart:math' as math;

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/tokens/field_notes_colors.dart';
import 'package:field_notes/design/tokens/typography.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/garden_motion.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/render/meadow_layers.dart';
import 'package:field_notes/features/garden/render/meadow_stage_painter.dart';
import 'package:field_notes/features/garden/scene/meadow_grass.dart';
import 'package:field_notes/features/garden/scene/meadow_pacer.dart';
import 'package:field_notes/features/garden/scene/meadow_plants.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_stage_tooltip.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart'
    hide MeadowRange;
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';
import '../support/meadow_stage_harness.dart';

const int _megabyte = 1000 * 1000;
const Size _bottomBarCard = Size(400, 300);
const Size _phoneScreen = Size(411.4, 868.6);
const Size _macWindow = Size(1100, 700);

int _indexOf(int year, int month, int day) =>
    DateTime.utc(year, month, day).difference(DateTime.utc(year)).inDays;

MeadowYear _countedYear({
  required int year,
  required int blooms,
  required int sprouts,
  required DateTime today,
}) {
  String dateAt(int index) => captureDateKey(DateTime(year, 1, 1 + index));
  return MeadowYear.build(
    days: <Day>[
      for (int i = 0; i < blooms; i++)
        dayOf(dateAt(i), mood: moodOrder[i % moodOrder.length]),
    ],
    entryCounts: <String, int>{
      for (int i = 0; i < sprouts; i++) dateAt(blooms + 3 + i): 1,
    },
    year: year,
    today: today,
  );
}

class _Expected {
  factory _Expected(MeadowYear year) {
    final int seed = meadowSeed(meadowStageKey, year.year);
    final MeadowTerrain terrain = buildMeadowTerrain(seed: seed, year: year);
    return _Expected._(
      year: year,
      terrain: terrain,
      plants: buildMeadowPlants(seed: seed, year: year, terrain: terrain),
    );
  }

  const _Expected._({
    required this.year,
    required this.terrain,
    required this.plants,
  });

  final MeadowYear year;
  final MeadowTerrain terrain;
  final MeadowPlants plants;

  MeadowOldSpruce get spruce => terrain.forest.oldSpruce!;

  Offset get insideSpruce =>
      Offset(spruce.x, spruce.top + spruce.height * 0.55);

  MeadowPlant plantOn(int month, int day) => plants.plants.singleWhere(
    (MeadowPlant plant) => plant.dayIndex == _indexOf(year.year, month, day),
  );

  Offset tipOf(MeadowPlant plant) {
    final Offset head = plant.heads.last;
    return Offset(head.dx, head.dy - 14 * plant.scale / meadowNearScale);
  }

  List<MeadowPlant> reaching(Offset world, {MeadowPlant? besides}) =>
      <MeadowPlant>[
        for (final MeadowPlant plant in plants.plants)
          if (!identical(plant, besides) &&
              !plant.hidden &&
              plant.heads.any(
                (Offset head) =>
                    (head - world).distance <
                    5 + 24 * plant.scale / meadowNearScale,
              ))
            plant,
      ];
}

int _countedSteps(Iterable<StageBatch> sent) =>
    sent.fold<int>(0, (int total, StageBatch batch) => total + batch.steps);

Offset _global(WidgetTester tester, MeadowStageState state, Offset world) =>
    tester.getTopLeft(find.byType(MeadowStage)) +
    state.debugViewport!.toLocal(world);

Rect _stageRect(WidgetTester tester) =>
    tester.getRect(find.byType(MeadowStage));

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .descendant(
            of: find.byType(MeadowStage),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

final Finder _stagePaints = find.byWidgetPredicate(
  (Widget widget) =>
      widget is CustomPaint && widget.painter is MeadowStagePainter,
);

MeadowStagePainter _stagePainter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_stagePaints).painter! as MeadowStagePainter;

int _sceneBytes(MeadowStagePainter painter) =>
    painter.layers.imageBytes +
    painter.atlas.imageBytes +
    painter.creatures.imageBytes +
    painter.rays.imageBytes;

Future<MeadowStagePainter> _sharpen(WidgetTester tester, double screen) async {
  bool sharp() {
    final Iterable<CustomPaint> paints = tester.widgetList<CustomPaint>(
      _stagePaints,
    );
    return paints.length == 1 &&
        ((paints.single.painter! as MeadowStagePainter).layers.density - screen)
                .abs() <
            1e-9;
  }

  for (int i = 0; i < meadowBuildFrames && !sharp(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(sharp(), isTrue, reason: 'the meadow never sharpened');
  return _stagePainter(tester);
}

BoxDecoration _tooltipDecoration(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find.descendant(
                of: find.byType(MeadowStageTooltip),
                matching: find.byType(DecoratedBox),
              ),
            )
            .decoration
        as BoxDecoration;

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

Future<TestGesture> _mouse(WidgetTester tester) async {
  final TestGesture mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  return mouse;
}

void _moveLifecycle(WidgetTester tester, List<AppLifecycleState> states) {
  for (final AppLifecycleState state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void _expectBubble(
  WidgetTester tester,
  Offset anchor, {
  required FieldNotesColors colors,
  required String title,
  required String subtitle,
}) {
  final Rect bubble = tester.getRect(find.byType(MeadowStageTooltip));
  expect(bubble.center.dx, closeTo(anchor.dx, 0.5));
  expect(bubble.bottom, closeTo(anchor.dy, 0.5));
  final BoxDecoration decoration = _tooltipDecoration(tester);
  expect(decoration.color, colors.cardBright);
  expect(decoration.border, Border.all(color: colors.line, width: 1.5));
  expect(decoration.borderRadius, BorderRadius.circular(12));
  expect(decoration.boxShadow, <BoxShadow>[
    BoxShadow(color: colors.shadowTint(0x33), offset: const Offset(2, 2)),
  ]);
  final TextStyle titleStyle = _styleOf(tester, title);
  expect(titleStyle.fontFamily, TypographyTokens.serif);
  expect(titleStyle.fontSize, 16);
  expect(titleStyle.color, colors.ink);
  final TextStyle subtitleStyle = _styleOf(tester, subtitle);
  expect(subtitleStyle.fontSize, 12);
  expect(subtitleStyle.color, colors.mutedDeep);
}

void main() {
  testWidgets('hovering a flower shows its date, mood, flower and entries', (
    WidgetTester tester,
  ) async {
    final _Expected expected = _Expected(meadowSampleYear());
    final MeadowPlant june = expected.plantOn(6, 30);
    final MeadowPlant sprout = expected.plantOn(9, 15);
    expect(june.mood, Mood.warm);
    expect(sprout.isSprout, isTrue);
    for (final MeadowPlant plant in <MeadowPlant>[june, sprout]) {
      expect(
        expected
            .reaching(plant.heads.last, besides: plant)
            .where((MeadowPlant rival) => rival.y >= plant.y),
        isEmpty,
      );
    }

    final TestGesture mouse = await _mouse(tester);
    for (final (MeadowSceneMode mode, Size box) in <(MeadowSceneMode, Size)>[
      (MeadowSceneMode.page, meadowSidebarCard),
      (MeadowSceneMode.study, meadowSidebarCard),
      (MeadowSceneMode.full, _macWindow),
    ]) {
      final MeadowStageState state = await pumpMeadowStage(
        tester,
        box: box,
        mode: mode,
      );
      await growMeadow(tester, state);

      await mouse.moveTo(_global(tester, state, june.heads.last));
      await tester.pump();
      expect(find.text('Mon, Jun 30'), findsOneWidget, reason: '$mode');
      expect(find.text('Warm · Sunflower · 1 entry'), findsOneWidget);
      _expectBubble(
        tester,
        _global(tester, state, expected.tipOf(june)),
        colors: FieldNotesColors.light,
        title: 'Mon, Jun 30',
        subtitle: 'Warm · Sunflower · 1 entry',
      );

      await mouse.down(_global(tester, state, june.heads.last));
      await tester.pump();
      await mouse.up();
      await tester.pump();
      expect(find.text('Mon, Jun 30'), findsOneWidget);

      if (mode != MeadowSceneMode.full) {
        await mouse.moveTo(_global(tester, state, sprout.heads.last));
        await tester.pump();
        expect(find.text('Mon, Sep 15'), findsOneWidget);
        expect(
          find.text('Wrote, no mood · Sprout · 2 entries'),
          findsOneWidget,
        );
      }

      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(find.byType(MeadowStageTooltip), findsNothing);

      await tester.tapAt(_global(tester, state, june.heads.last));
      await tester.pump();
      expect(find.byType(MeadowStageTooltip), findsNothing);
    }
  });

  testWidgets('hovering the old spruce shows its run', (
    WidgetTester tester,
  ) async {
    final _Expected expected = _Expected(meadowSampleYear());
    final MeadowOldSpruce spruce = expected.spruce;
    expect(spruce.day, _indexOf(2025, 1, 23));
    expect(expected.reaching(expected.insideSpruce), isEmpty);
    final GlobalKey key = GlobalKey();

    MeadowStageState state = await pumpMeadowStage(
      tester,
      mode: MeadowSceneMode.study,
      growthPoint: spruce.day,
      stageKey: key,
    );
    await growMeadow(tester, state);
    final TestGesture mouse = await _mouse(tester);
    await mouse.moveTo(_global(tester, state, expected.insideSpruce));
    await tester.pump();
    expect(find.byType(MeadowStageTooltip), findsNothing);

    state = await pumpMeadowStage(
      tester,
      mode: MeadowSceneMode.study,
      growthPoint: spruce.day + 1,
      stageKey: key,
    );
    await mouse.moveTo(_global(tester, state, expected.insideSpruce));
    await mouse.moveTo(
      _global(tester, state, expected.insideSpruce + const Offset(1, 0)),
    );
    await tester.pump();
    final Offset tip = Offset(spruce.x, spruce.top + spruce.height * 0.15);
    _expectBubble(
      tester,
      _global(tester, state, tip),
      colors: FieldNotesColors.light,
      title: 'The old spruce',
      subtitle: '11 days in a row · Jan 13 – Jan 23',
    );

    await mouse.moveTo(
      _global(tester, state, Offset(spruce.x + spruce.width, spruce.top + 4)),
    );
    await tester.pump();
    expect(find.byType(MeadowStageTooltip), findsNothing);

    state = await pumpMeadowStage(tester, brightness: Brightness.dark);
    await growMeadow(tester, state);
    await mouse.moveTo(_global(tester, state, expected.insideSpruce));
    await tester.pump();
    _expectBubble(
      tester,
      _global(tester, state, tip),
      colors: FieldNotesColors.dark,
      title: 'The old spruce',
      subtitle: '11 days in a row · Jan 13 – Jan 23',
    );
  });

  testWidgets('a tap on the phone shows the day card and a tap on the ground '
      'clears it', (WidgetTester tester) async {
    final _Expected expected = _Expected(meadowSampleYear());
    final MeadowPlant june = expected.plantOn(6, 30);
    final MeadowPlant april = expected.plantOn(4, 20);
    const Offset ground = Offset(400, 560);
    expect(expected.reaching(ground), isEmpty);
    expect(
      expected
          .reaching(june.heads.last, besides: june)
          .where((MeadowPlant rival) => rival.y >= june.y),
      isEmpty,
    );

    MeadowStageState state = await pumpMeadowStage(
      tester,
      box: _bottomBarCard,
      compact: true,
    );
    await growMeadow(tester, state);
    Rect stage = _stageRect(tester);
    expect(find.text(meadowStageHint), findsOneWidget);
    Rect hint = tester.getRect(
      find.ancestor(
        of: find.text(meadowStageHint),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(hint.top, closeTo(stage.top + 8, 0.01));
    expect(hint.center.dx, closeTo(stage.center.dx, 0.01));

    final TestGesture mouse = await _mouse(tester);
    await mouse.moveTo(_global(tester, state, june.heads.last));
    await tester.pump();
    expect(find.byType(MeadowStageTooltip), findsNothing);
    await mouse.moveTo(Offset.zero);

    await tester.tapAt(_global(tester, state, june.heads.last));
    await tester.pump();
    expect(find.text('Mon, Jun 30'), findsOneWidget);
    expect(find.text('Warm · Sunflower · 1 entry'), findsOneWidget);
    expect(find.text(meadowStageHint), findsNothing);
    Rect card = tester.getRect(find.byType(MeadowStageTooltip));
    expect(card.left, closeTo(stage.left + 8, 0.01));
    expect(card.right, closeTo(stage.right - 8, 0.01));
    expect(card.bottom, closeTo(stage.bottom - 8, 0.01));
    final BoxDecoration decoration = _tooltipDecoration(tester);
    expect(decoration.color, FieldNotesColors.light.cardBright);
    expect(decoration.borderRadius, BorderRadius.circular(11));
    expect(_styleOf(tester, 'Mon, Jun 30').fontSize, 14);
    expect(_styleOf(tester, 'Warm · Sunflower · 1 entry').fontSize, 10);

    await tester.tapAt(_global(tester, state, expected.insideSpruce));
    await tester.pump();
    expect(find.text('The old spruce'), findsOneWidget);

    await tester.tapAt(_global(tester, state, ground));
    await tester.pump();
    expect(find.byType(MeadowStageTooltip), findsNothing);

    state = await pumpMeadowStage(
      tester,
      box: _phoneScreen,
      compact: true,
      mode: MeadowSceneMode.full,
    );
    await growMeadow(tester, state);
    stage = _stageRect(tester);
    hint = tester.getRect(
      find.ancestor(
        of: find.text(meadowStageHint),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(hint.bottom, closeTo(stage.bottom - 18, 0.01));
    final Offset aprilAt = _global(tester, state, april.heads.last);
    expect(stage.contains(aprilAt), isTrue);
    await tester.tapAt(aprilAt);
    await tester.pump();
    expect(find.text('Sun, Apr 20'), findsOneWidget);
    expect(find.text('Hopeful · Daffodil'), findsOneWidget);
    card = tester.getRect(find.byType(MeadowStageTooltip));
    expect(card.bottom, closeTo(stage.bottom - 54, 0.01));
    expect(find.text(meadowStageHint), findsNothing);

    await tester.tapAt(_global(tester, state, ground));
    await tester.pump();
    expect(find.byType(MeadowStageTooltip), findsNothing);
  });

  testWidgets(
    'the sidebar page fits the meadow and the phone and full screen cover '
    'and pan',
    (WidgetTester tester) async {
      final _Expected expected = _Expected(meadowSampleYear());
      final double focusX = expected.terrain.sky.focusX;
      MeadowStageState state = await pumpMeadowStage(tester);
      await growMeadow(tester, state);
      expect(state.debugViewport!.scale, closeTo(1100 / 1400, 1e-9));
      expect(state.debugViewport!.offset, Offset.zero);
      expect(state.debugViewport!.pan, 0);
      await tester.drag(
        find.byType(MeadowStage),
        const Offset(-200, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(state.debugViewport!.pan, 0);
      expect(state.debugViewport!.offset, Offset.zero);

      for (final (
            Size box,
            bool compact,
            MeadowSceneMode mode,
            PointerDeviceKind kind,
          )
          in <(Size, bool, MeadowSceneMode, PointerDeviceKind)>[
            (
              _bottomBarCard,
              true,
              MeadowSceneMode.page,
              PointerDeviceKind.touch,
            ),
            (_phoneScreen, true, MeadowSceneMode.full, PointerDeviceKind.touch),
            (_macWindow, false, MeadowSceneMode.full, PointerDeviceKind.mouse),
          ]) {
        state = await pumpMeadowStage(
          tester,
          box: box,
          compact: compact,
          mode: mode,
        );
        await growMeadow(tester, state);
        final double scale = math.max(
          box.width / meadowWorldWidth,
          box.height / meadowWorldHeight,
        );
        final double visible = box.width / scale;
        final double edge = meadowWorldWidth - visible;
        final double start = (focusX - visible / 2).clamp(0.0, edge);
        final String reason = '$box $mode';
        expect(state.debugViewport!.scale, closeTo(scale, 1e-9));
        expect(state.debugViewport!.pan, closeTo(start, 1e-9), reason: reason);
        expect(
          state.debugViewport!.offset,
          offsetMoreOrLessEquals(
            Offset(
              -start * scale,
              (box.height - meadowWorldHeight * scale) / 2,
            ),
          ),
        );

        await tester.drag(
          find.byType(MeadowStage),
          const Offset(-120, 0),
          kind: kind,
        );
        await tester.pump();
        expect(
          state.debugViewport!.pan,
          closeTo(math.min(edge, start + 120 / scale), 1e-6),
          reason: reason,
        );
        if (kind == PointerDeviceKind.touch) {
          expect(find.byType(MeadowStageTooltip), findsNothing);
          expect(find.text(meadowStageHint), findsNothing);
        }

        await tester.drag(
          find.byType(MeadowStage),
          const Offset(-5000, 0),
          kind: kind,
        );
        await tester.pump();
        expect(state.debugViewport!.pan, closeTo(edge, 1e-6), reason: reason);

        await tester.drag(
          find.byType(MeadowStage),
          const Offset(5000, 0),
          kind: kind,
        );
        await tester.pump();
        expect(state.debugViewport!.pan, 0, reason: reason);
      }
    },
  );

  testWidgets('the card shows at once and the scene fades in when ready', (
    WidgetTester tester,
  ) async {
    final GlobalKey key = GlobalKey();
    final MeadowStageState state = await pumpMeadowStage(tester, stageKey: key);
    expect(find.text(meadowLoadingMessage), findsOneWidget);
    expect(state.debugIsReady, isFalse);
    expect(state.debugImageBytes, 0);
    expect(
      tester.getCenter(find.text(meadowLoadingMessage)),
      offsetMoreOrLessEquals(tester.getCenter(find.byType(MeadowStage))),
    );
    final TextStyle caption = _styleOf(tester, meadowLoadingMessage);
    expect(caption.fontSize, 12);
    expect(caption.fontFamily, TypographyTokens.sans);
    expect(caption.color, FieldNotesColors.light.muted);

    await growMeadow(tester, state);
    expect(find.text(meadowLoadingMessage), findsNothing);
    expect(state.debugImageBytes, greaterThan(0));
    expect(_opacity(tester), lessThan(0.05));
    await tester.pump(const Duration(milliseconds: 150));
    expect(_opacity(tester), inExclusiveRange(0.05, 1));
    await tester.pump(const Duration(milliseconds: 150));
    expect(_opacity(tester), 1);

    final double before = state.debugSceneDensity!;
    await pumpMeadowStage(tester, box: const Size(800, 365.7), stageKey: key);
    final double after = 800 / meadowWorldWidth;
    expect(state.debugViewport!.scale, closeTo(after, 1e-9));
    int frames = 0;
    while (state.debugSceneDensity != after && frames < meadowBuildFrames) {
      expect(find.text(meadowLoadingMessage), findsNothing);
      expect(state.debugSceneDensity, before);
      expect(_opacity(tester), 1);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump();
      frames++;
    }
    expect(frames, greaterThan(1));
    expect(state.debugSceneDensity, after);
    expect(_opacity(tester), 1);
  });

  testWidgets('reduce motion holds still and a hidden meadow stops ticking', (
    WidgetTester tester,
  ) async {
    final MeadowStageState still = await pumpMeadowStage(
      tester,
      motion: null,
      reduceMotion: true,
    );
    await growMeadow(tester, still);
    await tester.pump(const Duration(milliseconds: 400));
    expect(still.debugIsTicking, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(still.debugTime, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);

    final MeadowStageState live = await pumpMeadowStage(tester, motion: null);
    await growMeadow(tester, live);
    await tester.pump(const Duration(milliseconds: 400));
    expect(live.debugIsTicking, isTrue);
    expect(tester.binding.hasScheduledFrame, isTrue);
    final double running = live.debugTime;
    await tester.pump(const Duration(milliseconds: 100));
    expect(live.debugTime, greaterThan(running));

    _moveLifecycle(tester, const <AppLifecycleState>[
      AppLifecycleState.inactive,
    ]);
    await tester.pump();
    expect(live.debugIsTicking, isFalse);
    _moveLifecycle(tester, const <AppLifecycleState>[
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    await tester.pump();
    expect(live.debugIsTicking, isFalse);
    final double paused = live.debugTime;
    await tester.pump(const Duration(seconds: 1));
    expect(live.debugTime, paused);
    _moveLifecycle(tester, const <AppLifecycleState>[
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await tester.pump();
    expect(live.debugIsTicking, isTrue);

    final MeadowStageState hidden = await pumpMeadowStage(
      tester,
      motion: null,
      tickers: false,
    );
    await growMeadow(tester, hidden);
    await tester.pump(const Duration(milliseconds: 400));
    expect(hidden.debugIsTicking, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(hidden.debugTime, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the scene reads as one summary', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    void expectSummary(String label) {
      final SemanticsNode node = tester.getSemantics(
        find
            .descendant(
              of: find.byType(MeadowStage),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(node.label, label);
      expect(node.childrenCount, 0);
      expect(node.getSemanticsData().flagsCollection.isImage, isTrue);
    }

    await pumpMeadowStage(
      tester,
      year: _countedYear(
        year: 2025,
        blooms: 129,
        sprouts: 6,
        today: DateTime(2025, 7, 4),
      ),
    );
    expectSummary('Meadow, 2025: 129 blooms and 6 sprouts so far');

    await pumpMeadowStage(
      tester,
      year: _countedYear(
        year: 2024,
        blooms: 205,
        sprouts: 6,
        today: DateTime(2026, 3, 1),
      ),
    );
    expectSummary('Meadow, 2024: 205 blooms and 6 sprouts');

    final _Expected expected = _Expected(meadowSampleYear());
    final MeadowStageState state = await pumpMeadowStage(tester);
    expectSummary('Meadow, 2025: 16 blooms and 1 sprout');
    await growMeadow(tester, state);
    final TestGesture mouse = await _mouse(tester);
    await mouse.moveTo(
      _global(tester, state, expected.plantOn(6, 30).heads.last),
    );
    await tester.pump();
    expect(find.text('Mon, Jun 30'), findsOneWidget);
    expectSummary('Meadow, 2025: 16 blooms and 1 sprout');
    handle.dispose();
  });

  testWidgets(
    'the scene opens in batches the pacer sizes, one kind of step per batch',
    (WidgetTester tester) async {
      for (final double stepMs in <double>[0.1, 40]) {
        final StageGpu gpu = useStageGpu(stepMs: stepMs);
        final MeadowStageState state = await pumpMeadowStage(
          tester,
          year: meadowLeapYear(),
        );
        int most = 0;
        int creations = 0;
        for (int i = 0; i < meadowBuildFrames && !state.debugIsReady; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 2)),
          );
          final int steps = state.debugBuildSteps;
          final int pieces = state.debugRecolourPieces;
          final int batches = gpu.sent.length;
          tester.binding.scheduleFrame();
          await tester.pump(const Duration(milliseconds: 1));
          final int stepped = state.debugBuildSteps - steps;
          final int drawn = state.debugRecolourPieces - pieces;
          final List<StageBatch> sent = gpu.sent.sublist(batches);
          final String reason = '$stepMs ms a step, frame $i';
          if (drawn > 0) {
            expect(stepped, drawn, reason: '$reason drew a piece');
          }
          if (stepMs == 40) {
            final bool creates = sent.any(
              (StageBatch batch) =>
                  (batch.kind == MeadowWork.layers ||
                      batch.kind == MeadowWork.plants) &&
                  gpu.sent
                      .take(batches)
                      .every(
                        (StageBatch earlier) => earlier.kind != batch.kind,
                      ),
            );
            for (final StageBatch batch in sent) {
              expect(batch.steps, lessThanOrEqualTo(4), reason: reason);
            }
            expect(stepped, lessThanOrEqualTo(5), reason: reason);
            if (creates) {
              creations++;
            }
          }
          most = math.max(most, stepped);
        }
        expect(state.debugIsReady, isTrue, reason: '$stepMs ms a step');
        expect(state.debugRecolourPieces, greaterThan(1));
        if (stepMs == 40) {
          expect(
            creations,
            2,
            reason: 'the terrain layers and the plant atlas are created',
          );
          expect(most, 5);
        } else {
          expect(most, greaterThan(4));
        }
      }
    },
  );

  testWidgets(
    'pieces fill the snapshot room while the scene loads and once it is open',
    (WidgetTester tester) async {
      useStageGpu(stepMs: 6);
      const Key key = ValueKey<String>('shared stage');
      MeadowStageState state = await pumpMeadowStage(
        tester,
        tickers: false,
        stageKey: key,
      );
      final List<int> opening = <int>[];
      for (int i = 0; i < meadowBuildFrames && !state.debugIsReady; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
        final int pieces = state.debugRecolourPieces;
        tester.binding.scheduleFrame();
        await tester.pump(const Duration(milliseconds: 1));
        final int drawn = state.debugRecolourPieces - pieces;
        if (drawn > 0) {
          opening.add(drawn);
        }
      }
      expect(state.debugIsReady, isTrue);
      expect(opening, isNotEmpty);
      expect(opening, everyElement(lessThanOrEqualTo(4)), reason: '$opening');
      expect(
        opening.sublist(0, opening.length - 1),
        everyElement(4),
        reason: '$opening',
      );

      state = await pumpMeadowStage(
        tester,
        tickers: false,
        stageKey: key,
        sky: meadowMidnight,
      );
      expect(state.debugIsRecolouring, isTrue);
      final int before = state.debugRecolourPieces;
      final List<int> open = <int>[];
      while (state.debugIsRecolouring && open.length < 64) {
        final int pieces = state.debugRecolourPieces;
        await tester.pump();
        open.add(state.debugRecolourPieces - pieces);
      }
      expect(state.debugIsRecolouring, isFalse);
      expect(open, everyElement(lessThanOrEqualTo(4)), reason: '$open');
      expect(open, contains(4), reason: '$open');
      expect(state.debugRecolourPieces - before, greaterThan(1));
    },
  );

  testWidgets("a frame's build work stops at half the frame interval", (
    WidgetTester tester,
  ) async {
    final StageGpu gpu = useStageGpu(stepMs: 0.1);
    final MeadowStageState state = await pumpMeadowStage(
      tester,
      year: meadowLeapYear(),
    );
    gpu.busyStage = state;
    int threes = 0;
    for (int i = 0; i < meadowBuildFrames && !state.debugIsReady; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      final int steps = state.debugBuildSteps;
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 1));
      final int stepped = state.debugBuildSteps - steps;
      expect(stepped, lessThanOrEqualTo(3), reason: 'frame $i');
      if (stepped == 3) {
        threes++;
      }
    }
    expect(state.debugIsReady, isTrue);
    expect(threes, greaterThan(0));
  });

  testWidgets(
    'a build step that sends no GPU work never sizes the next batch',
    (WidgetTester tester) async {
      final StageGpu gpu = useStageGpu(stepMs: 0.1);
      final MeadowStageState state = await pumpMeadowStage(tester);
      await growMeadow(tester, state);
      expect(
        _countedSteps(gpu.sent),
        state.debugBuildSteps - 2,
        reason:
            'creating the terrain layers and the plant atlas counts nothing',
      );
      expect(
        gpu.sent
            .firstWhere((StageBatch batch) => batch.kind == MeadowWork.layers)
            .steps,
        1,
      );
      expect(
        gpu.sent
            .firstWhere((StageBatch batch) => batch.kind == MeadowWork.plants)
            .steps,
        1,
      );
    },
  );

  testWidgets("an open meadow's recolour work stops at half the frame "
      'interval', (WidgetTester tester) async {
    final StageGpu gpu = useStageGpu(stepMs: 0.1);
    const Key key = ValueKey<String>('busy recolour stage');
    MeadowStageState state = await pumpMeadowStage(
      tester,
      tickers: false,
      stageKey: key,
    );
    await growMeadow(tester, state);
    gpu.busyStage = state;
    final int before = state.debugRecolourPieces;

    state = await pumpMeadowStage(
      tester,
      tickers: false,
      stageKey: key,
      sky: meadowMidnight,
    );
    expect(state.debugIsRecolouring, isTrue);
    int threes = 0;
    int frames = 0;
    while (state.debugIsRecolouring && frames < 64) {
      final int drawn = state.debugRecolourPieces;
      await tester.pump();
      frames++;
      final int pieces = state.debugRecolourPieces - drawn;
      expect(pieces, lessThanOrEqualTo(3), reason: 'frame $frames');
      if (pieces == 3) {
        threes++;
      }
    }
    expect(state.debugIsRecolouring, isFalse);
    expect(threes, greaterThan(0));
    expect(state.debugRecolourPieces - before, greaterThan(3));
  });

  testWidgets('a meadow sends nothing while the pacer is behind', (
    WidgetTester tester,
  ) async {
    final HeldGpu gpu = installPacer(HeldGpu());
    final MeadowStageState state = await pumpMeadowStage(tester);
    for (int i = 0; i < meadowBuildFrames && !gpu.isBehind; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(gpu.isBehind, isTrue, reason: 'a batch carried behind a marker');
    final int steps = state.debugBuildSteps;
    final int pieces = state.debugRecolourPieces;
    final int waited = state.debugOpeningWaited;
    final int begun = gpu.phases.length;
    expect(steps, greaterThan(0));
    for (int i = 0; i < 8; i++) {
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 1));
      expect(state.debugBuildSteps, steps, reason: 'frame $i while behind');
      expect(state.debugRecolourPieces, pieces, reason: 'frame $i');
    }
    expect(
      state.debugOpeningWaited,
      waited + 8,
      reason: 'it waited each frame',
    );
    expect(gpu.phases, hasLength(begun), reason: 'no batch began while behind');

    gpu.answers[0].complete();
    tester.binding.scheduleFrame();
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      state.debugBuildSteps,
      greaterThan(steps),
      reason: 'the marker answered, so the next frame builds',
    );

    for (int i = 0; i < meadowBuildFrames && !state.debugIsReady; i++) {
      for (final Completer<void> answer in gpu.answers) {
        if (!answer.isCompleted) {
          answer.complete();
        }
      }
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(state.debugIsReady, isTrue);
  });

  testWidgets(
    'a sky change on an open meadow is paced, repaints each frame it draws '
    'and finishes with motion off',
    (WidgetTester tester) async {
      useStageGpu(stepMs: 12);
      const Key key = ValueKey<String>('recolour stage');
      MeadowStageState state = await pumpMeadowStage(
        tester,
        tickers: false,
        stageKey: key,
      );
      await growMeadow(tester, state);
      expect(state.debugIsRecolouring, isFalse);
      final int before = state.debugRecolourPieces;

      state = await pumpMeadowStage(
        tester,
        tickers: false,
        stageKey: key,
        sky: meadowMidnight,
      );

      expect(state.debugIsRecolouring, isTrue);
      int frames = 0;
      int widest = 0;
      while (state.debugIsRecolouring && frames < 64) {
        final int drawn = state.debugRecolourPieces;
        final MeadowStagePainter painted = _stagePainter(tester);
        await tester.pump();
        frames++;
        expect(
          state.debugRecolourPieces - drawn,
          lessThanOrEqualTo(4),
          reason: 'frame $frames',
        );
        widest = math.max(widest, state.debugRecolourPieces - drawn);
        final MeadowStagePainter now = _stagePainter(tester);
        if (now.layersRevision != painted.layersRevision ||
            now.raysRevision != painted.raysRevision) {
          expect(
            now.shouldRepaint(painted),
            isTrue,
            reason: 'repaint after frame $frames',
          );
        }
      }
      expect(state.debugIsRecolouring, isFalse);
      expect(state.debugRecolourPieces - before, greaterThan(1));
      expect(widest, greaterThan(1), reason: 'a frame drew several pieces');

      useStageGpu(stepMs: 0.1);
      final int midnight = state.debugRecolourPieces;
      state = await pumpMeadowStage(tester, tickers: false, stageKey: key);
      expect(state.debugIsRecolouring, isTrue);
      int most = 0;
      frames = 0;
      while (state.debugIsRecolouring && frames < 64) {
        final int drawn = state.debugRecolourPieces;
        final MeadowStagePainter painted = _stagePainter(tester);
        await tester.pump();
        frames++;
        most = math.max(most, state.debugRecolourPieces - drawn);
        final MeadowStagePainter now = _stagePainter(tester);
        if (now.layersRevision != painted.layersRevision ||
            now.raysRevision != painted.raysRevision) {
          expect(
            now.shouldRepaint(painted),
            isTrue,
            reason: 'repaint after frame $frames back to noon',
          );
        }
      }
      expect(state.debugIsRecolouring, isFalse);
      expect(state.debugRecolourPieces, greaterThan(midnight));
      expect(most, greaterThan(1));
    },
  );

  testWidgets(
    'a sky change while the meadow opens is finished once it appears',
    (WidgetTester tester) async {
      useStageGpu(stepMs: 40);
      const Key key = ValueKey<String>('opening stage');
      final MeadowYear leap = meadowLeapYear();
      MeadowStageState state = await pumpMeadowStage(
        tester,
        year: leap,
        tickers: false,
        stageKey: key,
      );
      int last = -1;
      int still = 0;
      for (
        int i = 0;
        i < meadowBuildFrames && !state.debugIsReady && still < 2;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
        tester.binding.scheduleFrame();
        await tester.pump(const Duration(milliseconds: 1));
        final int pieces = state.debugRecolourPieces;
        still = pieces > 0 && pieces == last ? still + 1 : 0;
        last = pieces;
      }
      expect(
        state.debugIsReady,
        isFalse,
        reason: 'first colours done, still opening',
      );

      state = await pumpMeadowStage(
        tester,
        year: leap,
        tickers: false,
        stageKey: key,
        sky: meadowMidnight,
      );
      await growMeadow(tester, state);
      expect(
        state.debugIsRecolouring,
        isTrue,
        reason: 'the scene appeared with pieces still to redraw',
      );
      expect(
        state.debugRecolourPieces,
        last,
        reason: 'the build drew only the first colours',
      );
      int frames = 0;
      while (state.debugIsRecolouring && frames < 64) {
        await tester.pump();
        frames++;
      }
      expect(state.debugIsRecolouring, isFalse);
      expect(state.debugRecolourPieces, greaterThan(last));
    },
  );

  testWidgets(
    'two meadows share one pacer and the covered one waits for the visible one',
    (WidgetTester tester) async {
      useStageGpu(stepMs: 12);
      final ValueNotifier<SkyScene> coveredSky = ValueNotifier<SkyScene>(
        meadowNoon,
      );
      addTearDown(coveredSky.dispose);
      final ValueNotifier<SkyScene> visibleSky = ValueNotifier<SkyScene>(
        meadowNoon,
      );
      addTearDown(visibleSky.dispose);
      final MeadowYear shown = meadowSampleYear();
      final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
      const Key coveredKey = ValueKey<String>('covered meadow');
      const Key visibleKey = ValueKey<String>('visible meadow');
      final int coveredSeed = meadowSeed(meadowStageKey, shown.year);
      final int visibleSeed = meadowSeed(meadowStageKey + 1, shown.year);
      Widget meadow(Key key, ValueNotifier<SkyScene> sky, int seed) => Scaffold(
        body: Center(
          child: SizedBox.fromSize(
            size: meadowSidebarCard,
            child: ValueListenableBuilder<SkyScene>(
              valueListenable: sky,
              builder: (BuildContext context, SkyScene value, Widget? child) =>
                  MeadowStage(
                    key: key,
                    year: shown,
                    seed: seed,
                    sky: value,
                    morning: false,
                    mode: MeadowSceneMode.page,
                    compact: false,
                    motion: GardenMotionProfile.reduced,
                  ),
            ),
          ),
        ),
      );
      tester.view.physicalSize = Size(
        meadowSidebarCard.width + 2 * meadowStageMargin,
        meadowSidebarCard.height + 2 * meadowStageMargin,
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          debugShowCheckedModeBanner: false,
          theme: fieldNotesTheme(
            platform: TargetPlatform.macOS,
            brightness: Brightness.light,
          ),
          home: meadow(coveredKey, coveredSky, coveredSeed),
        ),
      );
      final MeadowStageState covered = tester.state<MeadowStageState>(
        find.byKey(coveredKey),
      );
      await growMeadow(tester, covered);
      navigator.currentState!.push(
        PageRouteBuilder<void>(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondary,
          ) => meadow(visibleKey, visibleSky, visibleSeed),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
      await tester.pump();
      final MeadowStageState visible = tester.state<MeadowStageState>(
        find.byKey(visibleKey),
      );
      await growMeadow(tester, visible);
      final int coveredBefore = covered.debugRecolourPieces;
      final int visibleBefore = visible.debugRecolourPieces;

      coveredSky.value = meadowMidnight;
      await tester.pump();
      expect(covered.debugIsRecolouring, isTrue);
      visibleSky.value = meadowMidnight;

      int frames = 0;
      bool visibleWaiting = false;
      do {
        final int coveredDrawn = covered.debugRecolourPieces;
        final int visibleDrawn = visible.debugRecolourPieces;
        await tester.pump();
        frames++;
        final int byCovered = covered.debugRecolourPieces - coveredDrawn;
        final int byVisible = visible.debugRecolourPieces - visibleDrawn;
        if (byVisible > 0) {
          expect(
            byCovered,
            0,
            reason: 'frame $frames, the visible meadow sent the batch',
          );
        }
        if (visibleWaiting) {
          expect(
            byCovered,
            0,
            reason: 'frame $frames, the visible meadow still had pieces',
          );
        }
        visibleWaiting = visible.debugIsRecolouring;
      } while ((visible.debugIsRecolouring || covered.debugIsRecolouring) &&
          frames < 96);
      expect(visible.debugIsRecolouring, isFalse);
      expect(covered.debugIsRecolouring, isFalse);
      expect(visible.debugRecolourPieces, greaterThan(visibleBefore));
      expect(covered.debugRecolourPieces, greaterThan(coveredBefore));
    },
  );

  testWidgets('the whole scene fits the memory ceiling', (
    WidgetTester tester,
  ) async {
    final MeadowYear leap = meadowLeapYear();
    expect(leap.blooms + leap.sprouts, 366);
    final int seed = meadowSeed(meadowStageKey, leap.year);
    final MeadowTerrain terrain = buildMeadowTerrain(seed: seed, year: leap);
    final List<MeadowGrassBand> grass = buildMeadowGrass(
      seed: seed,
      terrain: terrain,
    );
    for (final (
          Size box,
          double ratio,
          bool compact,
          MeadowSceneMode mode,
          int ceiling,
        )
        in <(Size, double, bool, MeadowSceneMode, int)>[
          (_phoneScreen, 2.625, true, MeadowSceneMode.full, 96 * _megabyte),
          (meadowSidebarCard, 2, false, MeadowSceneMode.page, 48 * _megabyte),
          (_bottomBarCard, 2.625, true, MeadowSceneMode.page, 48 * _megabyte),
        ]) {
      final String reason = '$box at $ratio';
      final double screen =
          MeadowViewport.resolve(
            box: box,
            cover: compact || mode == MeadowSceneMode.full,
            focusX: 0,
          ).scale *
          ratio;
      final MeadowStageState state = await pumpMeadowStage(
        tester,
        year: leap,
        box: box,
        ratio: ratio,
        compact: compact,
        mode: mode,
        stageKey: ValueKey<String>(reason),
      );
      await growMeadow(tester, state);
      final MeadowStagePainter quick = _stagePainter(tester);
      expect(quick.layers.density, lessThan(screen), reason: reason);
      expect(state.debugImageBytes, _sceneBytes(quick), reason: reason);
      expect(
        state.debugImageBytes,
        allOf(greaterThan(0), lessThanOrEqualTo(ceiling)),
        reason: reason,
      );

      final MeadowStagePainter sharp = await _sharpen(tester, screen);
      expect(sharp.atlas.density, closeTo(screen, 1e-9), reason: reason);
      expect(
        state.debugImageBytes,
        MeadowLayers.bytesAt(terrain: terrain, grass: grass, density: screen) +
            sharp.atlas.imageBytes +
            sharp.creatures.imageBytes +
            sharp.rays.imageBytes,
        reason: reason,
      );
    }
  });
}
