import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/petal_art.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/onboarding/chapters/day_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/garden_scene.dart';
import 'package:field_notes/features/onboarding/chapters/moment_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/opening_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/theme_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';
import '../capture/core/capture_test_support.dart' show FakeNoteWriter;
import '../settings/support/fake_settings_repository.dart';
import '../settings/support/recording_reminder_scheduler.dart';

const Size _sidebarSurface = Size(1280, 800);
const Size _bottomBarSurface = Size(360, 740);

const Duration _step = Duration(milliseconds: 100);
const Duration _peonyGrowth = Duration(milliseconds: 3500);
const Duration _plantGrowth = Duration(milliseconds: 900);
const Duration _partGrown = Duration(milliseconds: 300);
const Duration _shown = Duration(seconds: 1);
const Duration _pastLongestLoop = Duration(seconds: 30);
const int _maxSteps = 60;

Future<void> _onLayout(ShellLayout layout, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = switch (layout) {
    ShellLayout.sidebar => TargetPlatform.macOS,
    ShellLayout.bottomBar => TargetPlatform.android,
  };
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

List<Override> _overrides() {
  final Set<Object> replaced = <Object>{
    settingsRepositoryProvider,
    reminderSchedulerProvider,
  };
  return <Override>[
    for (final Override override in shellOverrides())
      if (!replaced.contains(override.origin)) override,
    settingsRepositoryProvider.overrideWithValue(
      FakeSettingsRepository(storedValues: false),
    ),
    reminderSchedulerProvider.overrideWithValue(RecordingReminderScheduler()),
    onboardingCountryCodeProvider.overrideWithValue('US'),
    noteWriterProvider.overrideWith((Ref ref) => FakeNoteWriter()),
  ];
}

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  ShellLayout layout,
) async {
  tester.view.physicalSize = switch (layout) {
    ShellLayout.sidebar => _sidebarSurface,
    ShellLayout.bottomBar => _bottomBarSurface,
  };
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(),
      child: const FieldNotesApp(),
    ),
  );
  await _settle(tester);
  expect(find.byType(OpeningChapter), findsOneWidget);
  return ProviderScope.containerOf(tester.element(find.byType(AppShell)));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

