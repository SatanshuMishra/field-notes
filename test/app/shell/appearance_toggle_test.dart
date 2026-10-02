import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/appearance_toggle.dart';
import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
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
const int _maxTabs = 80;
const String _failure = 'Could not save your appearance.';
const Key _gearKey = ValueKey<String>('gear-button');

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

FakeSettingsRepository _freshInstall() =>
    FakeSettingsRepository(storedValues: false);

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

Finder _onboardingToggle(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => _anyToggle,
  ShellLayout.bottomBar => _frameToggle,
};

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

bool _focusedWithin(Finder toggle) {
  final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
  return focused != null &&
      find
          .descendant(
            of: toggle,
            matching: find.byElementPredicate(
              (Element element) => identical(element, focused),
            ),
          )
          .evaluate()
          .isNotEmpty;
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

void _expectInTheBar(WidgetTester tester, _Layout layout, Finder toggle) {
  final String reason = layout.layout.name;
  final Rect target = tester.getRect(toggle);
  switch (layout.layout) {
    case ShellLayout.sidebar:
      final Rect bar = tester.getRect(find.byKey(windowTitleBarKey));
      expect(target.top, bar.top, reason: reason);
      expect(target.height, shellTitleBarHeight, reason: reason);
      expect(target.width, kMinInteractiveDimension, reason: reason);
      expect(target.right, bar.right - shellTitleBarPadding, reason: reason);
    case ShellLayout.bottomBar:
      expect(
        find.descendant(of: find.byType(BottomBarShell), matching: toggle),
        findsOneWidget,
        reason: reason,
      );
      final Rect gear = tester.getRect(find.byKey(_gearKey));
      expect(
        target.size,
        const Size.square(kMinInteractiveDimension),
        reason: reason,
      );
      expect(target.right, gear.left, reason: reason);
      expect(target.center.dy, gear.center.dy, reason: reason);
      expect(target.top, greaterThanOrEqualTo(_statusBar), reason: reason);
  }
  expect(_hitTestable(tester, toggle), isTrue, reason: reason);
}

Future<void> _expectFocusRing(WidgetTester tester, Finder toggle) async {
  final FocusHighlightStrategy previous =
      FocusManager.instance.highlightStrategy;
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = previous);
  final Finder ring = find.descendant(
    of: toggle,
    matching: find.byKey(focusRingKey),
  );
  expect(ring, findsNothing);
  for (int press = 0; press < _maxTabs && !_focusedWithin(toggle); press++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  expect(_focusedWithin(toggle), isTrue, reason: 'Tab never reached it');
  expect(ring, findsOneWidget);
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
  expect(_hitTestable(tester, toggle), isTrue, reason: reason);
  switch (layout.layout) {
    case ShellLayout.sidebar:
      expect(_frameToggle, findsNothing, reason: reason);
      expect(
        tester.getRect(toggle).bottom,
        lessThanOrEqualTo(shellTitleBarHeight),
        reason: reason,
      );
    case ShellLayout.bottomBar:
      final Rect target = tester.getRect(toggle);
      expect(target.top, greaterThanOrEqualTo(_statusBar), reason: reason);
      expect(
        target.right,
        greaterThan(layout.surface.width - kMinInteractiveDimension),
        reason: reason,
      );
      expect(
        target.size,
        const Size.square(kMinInteractiveDimension),
        reason: reason,
      );
  }
}

Future<void> _flipsAfterOnboarding(WidgetTester tester, _Layout layout) async {
  final String name = layout.layout.name;
  final FakeSettingsRepository settings = _onboarded(Appearance.light);
  await _pumpApp(tester, layout, settings);
  expect(find.byType(OnboardingFrame), findsNothing, reason: name);
  expect(_anyToggle, findsOneWidget, reason: name);
  _expectInTheBar(tester, layout, _anyToggle);
  _expectShowing(tester, _anyToggle, Brightness.light, reason: '$name light');

  await _tapToggle(tester, _anyToggle);
  expect(settings.appearanceWrites, <Appearance>[Appearance.dark]);
  expect(_app(tester).themeMode, ThemeMode.dark, reason: name);
  _expectShowing(tester, _anyToggle, Brightness.dark, reason: '$name dark');

  await _tapToggle(tester, _anyToggle);
  expect(settings.appearanceWrites, <Appearance>[
    Appearance.dark,
    Appearance.light,
  ]);
  expect(_app(tester).themeMode, ThemeMode.light, reason: name);
  _expectShowing(tester, _anyToggle, Brightness.light, reason: '$name back');

  if (layout.layout == ShellLayout.sidebar) {
    await _expectFocusRing(tester, _anyToggle);
  }
  await _unmount(tester);
}

Future<void> _flipsSystemOnADarkDevice(
  WidgetTester tester,
  _Layout layout,
) async {
  final String name = '${layout.layout.name} system';
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  final FakeSettingsRepository settings = _onboarded(Appearance.system);
  await _pumpApp(tester, layout, settings);
  expect(_app(tester).themeMode, ThemeMode.system, reason: name);
  _expectShowing(tester, _anyToggle, Brightness.dark, reason: name);

  await _tapToggle(tester, _anyToggle);
  expect(settings.appearanceWrites, <Appearance>[Appearance.light]);
  expect(_app(tester).themeMode, ThemeMode.light, reason: name);
  _expectShowing(tester, _anyToggle, Brightness.light, reason: name);
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
    if (layout.layout == ShellLayout.bottomBar) {
      final Color ink = chapter == OnboardingChapter.year
          ? FieldNotesColors.light.composerPaper
          : FieldNotesColors.of(tester.element(toggle)).ink;
      expect(
        find.descendant(
          of: toggle,
          matching: find.byKey(appearanceToggleSunKey),
        ),
        paints..circle(color: ink),
        reason: reason,
      );
    }
  }
  expect(settings.appearanceWrites, <Appearance>[Appearance.dark]);
  await _unmount(tester);
}

