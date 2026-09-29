import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/today/today_screen.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';
import '../settings/support/fake_settings_repository.dart';
import '../settings/support/recording_reminder_scheduler.dart';

const Size _sidebarSurface = Size(1280, 800);
const Size _bottomBarSurface = Size(360, 740);

const String _welcomeHeadline = 'A journal of days.';
const String _beginLabel = 'Let’s begin';
const String _skipTourLabel = 'Skip how it works';
const String _appearanceTitle = 'Light or dark?';
const String _reminderTitle = 'A gentle daily nudge?';
const String _weekTitle = 'Your week starts on';
const String _storageTitle = 'Where should entries live?';
const String _summaryTitle = 'You’re all set';
const String _finishedToast = 'All set. Plant your first bloom.';
const String _skippedToast = 'Defaults applied · change them in Settings';

const List<String> _tipTitles = <String>[
  'Four pages, one journal',
  'Plant a bloom each day',
  'Capture a moment',
  'What a note can hold',
  'Past days stay open',
  'Settings live here',
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

class _Run {
  _Run({required this.settings, required this.scheduler});

  final FakeSettingsRepository settings;
  final RecordingReminderScheduler scheduler;
}

Finder get _tourCard => find.byKey(tourCardKey);

Finder get _welcome => find.text(_welcomeHeadline);

Finder get _appearance => find.byType(OnboardingAppearance);

Finder _tipTitle(int index) =>
    find.descendant(of: _tourCard, matching: find.text(_tipTitles[index]));

Finder _nextReading(String label) =>
    find.descendant(of: find.byKey(tourNextKey), matching: find.text(label));

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

List<Override> _overrides(_Run run) {
  final Set<Object> replaced = <Object>{
    settingsRepositoryProvider,
    reminderSchedulerProvider,
  };
  return <Override>[
    for (final Override override in shellOverrides())
      if (!replaced.contains(override.origin)) override,
    settingsRepositoryProvider.overrideWithValue(run.settings),
    reminderSchedulerProvider.overrideWithValue(run.scheduler),
  ];
}

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<_Run> _pumpApp(
  WidgetTester tester, {
  required Size surface,
  FakeSettingsRepository? settings,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _Run run = _Run(
    settings: settings ?? FakeSettingsRepository(storedValues: false),
    scheduler: RecordingReminderScheduler(),
  );
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(run),
      child: const FieldNotesApp(),
    ),
  );
  await _settle(tester);
  return run;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppShell)));

ShellDestination _destination(WidgetTester tester) =>
    _container(tester).read(shellNavigationProvider);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _tapKey(WidgetTester tester, Key key) =>
    _tap(tester, find.byKey(key));

OnboardingFlow _flow(WidgetTester tester) =>
    _container(tester).read(onboardingControllerProvider);

Future<void> _continueFromAppearance(WidgetTester tester) async {
  expect(find.text(_appearanceTitle), findsOneWidget);
  await _tapKey(tester, onboardingAppearanceContinueKey);
  expect(_appearance, findsNothing);
}

Future<void> _walkTourToLastTip(WidgetTester tester) async {
  for (int tip = 0; tip < _tipTitles.length - 1; tip++) {
    expect(_tipTitle(tip), findsOneWidget);
    await _tapKey(tester, tourNextKey);
  }
  expect(_tipTitle(_tipTitles.length - 1), findsOneWidget);
}

Future<void> _walkSetupToEnd(WidgetTester tester) async {
  expect(find.text(_reminderTitle), findsOneWidget);
  await _tapKey(tester, setupPrimaryKey);
  expect(find.text(_weekTitle), findsOneWidget);
  await _tapKey(tester, setupPrimaryKey);
  expect(find.text(_storageTitle), findsOneWidget);
  await _tapKey(tester, setupPrimaryKey);
  expect(find.text(_summaryTitle), findsOneWidget);
  await _tapKey(tester, setupPrimaryKey);
}