void _holdStill(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

OnboardingController _controller(ProviderContainer container) =>
    container.read(onboardingControllerProvider.notifier);

OnboardingFlowRunning _running(ProviderContainer container) =>
    container.read(onboardingControllerProvider) as OnboardingFlowRunning;

Finder get _framePetals => find.descendant(
  of: find.byType(OnboardingFrame),
  matching: find.byType(PetalDrift),
);

FlowerKind? _shedding(WidgetTester tester) => _framePetals.evaluate().isEmpty
    ? null
    : tester.widget<PetalDrift>(_framePetals).flower;

Set<int> _coloursOf(FlowerKind kind) => <int>{
  for (final PetalPiece piece in petalArtFor(kind)!.pieces) ...<int>[
    if (piece.fill case final Color fill) fill.toARGB32() & 0xFFFFFF,
    if (piece.outline case final Color outline) outline.toARGB32() & 0xFFFFFF,
  ],
};

Set<int> _paintedColours(WidgetTester tester) {
  final Finder layer = find.descendant(
    of: _framePetals,
    matching: find.byType(CustomPaint),
  );
  if (layer.evaluate().isEmpty) {
    return const <int>{};
  }
  final RenderCustomPaint render = tester.renderObject<RenderCustomPaint>(
    layer,
  );
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  render.painter!.paint(canvas, render.size);
  return <int>{
    for (final RecordedInvocation call in canvas.invocations)
      if (call.invocation.memberName == #drawPath)
        (call.invocation.positionalArguments[1] as Paint).color.toARGB32() &
            0xFFFFFF,
  };
}

void _expectShedding(
  WidgetTester tester,
  FlowerKind kind, {
  required String reason,
}) {
  final Set<int> painted = _paintedColours(tester);
  expect(painted, isNotEmpty, reason: '$reason paints no petals');
  expect(
    _coloursOf(kind).containsAll(painted),
    isTrue,
    reason: '$reason paints petals that are not ${kind.name}',
  );
}

double _plantGrowthOf(WidgetTester tester, FlowerKind kind) {
  final CustomPaint plant = tester.widget<CustomPaint>(
    find.byKey(gardenFlowerKey(kind)),
  );
  return (plant.painter! as GardenBloomPainter).growth;
}

Future<void> _advance(WidgetTester tester, ShellLayout layout) async {
  if (layout == ShellLayout.sidebar) {
    await tester.tap(find.byKey(onboardingPrimaryKey));
    return;
  }
  expect(find.byKey(onboardingPrimaryKey), findsNothing);
  final Rect frame = tester.getRect(find.byType(OnboardingFrame));
  await tester.flingFrom(
    Offset(frame.center.dx, frame.top + frame.height * 0.45),
    const Offset(-120, 0),
    800,
  );
}

Future<Duration> _growPeony(
  WidgetTester tester,
  ProviderContainer container, {
  required String reason,
}) async {
  _controller(container).plant();
  await tester.pump();
  Duration elapsed = Duration.zero;
  for (
    int step = 0;
    step < _maxSteps && !_running(container).draft.grown;
    step++
  ) {
    expect(
      _paintedColours(tester),
      isEmpty,
      reason: '$reason paints petals ${elapsed.inMilliseconds} ms into growth',
    );
    await tester.pump(_step);
    elapsed += _step;
  }
  expect(_running(container).draft.grown, isTrue, reason: reason);
  return elapsed;
}

Future<void> _expectPetalsAfterThePeonyHasGrown(
  WidgetTester tester,
  ShellLayout layout,
) async {
  final String name = layout.name;
  final ProviderContainer container = await _pumpApp(tester, layout);
  expect(_paintedColours(tester), isEmpty, reason: '$name before planting');

  final Duration grew = await _growPeony(tester, container, reason: name);
  expect(
    grew,
    greaterThanOrEqualTo(_peonyGrowth - _step),
    reason: '$name grew too soon',
  );
  await tester.pump();
  await tester.pump(_shown);
  expect(_shedding(tester), FlowerKind.peony, reason: name);
  _expectShedding(tester, FlowerKind.peony, reason: '$name grown');
  await _unmount(tester);
}

Future<void> _expectNoPetalsWithReduceMotion(
  WidgetTester tester,
  ShellLayout layout,
) async {
  final String name = '${layout.name} reduce motion';
  final ProviderContainer container = await _pumpApp(tester, layout);
  _controller(container).plant();
  await _settle(tester);
  expect(_running(container).draft.grown, isTrue, reason: name);
  await tester.pump(_shown);
  expect(_paintedColours(tester), isEmpty, reason: name);
  await _unmount(tester);
}

Future<void> _openDay(
  WidgetTester tester,
  ProviderContainer container,
  ShellLayout layout, {
  required String reason,
}) async {
  _controller(container)
    ..plant()
    ..markGrown();
  await _settle(tester);
  await _advance(tester, layout);
  await _settle(tester);
  expect(find.byType(DayChapter), findsOneWidget, reason: reason);
  await tester.pump(_plantGrowth);
  await tester.pump();
  expect(_shedding(tester), FlowerKind.peony, reason: '$reason on A day');
}

Future<void> _expectSwitchOnceGrown(
  WidgetTester tester,
  ProviderContainer container,
  Mood mood, {
  required FlowerKind before,
  required String reason,
}) async {
  _controller(container).chooseMood(mood);
  await tester.pump();
  for (
    Duration growing = Duration.zero;
    growing <= _plantGrowth;
    growing += _step
  ) {
    expect(
      _shedding(tester),
      before,
      reason:
          '$reason switched ${growing.inMilliseconds} ms into the '
          '${mood.flower.name} growth',
    );
    await tester.pump(_step);
  }
  await tester.pump(_step);
  await tester.pump();
  expect(_plantGrowthOf(tester, mood.flower), 1, reason: '$reason grown');
  expect(_shedding(tester), mood.flower, reason: '$reason once grown');
}

Future<void> _expectChosenFlowerSheds(
  WidgetTester tester,
  ShellLayout layout,
) async {
  final String name = layout.name;
  final ProviderContainer container = await _pumpApp(tester, layout);
  await _openDay(tester, container, layout, reason: name);

  await _expectSwitchOnceGrown(
    tester,
    container,
    Mood.anxious,
    before: FlowerKind.peony,
    reason: '$name anxious',
  );

  _controller(container).chooseMood(Mood.angry);
  await tester.pump();
  await tester.pump(_partGrown);
  expect(
    _plantGrowthOf(tester, FlowerKind.redSpiderLily),
    lessThan(1),
    reason: '$name angry',
  );
  expect(_shedding(tester), FlowerKind.aster, reason: '$name angry growing');
  await _advance(tester, layout);
  await tester.pump();
  expect(find.byType(MomentChapter), findsOneWidget, reason: name);
  expect(
    _shedding(tester),
    FlowerKind.redSpiderLily,
    reason: '$name next before grown',
  );

  await tester.pump(_pastLongestLoop);
  await tester.pump();
  expect(find.byType(MomentChapter), findsOneWidget, reason: name);
  _expectShedding(tester, FlowerKind.redSpiderLily, reason: '$name moment');
  await _unmount(tester);
}

Future<void> _expectOpeningShedsPeonyAgain(
  WidgetTester tester,
  ShellLayout layout,
) async {
  final String name = layout.name;
  final ProviderContainer container = await _pumpApp(tester, layout);
  await _openDay(tester, container, layout, reason: name);
  await _expectSwitchOnceGrown(
    tester,
    container,
    Mood.anxious,
    before: FlowerKind.peony,
    reason: '$name anxious',
  );

  _controller(container).back();
  await _settle(tester);
  expect(find.byType(OpeningChapter), findsOneWidget, reason: name);
  expect(_shedding(tester), FlowerKind.peony, reason: '$name back on Opening');
  await tester.pump(_pastLongestLoop);
  await tester.pump();
  _expectShedding(tester, FlowerKind.peony, reason: '$name Opening');

  await _advance(tester, layout);
  await _settle(tester);
  expect(find.byType(DayChapter), findsOneWidget, reason: name);
  expect(_shedding(tester), FlowerKind.aster, reason: '$name A day again');
  await _unmount(tester);
}

Future<void> _expectSkipKeepsWhatGrew(
  WidgetTester tester,
  ShellLayout layout,
) async {
  final String name = layout.name;
  final ProviderContainer grown = await _pumpApp(tester, layout);
  _controller(grown)
    ..plant()
    ..markGrown();
  await _settle(tester);
  _controller(grown).skipToSetup();
  await _settle(tester);
  expect(find.byType(ThemeChapter), findsOneWidget, reason: name);
  expect(_shedding(tester), FlowerKind.peony, reason: '$name skip after grown');
  _controller(grown).next();
  await _settle(tester);
  expect(
    _running(grown).chapter,
    OnboardingChapter.reminder,
    reason: '$name reminder',
  );
  expect(_shedding(tester), FlowerKind.peony, reason: '$name reminder');
  await _unmount(tester);

  final ProviderContainer unplanted = await _pumpApp(tester, layout);
  _controller(unplanted).skipToSetup();
  await _settle(tester);
  expect(find.byType(ThemeChapter), findsOneWidget, reason: name);
  expect(_framePetals, findsNothing, reason: '$name skip before planting');
  await tester.pump(_shown);
  expect(_paintedColours(tester), isEmpty, reason: '$name skip unplanted');
  await _unmount(tester);
}

void main() {
  testWidgets('petals start only after the peony has fully grown', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        await _expectPetalsAfterThePeonyHasGrown(tester, layout);
      });
    }
    _holdStill(tester);
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        await _expectNoPetalsWithReduceMotion(tester, layout);
      });
    }
  });

  testWidgets('a newly chosen flower sheds only after its plant has grown', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        await _expectChosenFlowerSheds(tester, layout);
        await _expectSkipKeepsWhatGrew(tester, layout);
      });
    }
  });

  testWidgets('the Opening sheds peony petals after going back', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        await _expectOpeningShedsPeonyAgain(tester, layout);
      });
    }
  });
}