Future<void> _worksOnTheMap(WidgetTester tester, _Layout layout) async {
  final String name = '${layout.layout.name} map';
  final FakeSettingsRepository settings = _onboarded(Appearance.light);
  final ProviderContainer container = await _pumpApp(tester, layout, settings);
  container.read(onboardingControllerProvider.notifier).showMap();
  await _settle(tester);
  expect(
    container.read(onboardingControllerProvider),
    const OnboardingFlowMap(),
  );
  _expectReachableDuringOnboarding(tester, layout, reason: name);
  final Finder toggle = _onboardingToggle(layout.layout);
  _expectShowing(tester, toggle, Brightness.light, reason: name);

  await _tapToggle(tester, toggle);
  expect(settings.appearanceWrites, <Appearance>[Appearance.dark]);
  _expectShowing(tester, toggle, Brightness.dark, reason: name);
  expect(
    container.read(onboardingControllerProvider),
    const OnboardingFlowMap(),
    reason: name,
  );
  await _unmount(tester);
}

void main() {
  testWidgets(
    'the toggle flips what is showing, saves it and works during onboarding',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      _onDevice(tester, Brightness.light);
      for (final _Layout layout in _layouts) {
        await _onLayout(layout, () async {
          await _flipsAfterOnboarding(tester, layout);
          await _flipsSystemOnADarkDevice(tester, layout);
          await _worksThroughOnboarding(tester, layout);
          await _worksOnTheMap(tester, layout);
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
        final FakeSettingsRepository settings = FakeSettingsRepository(
          initial: _onboardedWith(Appearance.light),
          writeError: StateError('The appearance could not be saved.'),
        );
        await _pumpApp(tester, layout, settings);
        expect(find.text(_failure), findsNothing, reason: name);

        await _tapToggle(tester, _anyToggle);

        expect(find.text(_failure), findsOneWidget, reason: name);
        expect(settings.appearanceWrites, isEmpty, reason: name);
        expect(_app(tester).themeMode, ThemeMode.light, reason: name);
        await tester.pump(const Duration(seconds: 3));
        await _unmount(tester);
      });
    }
  });
}
