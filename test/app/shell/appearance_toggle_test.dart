import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/appearance_toggle.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/onboarding/chapters/opening_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/capture/core/capture_test_support.dart'
    show FakeNoteWriter;
import '../../features/settings/support/fake_settings_repository.dart';
import '../../features/settings/support/recording_reminder_scheduler.dart';
import '../support/app_shell_harness.dart';

const double _statusBar = 24;
const String _failure = 'Could not save your appearance.';

typedef _Layout = ({ShellLayout layout, TargetPlatform platform, Size surface});

const List<_Layout> _layouts = <_Layout>[
  (
    layout: ShellLayout.sidebar,
    platform: TargetPlatform.macOS,
    surface: Size(1280, 800),
  ),
  (
    layout: ShellLayout.bottomBar,
    platform: TargetPlatform.android,
    surface: Size(480, 960),
  ),
];

AppSettings _onboardedWith(Appearance appearance) =>
    AppSettings.defaults.copyWith(
      onboardingStatus: OnboardingStatus.done,
      notificationPermissionAsked: true,
      appearance: appearance,
    );

FakeSettingsRepository _onboarded(Appearance appearance) =>
    FakeSettingsRepository(initial: _onboardedWith(appearance));

FakeSettingsRepository _freshInstall({Object? writeError}) =>
    FakeSettingsRepository(storedValues: false, writeError: writeError);

FakeSettingsRepository _midOnboarding(Appearance appearance) =>
    FakeSettingsRepository(
      initial: AppSettings.defaults.copyWith(
        onboardingStatus: OnboardingStatus.pending,
        notificationPermissionAsked: true,
        appearance: appearance,
      ),
    );

Future<void> _onLayout(_Layout layout, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = layout.platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void _onDevice(WidgetTester tester, Brightness brightness) {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

List<Override> _overrides(FakeSettingsRepository settings) {
  final Set<Object> replaced = <Object>{
    settingsRepositoryProvider,
    reminderSchedulerProvider,
  };
  return <Override>[
    for (final Override override in shellOverrides())
      if (!replaced.contains(override.origin)) override,
    settingsRepositoryProvider.overrideWithValue(settings),
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
  _Layout layout,
  FakeSettingsRepository settings,
) async {
  tester.view.physicalSize = layout.surface;
  tester.view.devicePixelRatio = 1;
  if (layout.layout == ShellLayout.bottomBar) {
    tester.view.padding = const FakeViewPadding(top: _statusBar);
    tester.view.viewPadding = const FakeViewPadding(top: _statusBar);
  }
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(settings),
      child: const FieldNotesApp(),
    ),
  );
  await _settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(AppShell)));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

List<String> _recordWindowCalls(WidgetTester tester) {
  final List<String> calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    windowChannel,
    (MethodCall call) async {
      calls.add(call.method);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      windowChannel,
      null,
    ),
  );
  return calls;
}

Finder get _anyToggle => find.byKey(appearanceToggleKey);

Finder get _frameToggle => find.descendant(
  of: find.byType(OnboardingFrame),
  matching: find.byKey(appearanceToggleKey),
);

Finder _onboardingToggle(ShellLayout layout) => _frameToggle;

Finder get _titleBarToggle => find.descendant(
  of: find.byKey(windowTitleBarKey),
  matching: find.byType(AppearanceToggle),
);

MaterialApp _app(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp));

bool _hitTestable(WidgetTester tester, Finder finder) {
  final RenderObject target = tester.renderObject(finder);
  final HitTestResult result = tester.hitTestOnBinding(
    tester.getCenter(finder),
  );
  return result.path.any(
    (HitTestEntry entry) => identical(entry.target, target),
  );
}

