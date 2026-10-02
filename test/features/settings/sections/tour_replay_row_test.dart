import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/data/database/app_database.dart' as db;
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/onboarding/chapters/tour_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/settings/sections/journal_section.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../app/support/app_shell_harness.dart';
import '../../capture/core/capture_test_support.dart' show newTestDatabase;
import '../support/fake_settings_repository.dart';
import '../support/recording_reminder_scheduler.dart';
import '../support/settings_harness.dart';

const String _rowLabel = 'Show the tour again';
const String _rowDescription = 'A map of where everything lives.';
const String _showTour = 'Show tour';
const String _mapTitle = "Here's where everything lives.";

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

class _App {
  const _App({required this.database, required this.settings});

  final db.AppDatabase database;
  final FakeSettingsRepository settings;
}

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

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 300));
}

Future<_App> _pumpApp(WidgetTester tester, Size surface) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db.AppDatabase database = newTestDatabase();
  final FakeSettingsRepository settings = FakeSettingsRepository(
    initial: _onboarded,
  );
  final Set<Object> replaced = <Object>{
    journalRepositoryProvider,
    settingsRepositoryProvider,
    reminderSchedulerProvider,
  };
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        for (final Override override in shellOverrides())
          if (!replaced.contains(override.origin)) override,
        journalRepositoryProvider.overrideWithValue(
          DriftJournalRepository(database),
        ),
        settingsRepositoryProvider.overrideWithValue(settings),
        reminderSchedulerProvider.overrideWithValue(
          RecordingReminderScheduler(),
        ),
      ],
      child: const FieldNotesApp(),
    ),
  );
  await _settle(tester);
  return _App(database: database, settings: settings);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppShell)));

ShellDestination _selected(WidgetTester tester) =>
    _container(tester).read(shellNavigationProvider);

Finder get _done => find.descendant(
  of: find.byKey(onboardingPrimaryKey),
  matching: find.text('Done'),
);

Future<void> _openSettings(WidgetTester tester, String button) async {
  await tester.tap(find.byKey(ValueKey<String>(button)));
  await _settle(tester);
  expect(_selected(tester), ShellDestination.settings);
  await tester.tap(find.byKey(settingsTabKey(SettingsTab.journal)));
  await _settle(tester);
  await tester.ensureVisible(find.text(_rowLabel));
  await _settle(tester);
  expect(find.text(_rowDescription), findsOneWidget);
}

Future<void> _showMap(WidgetTester tester) async {
  await tester.ensureVisible(find.text(_showTour));
  await _settle(tester);
  await tester.tap(find.text(_showTour));
  await _settle(tester);
  expect(find.byType(TourChapter), findsOneWidget);
  expect(find.text(_mapTitle), findsOneWidget);
  expect(_done, findsOneWidget);
  expect(find.byKey(onboardingProgressKey), findsNothing);
  expect(find.byKey(onboardingSkipKey), findsNothing);
  expect(find.text('Skip to setup'), findsNothing);
  expect(
    _container(tester).read(onboardingControllerProvider),
    const OnboardingFlowMap(),
  );
}

void _expectBackOnSettings(WidgetTester tester) {
  expect(find.byType(TourChapter), findsNothing);
  expect(find.byType(OnboardingFrame), findsNothing);
  expect(_selected(tester), ShellDestination.settings);
  expect(find.byType(SettingsScreen), findsOneWidget);
  expect(find.text(_rowLabel), findsOneWidget);
}

Future<void> _expectNothingSaved(_App app) async {
  final db.AppDatabase database = app.database;
  expect(await database.select(database.days).get(), isEmpty);
  expect(await database.select(database.entries).get(), isEmpty);
  final FakeSettingsRepository settings = app.settings;
  expect(settings.reminderEnabledWrites, isEmpty);
  expect(settings.reminderTimeWrites, isEmpty);
  expect(settings.soundEnabledWrites, isEmpty);
  expect(settings.textSizeWrites, isEmpty);
  expect(settings.weekStartWrites, isEmpty);
  expect(settings.spellCheckEnabledWrites, isEmpty);
  expect(settings.notificationPermissionAskedWrites, isEmpty);
  expect(settings.reflectionPromptsEnabledWrites, isEmpty);
  expect(settings.onboardingStatusWrites, isEmpty);
  expect(settings.appearanceWrites, isEmpty);
}

Future<void> _unmount(WidgetTester tester, _App app) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await app.database.close();
}

void main() {
  testWidgets('Journal shows Show the tour again with a Show tour button', (
    WidgetTester tester,
  ) async {
    useWideSurface(tester);
    await tester.pumpWidget(
      settingsFeatureHarness(
        JournalSection(
          settings: AppSettings.defaults,
          onFeedback: (String message) {},
        ),
        overrides: <Override>[
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(_rowLabel), findsOneWidget);
    expect(find.text(_rowDescription), findsOneWidget);
    expect(find.text('Six quick tips about the app.'), findsNothing);
    expect(find.text(_showTour), findsOneWidget);
  });

  testWidgets(
    'show the tour again opens the map chapter and Done or back returns to Settings',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        final _App app = await _pumpApp(tester, const Size(1280, 900));
        await _openSettings(tester, 'settings-button');

        await _showMap(tester);
        await tester.tap(_done);
        await _settle(tester);
        _expectBackOnSettings(tester);

        for (final LogicalKeyboardKey key in <LogicalKeyboardKey>[
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.arrowRight,
          LogicalKeyboardKey.arrowLeft,
        ]) {
          await _showMap(tester);
          await tester.sendKeyEvent(key);
          await _settle(tester);
          _expectBackOnSettings(tester);
        }

        await _expectNothingSaved(app);
        await _unmount(tester, app);
      });

      await _onPlatform(TargetPlatform.android, () async {
        final _App app = await _pumpApp(tester, const Size(360, 740));
        await _openSettings(tester, 'gear-button');

        await _showMap(tester);
        await tester.binding.handlePopRoute();
        await _settle(tester);
        _expectBackOnSettings(tester);

        await _showMap(tester);
        await tester.tap(_done);
        await _settle(tester);
        _expectBackOnSettings(tester);

        await tester.binding.handlePopRoute();
        await _settle(tester);
        expect(_selected(tester), ShellDestination.today);

        await _expectNothingSaved(app);
        await _unmount(tester, app);
      });
    },
  );
}
