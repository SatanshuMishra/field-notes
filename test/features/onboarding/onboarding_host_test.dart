import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/onboarding/chapters/day_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/moment_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/month_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/opening_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/reminder_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/theme_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/tour_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/week_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/year_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/today/today_screen.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';
import '../settings/support/fake_settings_repository.dart';
import '../settings/support/recording_reminder_scheduler.dart';

const Size _sidebarSurface = Size(1280, 800);
const Size _bottomBarSurface = Size(360, 740);

const String _openingTitle = "Most days won't feel like a story.";

const List<Type> _chapterTypes = <Type>[
  OpeningChapter,
  DayChapter,
  MomentChapter,
  MonthChapter,
  YearChapter,
  ThemeChapter,
  ReminderChapter,
  WeekChapter,
  TourChapter,
];

const List<String> _sidebarControls = <String>[
  'rail-today',
  'rail-calendar',
  'rail-garden',
  'rail-search',
  'settings-button',
  'sound-button',
];

const List<String> _bottomBarControls = <String>[
  'tab-today',
  'tab-calendar',
  'tab-garden',
  'tab-search',
  'capture-button',
  'gear-button',
];

const AppSettings _onboarded = AppSettings(
  reminderEnabled: true,
  reminderTime: ReminderTime.defaultTime,
  soundEnabled: true,
  textSize: TextSize.medium,
  weekStart: WeekStart.sunday,
  spellCheckEnabled: false,
  notificationPermissionAsked: true,
  reflectionPromptsEnabled: false,
  onboardingStatus: OnboardingStatus.done,
  appearance: Appearance.light,
);

Future<void> _onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
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
  ];
}

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required Size surface,
  required FakeSettingsRepository settings,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(settings),
      child: const FieldNotesApp(),
    ),
  );
  await _settle(tester);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppShell)));

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

bool _hitTestable(WidgetTester tester, Finder finder) {
  final RenderObject target = tester.renderObject(finder);
  final HitTestResult result = tester.hitTestOnBinding(
    tester.getCenter(finder),
  );
  return result.path.any(
    (HitTestEntry entry) => identical(entry.target, target),
  );
}

List<FocusNode> _focusNodesIn(
  WidgetTester tester,
  Finder finder,
) => <FocusNode>[
  for (final Element element
      in find.descendant(of: finder, matching: find.byType(Focus)).evaluate())
    (element.widget as Focus).focusNode ?? Focus.of(element),
];

Finder _absorbing(Finder of) => find.ancestor(
  of: of,
  matching: find.byWidgetPredicate(
    (Widget widget) => widget is AbsorbPointer && widget.absorbing,
    description: 'an absorbing AbsorbPointer',
  ),
);

Finder _excludingFocus(Finder of) => find.ancestor(
  of: of,
  matching: find.byWidgetPredicate(
    (Widget widget) => widget is ExcludeFocus && widget.excluding,
    description: 'an excluding ExcludeFocus',
  ),
);

Future<void> _expectAppUnreachable(
  WidgetTester tester,
  List<String> controls,
) async {
  for (final String key in controls) {
    final Finder control = find.byKey(ValueKey<String>(key));
    expect(control, findsOneWidget, reason: key);
    expect(_hitTestable(tester, control), isFalse, reason: key);
    expect(_absorbing(control), findsWidgets, reason: key);
    expect(_excludingFocus(control), findsWidgets, reason: key);
    final List<FocusNode> nodes = _focusNodesIn(tester, control);
    expect(nodes, isNotEmpty, reason: key);
    for (final FocusNode node in nodes) {
      expect(node.canRequestFocus, isFalse, reason: key);
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isFalse, reason: key);
    }
  }
}

void _expectOpening() {
  expect(find.byType(OnboardingFrame), findsOneWidget);
  expect(find.byType(OpeningChapter), findsOneWidget);
  expect(find.text(_openingTitle), findsOneWidget);
}

void _expectNoOnboarding() {
  expect(find.byType(OnboardingFrame), findsNothing);
  for (final Type chapter in _chapterTypes) {
    expect(find.byType(chapter), findsNothing, reason: '$chapter');
  }
}