Future<void> _tapToggle(WidgetTester tester, Finder toggle) async {
  await tester.tap(toggle);
  await tester.idle();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void _expectShowing(
  WidgetTester tester,
  Finder toggle,
  Brightness brightness, {
  required String reason,
}) {
  final bool dark = brightness == Brightness.dark;
  final String label = dark
      ? appearanceToggleLightLabel
      : appearanceToggleDarkLabel;
  expect(
    Theme.of(tester.element(toggle)).brightness,
    brightness,
    reason: reason,
  );
  expect(
    find.descendant(
      of: toggle,
      matching: find.byKey(
        dark ? appearanceToggleSunKey : appearanceToggleMoonKey,
      ),
    ),
    findsOneWidget,
    reason: reason,
  );
  expect(
    find.descendant(
      of: toggle,
      matching: find.byKey(
        dark ? appearanceToggleMoonKey : appearanceToggleSunKey,
      ),
    ),
    findsNothing,
    reason: reason,
  );
  expect(
    tester.getSemantics(toggle),
    isSemantics(label: label, isButton: true, hasTapAction: true),
    reason: reason,
  );
  expect(
    tester
        .widget<Tooltip>(
          find.ancestor(of: toggle, matching: find.byType(Tooltip)).first,
        )
        .message,
    label,
    reason: reason,
  );
}

void _doTask(OnboardingController controller, OnboardingChapter chapter) {
  switch (chapter) {
    case OnboardingChapter.opening:
      controller
        ..plant()
        ..markGrown();
    case OnboardingChapter.moment:
      controller.setNote('A first line about today');
    case OnboardingChapter.month:
      controller.setMonthFill(1);
    case OnboardingChapter.year:
      controller.setYearDay(365, scrubbed: true);
    case OnboardingChapter.day ||
        OnboardingChapter.theme ||
        OnboardingChapter.reminder ||
        OnboardingChapter.week ||
        OnboardingChapter.tour:
      return;
  }
}

void _expectReachableDuringOnboarding(
  WidgetTester tester,
  _Layout layout, {
  required String reason,
}) {
  final Finder toggle = _onboardingToggle(layout.layout);
  expect(toggle, findsOneWidget, reason: reason);
  expect(_anyToggle, findsOneWidget, reason: reason);
  expect(_hitTestable(tester, toggle), isTrue, reason: reason);
  expect(_titleBarToggle, findsNothing, reason: reason);
  final Rect target = tester.getRect(toggle);
  final Finder glass = find.descendant(
    of: find.byKey(onboardingToggleKey),
    matching: find.byType(GlassSurface),
  );
  expect(glass, findsOneWidget, reason: reason);
  switch (layout.layout) {
    case ShellLayout.sidebar:
      expect(
        target.top,
        greaterThanOrEqualTo(shellTitleBarHeight),
        reason: reason,
      );
      expect(target.width, greaterThanOrEqualTo(44), reason: reason);
      expect(target.height, greaterThanOrEqualTo(44), reason: reason);
      expect(
        tester.getRect(glass),
        const Rect.fromLTWH(18, shellTitleBarHeight + 8, 36, 36),
        reason: reason,
      );
    case ShellLayout.bottomBar:
      expect(
        target,
        const Rect.fromLTWH(8, _statusBar + 2, 44, 44),
        reason: reason,
      );
      expect(tester.getRect(glass), target, reason: reason);
  }
}

Future<void> _absentAfterOnboarding(WidgetTester tester, _Layout layout) async {
  final String name = layout.layout.name;
  final FakeSettingsRepository settings = _onboarded(Appearance.light);
  await _pumpApp(tester, layout, settings);
  expect(find.byType(OnboardingFrame), findsNothing, reason: name);
  expect(_anyToggle, findsNothing, reason: name);
  expect(find.byType(AppearanceToggle), findsNothing, reason: name);
  expect(find.byKey(windowTitleBarKey), switch (layout.layout) {
    ShellLayout.sidebar => findsOneWidget,
    ShellLayout.bottomBar => findsNothing,
  }, reason: name);
  expect(
    find.bySemanticsLabel(appearanceToggleDarkLabel),
    findsNothing,
    reason: name,
  );
  expect(settings.appearanceWrites, isEmpty, reason: name);
  await _unmount(tester);
}

Future<void> _flipsSystemDuringOnboardingOnADarkDevice(
  WidgetTester tester,
  _Layout layout,
) async {
  final String name = '${layout.layout.name} system';
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  final FakeSettingsRepository settings = _midOnboarding(Appearance.system);
  await _pumpApp(tester, layout, settings);
  expect(_app(tester).themeMode, ThemeMode.system, reason: name);
  final Finder toggle = _onboardingToggle(layout.layout);
  _expectReachableDuringOnboarding(tester, layout, reason: name);
  _expectShowing(tester, toggle, Brightness.dark, reason: name);

  await _tapToggle(tester, toggle);
  expect(settings.appearanceWrites, <Appearance>[Appearance.light]);
  expect(_app(tester).themeMode, ThemeMode.light, reason: name);
  _expectShowing(tester, toggle, Brightness.light, reason: name);
  await _unmount(tester);
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
}

Future<void> _worksThroughOnboarding(
  WidgetTester tester,
  _Layout layout,
) async {
  final String name = layout.layout.name;
  final List<String> windowCalls = _recordWindowCalls(tester);
  final FakeSettingsRepository settings = _freshInstall();
  final ProviderContainer container = await _pumpApp(tester, layout, settings);
  final OnboardingController controller = container.read(
    onboardingControllerProvider.notifier,
  );
  expect(find.byType(OpeningChapter), findsOneWidget, reason: name);
  _expectReachableDuringOnboarding(tester, layout, reason: '$name opening');
  final Finder toggle = _onboardingToggle(layout.layout);
  _expectShowing(tester, toggle, Brightness.light, reason: '$name opening');
  final int appearanceCalls = windowCalls
      .where((String call) => call == setAppearanceMethod)
      .length;

  await _tapToggle(tester, toggle);
  expect(settings.appearanceWrites, <Appearance>[Appearance.dark]);
  expect(_app(tester).themeMode, ThemeMode.dark, reason: name);
  _expectShowing(tester, toggle, Brightness.dark, reason: '$name opening');
  expect(
    Theme.of(tester.element(find.byType(OpeningChapter))).brightness,
    Brightness.dark,
    reason: name,
  );
  final OnboardingFlowRunning flow =
      container.read(onboardingControllerProvider) as OnboardingFlowRunning;
  expect(flow.chapter, OnboardingChapter.opening, reason: name);
  expect(flow.draft.planted, isFalse, reason: name);
  expect(find.byType(OpeningChapter), findsOneWidget, reason: name);

  if (layout.layout == ShellLayout.sidebar) {
    expect(windowCalls, isNot(contains(startDragMethod)));
    expect(windowCalls, isNot(contains(titlebarDoubleClickMethod)));
    expect(
      windowCalls.where((String call) => call == setAppearanceMethod).length,
      appearanceCalls + 1,
    );
    await tester.dragFrom(
      tester.getCenter(find.byKey(windowTitleBarKey)),
      const Offset(60, 0),
    );
    await tester.pump();
    expect(windowCalls, contains(startDragMethod));
  }

  for (final OnboardingChapter chapter in OnboardingChapter.values) {
    if (chapter != OnboardingChapter.opening) {
      _doTask(controller, OnboardingChapter.values[chapter.index - 1]);
      controller.next();
      await _settle(tester);
    }
    final String reason = '$name ${chapter.name}';
    expect(
      (container.read(
        onboardingControllerProvider,
      ) as OnboardingFlowRunning).chapter,
      chapter,
      reason: reason,
    );
    _expectReachableDuringOnboarding(tester, layout, reason: reason);
    _expectShowing(tester, toggle, Brightness.dark, reason: reason);
    final Color ink = chapter == OnboardingChapter.year
        ? FieldNotesColors.light.composerPaper
        : FieldNotesColors.of(tester.element(toggle)).ink;
    expect(
      find.descendant(of: toggle, matching: find.byKey(appearanceToggleSunKey)),
      paints..circle(color: ink),
      reason: reason,
    );
  }
  expect(settings.appearanceWrites, <Appearance>[Appearance.dark]);
  await _unmount(tester);
}

Future<void> _absentOnTheMap(WidgetTester tester, _Layout layout) async {
  final String name = '${layout.layout.name} map';
  final FakeSettingsRepository settings = _onboarded(Appearance.light);
  final ProviderContainer container = await _pumpApp(tester, layout, settings);
  container.read(onboardingControllerProvider.notifier).showMap();
  await _settle(tester);
  expect(
    container.read(onboardingControllerProvider),
    const OnboardingFlowMap(),
  );
  expect(find.byType(OnboardingFrame), findsOneWidget, reason: name);
  expect(
    find.descendant(
      of: find.byKey(onboardingPrimaryKey),
      matching: find.text('Done'),
    ),
    findsOneWidget,
    reason: name,
  );
  expect(_anyToggle, findsNothing, reason: name);
  expect(find.byType(AppearanceToggle), findsNothing, reason: name);
  expect(find.byKey(onboardingToggleKey), findsNothing, reason: name);
  expect(
    find.bySemanticsLabel(appearanceToggleDarkLabel),
    findsNothing,
    reason: name,
  );

  container.read(onboardingControllerProvider.notifier).closeMap();
  await _settle(tester);
  expect(find.byType(OnboardingFrame), findsNothing, reason: name);
  expect(_anyToggle, findsNothing, reason: '$name closed');
  expect(settings.appearanceWrites, isEmpty, reason: name);
  await _unmount(tester);
}

void main() {
  testWidgets(
    'the toggle shows only during onboarding, flips what is showing and '
    'saves it',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      _onDevice(tester, Brightness.light);
      for (final _Layout layout in _layouts) {
        await _onLayout(layout, () async {
          await _absentAfterOnboarding(tester, layout);
          await _flipsSystemDuringOnboardingOnADarkDevice(tester, layout);
          await _worksThroughOnboarding(tester, layout);
          await _absentOnTheMap(tester, layout);
        });
      }
      handle.dispose();
    },
  );

  testWidgets('a failed appearance write shows its message and keeps the '
      'theme', (WidgetTester tester) async {
    _onDevice(tester, Brightness.light);
    for (final _Layout layout in _layouts) {
      await _onLayout(layout, () async {
        final String name = layout.layout.name;
        final FakeSettingsRepository settings = _freshInstall(
          writeError: StateError('The appearance could not be saved.'),
        );
        await _pumpApp(tester, layout, settings);
        expect(find.byType(OnboardingFrame), findsOneWidget, reason: name);
        expect(find.text(_failure), findsNothing, reason: name);

        await _tapToggle(tester, _onboardingToggle(layout.layout));

        expect(find.text(_failure), findsOneWidget, reason: name);
        expect(settings.appearanceWrites, isEmpty, reason: name);
        expect(_app(tester).themeMode, ThemeMode.light, reason: name);
        await tester.pump(const Duration(seconds: 3));
        await _unmount(tester);
      });
    }
  });
}