void _expectNoOnboarding() {
  expect(_welcome, findsNothing);
  expect(_tourCard, findsNothing);
  expect(find.byType(OnboardingWelcome), findsNothing);
  expect(find.byType(OnboardingTour), findsNothing);
  expect(find.byType(OnboardingSetup), findsNothing);
  expect(_appearance, findsNothing);
}

void _expectFocusOutsideApp() {
  final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
  expect(focused, isNotNull);
  expect(focused!.findAncestorWidgetOfExactType<AppShell>(), isNull);
}

Future<void> _tabAround(WidgetTester tester) async {
  for (int press = 0; press < 8; press++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    _expectFocusOutsideApp();
  }
}

void main() {
  testWidgets(
    'a fresh install runs welcome, tour over Today, setup, then the app with the finish toast',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        final _Run run = await _pumpApp(tester, surface: _sidebarSurface);

        expect(find.byType(SidebarShell), findsOneWidget);
        expect(_welcome, findsOneWidget);
        expect(find.byKey(onboardingCardKey), findsOneWidget);
        expect(find.byType(TodayScreen), findsOneWidget);
        expect(run.settings.onboardingStatusWrites, <OnboardingStatus>[
          OnboardingStatus.pending,
        ]);

        await _tap(tester, find.text(_beginLabel));
        await _continueFromAppearance(tester);

        expect(_welcome, findsNothing);
        expect(_destination(tester), ShellDestination.today);
        expect(find.byType(TodayScreen), findsOneWidget);
        await _walkTourToLastTip(tester);
        expect(_nextReading('Set up'), findsOneWidget);
        await _tapKey(tester, tourNextKey);

        expect(_tourCard, findsNothing);
        await _walkSetupToEnd(tester);

        expect(find.text(_finishedToast), findsOneWidget);
        _expectNoOnboarding();
        expect(find.byType(TodayScreen), findsOneWidget);
        expect(_destination(tester), ShellDestination.today);
        expect(run.settings.onboardingStatusWrites.last, OnboardingStatus.done);
      });
    },
  );

  testWidgets('finishing writes done and onboarding never returns', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.android, () async {
      final _Run run = await _pumpApp(tester, surface: _bottomBarSurface);

      expect(_welcome, findsOneWidget);
      await _tap(tester, find.text(_beginLabel));
      await _continueFromAppearance(tester);
      await _walkTourToLastTip(tester);
      await _tapKey(tester, tourNextKey);
      await _walkSetupToEnd(tester);

      expect(run.settings.onboardingStatusWrites, <OnboardingStatus>[
        OnboardingStatus.pending,
        OnboardingStatus.done,
      ]);
      await tester.pump(const Duration(seconds: 3));
      _expectNoOnboarding();

      final _Run relaunch = await _pumpApp(
        tester,
        surface: _bottomBarSurface,
        settings: FakeSettingsRepository(
          initial: AppSettings.defaults.copyWith(
            onboardingStatus: OnboardingStatus.done,
          ),
          storedValues: false,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      _expectNoOnboarding();
      expect(find.byKey(onboardingPageKey), findsNothing);
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(relaunch.settings.onboardingStatusWrites, isEmpty);
    });
  });

  testWidgets(
    'the app underneath ignores taps and keys while onboarding shows',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        await _pumpApp(tester, surface: _sidebarSurface);
        final Finder calendar = find.byKey(
          const ValueKey<String>('rail-calendar'),
        );

        final FocusNode calendarFocus = Focus.of(
          tester.element(
            find
                .descendant(
                  of: calendar,
                  matching: find.byType(ExcludeSemantics),
                )
                .first,
          ),
        );

        expect(_welcome, findsOneWidget);
        await tester.tapAt(tester.getCenter(calendar));
        await _settle(tester);
        expect(_destination(tester), ShellDestination.today);
        expect(_welcome, findsOneWidget);
        await _tabAround(tester);
        expect(_destination(tester), ShellDestination.today);
        calendarFocus.requestFocus();
        await tester.pump();
        expect(calendarFocus.hasFocus, isFalse);
        _expectFocusOutsideApp();

        await _tap(tester, find.text(_beginLabel));
        await _continueFromAppearance(tester);
        expect(_tipTitle(0), findsOneWidget);
        await tester.tapAt(tester.getCenter(calendar));
        await _settle(tester);
        expect(_destination(tester), ShellDestination.today);
        expect(_tipTitle(0), findsOneWidget);
        calendarFocus.requestFocus();
        await tester.pump();
        expect(calendarFocus.hasFocus, isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await _settle(tester);
        expect(_destination(tester), ShellDestination.today);
        expect(_tipTitle(1), findsOneWidget);
        await _tabAround(tester);
        expect(_destination(tester), ShellDestination.today);
        expect(_tourCard, findsOneWidget);
      });
    },
  );

  testWidgets(
    'skipping setup closes with the defaults toast and then asks for notification permission once',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.android, () async {
        final _Run run = await _pumpApp(tester, surface: _bottomBarSurface);

        await _tap(tester, find.text(_skipTourLabel));
        await _continueFromAppearance(tester);
        expect(find.text(_reminderTitle), findsOneWidget);
        expect(run.scheduler.permissionRequests, 0);

        await _tapKey(tester, setupSkipKey);

        expect(find.text(_skippedToast), findsOneWidget);
        _expectNoOnboarding();
        expect(run.settings.reminderEnabledWrites, <bool>[true]);
        expect(run.settings.reminderTimeWrites, <ReminderTime>[
          ReminderTime.defaultTime,
        ]);
        expect(run.settings.weekStartWrites, <WeekStart>[WeekStart.monday]);
        expect(run.settings.onboardingStatusWrites.last, OnboardingStatus.done);
        expect(run.scheduler.permissionRequests, 1);

        await tester.pump(const Duration(seconds: 3));
        await _settle(tester);
        expect(run.scheduler.permissionRequests, 1);
        expect(run.settings.notificationPermissionAskedWrites, <bool>[true]);
      });
    },
  );

  testWidgets(
    'Back walks from setup and the first tip to Light or dark and then welcome',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        await _pumpApp(tester, surface: _sidebarSurface);

        await _tap(tester, find.text(_beginLabel));
        await _continueFromAppearance(tester);
        await _walkTourToLastTip(tester);
        await _tapKey(tester, tourNextKey);
        expect(find.text(_reminderTitle), findsOneWidget);

        await _tapKey(tester, setupBackKey);

        expect(find.text(_reminderTitle), findsNothing);
        expect(_tipTitle(_tipTitles.length - 1), findsOneWidget);
        expect(_nextReading('Set up'), findsOneWidget);

        for (int tip = _tipTitles.length - 1; tip > 0; tip--) {
          await _tapKey(tester, tourBackKey);
          expect(_tipTitle(tip - 1), findsOneWidget);
        }
        await _tapKey(tester, tourBackKey);

        expect(_tourCard, findsNothing);
        expect(_welcome, findsNothing);
        expect(find.text(_appearanceTitle), findsOneWidget);
        expect(
          _flow(tester),
          const OnboardingFlowAppearance(skippedTips: false),
        );

        await _tapKey(tester, onboardingAppearanceBackKey);

        expect(_appearance, findsNothing);
        expect(_welcome, findsOneWidget);

        await _tap(tester, find.text(_skipTourLabel));
        await _continueFromAppearance(tester);
        expect(find.text(_reminderTitle), findsOneWidget);

        await _tapKey(tester, setupBackKey);

        expect(find.text(_reminderTitle), findsNothing);
        expect(_tourCard, findsNothing);
        expect(find.text(_appearanceTitle), findsOneWidget);
        expect(
          _flow(tester),
          const OnboardingFlowAppearance(skippedTips: true),
        );

        await _tapKey(tester, onboardingAppearanceBackKey);

        expect(_appearance, findsNothing);
        expect(_welcome, findsOneWidget);
      });
    },
  );

  testWidgets(
    'Android system Back acts as the surface Back and does nothing on welcome',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.android, () async {
        await _pumpApp(tester, surface: _bottomBarSurface);

        await tester.binding.handlePopRoute();
        await _settle(tester);
        expect(_welcome, findsOneWidget);

        await _tap(tester, find.text(_beginLabel));
        await _continueFromAppearance(tester);
        await _tapKey(tester, tourNextKey);
        expect(_tipTitle(1), findsOneWidget);
        await tester.binding.handlePopRoute();
        await _settle(tester);
        expect(_tipTitle(0), findsOneWidget);
        await tester.binding.handlePopRoute();
        await _settle(tester);
        expect(_tourCard, findsNothing);
        expect(find.text(_appearanceTitle), findsOneWidget);
        await tester.binding.handlePopRoute();
        await _settle(tester);
        expect(_appearance, findsNothing);
        expect(_welcome, findsOneWidget);

        await _tap(tester, find.text(_beginLabel));
        await _continueFromAppearance(tester);
        await _walkTourToLastTip(tester);
        await _tapKey(tester, tourNextKey);
        await _tapKey(tester, setupPrimaryKey);
        expect(find.text(_weekTitle), findsOneWidget);
        await tester.binding.handlePopRoute();
        await _settle(tester);
        expect(find.text(_reminderTitle), findsOneWidget);
        await tester.binding.handlePopRoute();
        await _settle(tester);
        expect(find.text(_reminderTitle), findsNothing);
        expect(_tipTitle(_tipTitles.length - 1), findsOneWidget);
        expect(_destination(tester), ShellDestination.today);
      });
    },
  );

  testWidgets(
    'a platform other than macOS and Android runs onboarding in the bottom-bar layout',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.linux, () async {
        final _Run run = await _pumpApp(tester, surface: _bottomBarSurface);

        expect(find.byType(BottomBarShell), findsOneWidget);
        expect(_welcome, findsOneWidget);
        expect(find.byKey(onboardingCardKey), findsNothing);
        expect(
          tester.getRect(find.byKey(onboardingPageKey)),
          Offset.zero & _bottomBarSurface,
        );

        await _tap(tester, find.text(_beginLabel));
        await _continueFromAppearance(tester);

        expect(find.byKey(tourControlsKey), findsOneWidget);
        await _walkTourToLastTip(tester);
        await _tapKey(tester, tourNextKey);
        expect(
          tester.getRect(find.byKey(onboardingPageKey)),
          Offset.zero & _bottomBarSurface,
        );
        await _walkSetupToEnd(tester);

        expect(find.text(_finishedToast), findsOneWidget);
        _expectNoOnboarding();
        expect(run.settings.onboardingStatusWrites.last, OnboardingStatus.done);
      });
    },
  );

  testWidgets('an upgrade launch shows no onboarding', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.android, () async {
      final _Run run = await _pumpApp(
        tester,
        surface: _bottomBarSurface,
        settings: FakeSettingsRepository(),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(OnboardingHost), findsOneWidget);
      expect(
        _container(tester).read(onboardingControllerProvider),
        isA<OnboardingFlowHidden>(),
      );
      _expectNoOnboarding();
      expect(find.byKey(onboardingPageKey), findsNothing);
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(run.settings.onboardingStatusWrites, <OnboardingStatus>[
        OnboardingStatus.done,
      ]);
    });
  });

  testWidgets('replayTour switches to Today and runs the tour in replay mode', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.macOS, () async {
      final _Run run = await _pumpApp(
        tester,
        surface: _sidebarSurface,
        settings: FakeSettingsRepository(initial: _onboarded),
      );
      _expectNoOnboarding();
      _container(tester)
          .read(shellNavigationProvider.notifier)
          .select(ShellDestination.settings);
      await _settle(tester);
      expect(find.byType(TodayScreen), findsNothing);

      _container(
        tester,
      ).read(onboardingControllerProvider.notifier).replayTour();
      await _settle(tester);

      expect(_destination(tester), ShellDestination.today);
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(_welcome, findsNothing);
      await _walkTourToLastTip(tester);
      expect(_nextReading('Done'), findsOneWidget);
      await _tapKey(tester, tourNextKey);

      _expectNoOnboarding();
      expect(_destination(tester), ShellDestination.today);
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(run.settings.onboardingStatusWrites, isEmpty);
      expect(run.settings.reminderEnabledWrites, isEmpty);
      expect(run.settings.reminderTimeWrites, isEmpty);
      expect(run.settings.weekStartWrites, isEmpty);
      expect(run.settings.notificationPermissionAskedWrites, isEmpty);
      expect(run.settings.reflectionPromptsEnabledWrites, isEmpty);
      expect(run.settings.soundEnabledWrites, isEmpty);
      expect(run.settings.textSizeWrites, isEmpty);
      expect(run.settings.spellCheckEnabledWrites, isEmpty);
    });
  });

  testWidgets("Let's begin shows Light or dark, then the first tip", (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.macOS, () async {
      await _pumpApp(tester, surface: _sidebarSurface);
      expect(_welcome, findsOneWidget);

      await _tap(tester, find.text(_beginLabel));

      expect(_welcome, findsNothing);
      expect(_tourCard, findsNothing);
      expect(_appearance, findsOneWidget);
      expect(find.text(_appearanceTitle), findsOneWidget);
      expect(_flow(tester), const OnboardingFlowAppearance(skippedTips: false));
      expect(find.byType(TodayScreen), findsOneWidget);

      await _tapKey(tester, onboardingAppearanceContinueKey);

      expect(_appearance, findsNothing);
      expect(_tipTitle(0), findsOneWidget);
      expect(
        _flow(tester),
        const OnboardingFlowTour(tip: 0, mode: TourMode.firstRun),
      );
    });
  });

  testWidgets('Skip how it works shows Light or dark, then setup', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.android, () async {
      await _pumpApp(tester, surface: _bottomBarSurface);
      expect(_welcome, findsOneWidget);

      await _tap(tester, find.text(_skipTourLabel));

      expect(_welcome, findsNothing);
      expect(_appearance, findsOneWidget);
      expect(find.text(_appearanceTitle), findsOneWidget);
      expect(find.text(_reminderTitle), findsNothing);
      expect(_flow(tester), const OnboardingFlowAppearance(skippedTips: true));

      await _tapKey(tester, onboardingAppearanceContinueKey);

      expect(_appearance, findsNothing);
      expect(_tourCard, findsNothing);
      expect(find.byType(OnboardingSetup), findsOneWidget);
      expect(find.text(_reminderTitle), findsOneWidget);
    });
  });

  testWidgets('first run shows Light or dark but replaying the tour does not', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.macOS, () async {
      await _pumpApp(tester, surface: _sidebarSurface);
      await _tap(tester, find.text(_beginLabel));
      expect(find.text(_appearanceTitle), findsOneWidget);
      await _continueFromAppearance(tester);
      await _tapKey(tester, tourBackKey);
      expect(find.text(_appearanceTitle), findsOneWidget);

      await _pumpApp(
        tester,
        surface: _sidebarSurface,
        settings: FakeSettingsRepository(initial: _onboarded),
      );
      _expectNoOnboarding();

      _container(
        tester,
      ).read(onboardingControllerProvider.notifier).replayTour();
      await _settle(tester);

      expect(_tipTitle(0), findsOneWidget);
      expect(_appearance, findsNothing);
      _container(
        tester,
      ).read(onboardingControllerProvider.notifier).backFromTour();
      await _settle(tester);
      expect(_tipTitle(0), findsOneWidget);
      expect(_appearance, findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await _settle(tester);
      expect(_tipTitle(0), findsOneWidget);
      expect(_appearance, findsNothing);

      for (int tip = 0; tip < _tipTitles.length - 1; tip++) {
        expect(_appearance, findsNothing);
        await _tapKey(tester, tourNextKey);
      }
      expect(_nextReading('Done'), findsOneWidget);
      await _tapKey(tester, tourNextKey);

      _expectNoOnboarding();
      expect(find.text(_appearanceTitle), findsNothing);
    });
  });
}