void main() {
  testWidgets(
    'a fresh install opens on the Opening chapter with the app hidden, on both layouts',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        final List<String> calls = _recordWindowCalls(tester);
        final FakeSettingsRepository settings = FakeSettingsRepository(
          storedValues: false,
        );
        await _pumpApp(tester, surface: _sidebarSurface, settings: settings);

        _expectOpening();
        expect(settings.onboardingStatusWrites, <OnboardingStatus>[
          OnboardingStatus.pending,
        ]);
        expect(
          tester.getRect(find.byType(OnboardingFrame)),
          const Rect.fromLTRB(0, shellTitleBarHeight, 1280, 800),
        );
        expect(
          _container(tester).read(shellNavigationProvider),
          ShellDestination.today,
        );
        await _expectAppUnreachable(tester, _sidebarControls);

        final Finder titleBar = find.byKey(windowTitleBarKey);
        expect(titleBar, findsOneWidget);
        expect(
          tester.getRect(titleBar),
          const Rect.fromLTRB(0, 0, 1280, shellTitleBarHeight),
        );
        expect(_hitTestable(tester, titleBar), isTrue);
        expect(_absorbing(titleBar), findsNothing);
        expect(_excludingFocus(titleBar), findsNothing);
        expect(
          find.descendant(
            of: titleBar,
            matching: find.byWidgetPredicate(
              (Widget widget) => widget is ExcludeSemantics && widget.excluding,
            ),
          ),
          findsNothing,
        );

        await tester.drag(titleBar, const Offset(60, 0));
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          calls.where((String method) => method == startDragMethod),
          hasLength(1),
        );

        await tester.tap(titleBar);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(titleBar);
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          calls.where((String method) => method == titlebarDoubleClickMethod),
          hasLength(1),
        );
        _expectOpening();
      });

      await _onPlatform(TargetPlatform.android, () async {
        await _pumpApp(
          tester,
          surface: _bottomBarSurface,
          settings: FakeSettingsRepository(storedValues: false),
        );

        _expectOpening();
        expect(find.byKey(windowTitleBarKey), findsNothing);
        expect(
          tester.getRect(find.byType(OnboardingFrame)),
          Offset.zero & _bottomBarSurface,
        );
        await _expectAppUnreachable(tester, _bottomBarControls);
        _expectOpening();
      });
    },
  );

  testWidgets('an onboarded user opens on Today with no onboarding', (
    WidgetTester tester,
  ) async {
    for (final (TargetPlatform platform, Size surface)
        in <(TargetPlatform, Size)>[
          (TargetPlatform.macOS, _sidebarSurface),
          (TargetPlatform.android, _bottomBarSurface),
        ]) {
      await _onPlatform(platform, () async {
        final FakeSettingsRepository settings = FakeSettingsRepository(
          initial: _onboarded,
        );
        await _pumpApp(tester, surface: surface, settings: settings);

        expect(find.byType(TodayScreen), findsOneWidget, reason: '$platform');
        _expectNoOnboarding();
        expect(
          _container(tester).read(onboardingControllerProvider),
          const OnboardingFlowHidden(),
        );
        expect(settings.onboardingStatusWrites, isEmpty);
      });
    }
  });

  testWidgets('starting from the tour records done and leaves Today showing', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.macOS, () async {
      final FakeSettingsRepository settings = FakeSettingsRepository(
        storedValues: false,
      );
      await _pumpApp(tester, surface: _sidebarSurface, settings: settings);
      final OnboardingController controller = _container(tester)
          .read(onboardingControllerProvider.notifier);

      controller
        ..skipToSetup()
        ..next()
        ..next();
      await _settle(tester);
      controller.next();
      await _settle(tester);
      expect(find.byType(TourChapter), findsOneWidget);

      await tester.tap(find.text('Start journaling'));
      await _settle(tester);

      _expectNoOnboarding();
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(settings.onboardingStatusWrites, <OnboardingStatus>[
        OnboardingStatus.pending,
        OnboardingStatus.done,
      ]);
      expect(
        _container(tester).read(shellNavigationProvider),
        ShellDestination.today,
      );
      expect(
        _hitTestable(
          tester,
          find.byKey(const ValueKey<String>('rail-calendar')),
        ),
        isTrue,
      );
    });
  });
}
