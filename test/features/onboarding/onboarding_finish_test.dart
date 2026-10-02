import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/data/database/app_database.dart' as db;
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/mood/mood_banner.dart';
import 'package:field_notes/features/onboarding/chapters/tour_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/reminders/reminder_scheduler.dart';
import 'package:field_notes/features/sound/sound_providers.dart';
import 'package:field_notes/features/today/today_entry_feed.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/features/today/today_screen.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart' show shellOverrides;
import '../capture/core/capture_test_support.dart'
    show FakeDraftStore, newTestDatabase;
import '../notes/support/notes_harness.dart'
    show FakeNoteMediaResolver, FakeNoteMediaStore;
import '../settings/support/fake_settings_repository.dart';
import '../settings/support/recording_reminder_scheduler.dart';
import '../sound/support/fake_sound_player.dart';

const String _today = '2026-10-01';
const String _toast = 'Your meadow starts today.';
const String _finishError = "Couldn't save your choices. Try again.";
const String _firstLine = 'The fog lifted over the harbour';
const String _finalLine = 'The fog lifted over the harbour before noon';

const Duration _pause = Duration(milliseconds: 600);

const ReminderTime _morning = ReminderTime(hour: 8, minute: 0);
const ReminderTime _midday = ReminderTime(hour: 12, minute: 30);
const ReminderTime _evening = ReminderTime(hour: 20, minute: 30);

final DateTime _now = DateTime(2026, 10, 1, 9, 30);

typedef _Layout = ({
  String name,
  TargetPlatform platform,
  Size surface,
  String start,
});

const List<_Layout> _layouts = <_Layout>[
  (
    name: 'sidebar',
    platform: TargetPlatform.macOS,
    surface: Size(1280, 1400),
    start: 'Start journaling',
  ),
  (
    name: 'bottom bar',
    platform: TargetPlatform.android,
    surface: Size(412, 1400),
    start: 'Start',
  ),
];

class _StoredSettings extends FakeSettingsRepository {
  _StoredSettings() : super(storedValues: false);

  bool failReminderEnabled = false;
  bool failOnboardingStatus = false;

  Future<void> _store(AppSettings Function(AppSettings stored) change) async {
    emit(change(await load()));
  }

  @override
  Future<void> setReminderEnabled(bool value) async {
    if (failReminderEnabled) {
      throw StateError('disk full');
    }
    await super.setReminderEnabled(value);
    await _store(
      (AppSettings stored) => stored.copyWith(reminderEnabled: value),
    );
  }

  @override
  Future<void> setReminderTime(ReminderTime value) async {
    await super.setReminderTime(value);
    await _store((AppSettings stored) => stored.copyWith(reminderTime: value));
  }

  @override
  Future<void> setWeekStart(WeekStart value) async {
    await super.setWeekStart(value);
    await _store((AppSettings stored) => stored.copyWith(weekStart: value));
  }

  @override
  Future<void> setNotificationPermissionAsked(bool value) async {
    await super.setNotificationPermissionAsked(value);
    await _store(
      (AppSettings stored) =>
          stored.copyWith(notificationPermissionAsked: value),
    );
  }

  @override
  Future<void> setOnboardingStatus(OnboardingStatus value) async {
    if (failOnboardingStatus) {
      throw StateError('disk full');
    }
    await super.setOnboardingStatus(value);
    await _store(
      (AppSettings stored) => stored.copyWith(onboardingStatus: value),
    );
  }
}

Future<void> _onLayout(_Layout layout, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = layout.platform;
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

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (int attempt = 0; attempt < 50 && !done(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

Future<ProviderContainer> _launch(
  WidgetTester tester,
  _Layout layout, {
  required FakeSettingsRepository settings,
  required ReminderScheduler scheduler,
  JournalRepository? journal,
}) async {
  tester.view.physicalSize = layout.surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final Set<Object> replaced = <Object>{
    settingsRepositoryProvider,
    reminderSchedulerProvider,
    if (journal != null) journalRepositoryProvider,
  };
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        for (final Override override in shellOverrides())
          if (!replaced.contains(override.origin)) override,
        settingsRepositoryProvider.overrideWithValue(settings),
        reminderSchedulerProvider.overrideWithValue(scheduler),
        if (journal case final JournalRepository real)
          journalRepositoryProvider.overrideWithValue(real),
        onboardingCountryCodeProvider.overrideWithValue('US'),
        todayClockProvider.overrideWithValue(() => _now),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        mediaStoreProvider.overrideWith(
          (Ref ref) async => FakeNoteMediaStore(),
        ),
        todayMediaResolverProvider.overrideWith(
          (Ref ref) async => FakeNoteMediaResolver(),
        ),
        soundPlayerProvider.overrideWithValue(FakeSoundPlayer()),
      ],
      child: const FieldNotesApp(),
    ),
  );
  await _until(
    tester,
    () => find.byType(OnboardingFrame).evaluate().isNotEmpty,
  );
  await _settle(tester);
  expect(find.byType(OnboardingFrame), findsOneWidget, reason: layout.name);
  return ProviderScope.containerOf(tester.element(find.byType(AppShell)));
}

Future<void> _close(WidgetTester tester, db.AppDatabase? database) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await database?.close();
}

OnboardingController _controller(ProviderContainer container) =>
    container.read(onboardingControllerProvider.notifier);

Future<void> _walkToTour(
  WidgetTester tester,
  ProviderContainer container, {
  required ReminderChoice reminder,
  required WeekStart week,
}) async {
  _controller(container)
    ..skipToSetup()
    ..next()
    ..chooseReminder(reminder)
    ..next()
    ..chooseWeek(week)
    ..next();
  await _settle(tester);
  expect(find.byType(TourChapter), findsOneWidget);
}

Finder _start(_Layout layout) => find.descendant(
  of: find.byKey(onboardingPrimaryKey),
  matching: find.text(layout.start),
);

Future<void> _pressStart(WidgetTester tester, _Layout layout) async {
  expect(_start(layout), findsOneWidget, reason: layout.name);
  await tester.tap(_start(layout));
  await _settle(tester);
}

void _expectToday(
  WidgetTester tester,
  ProviderContainer container, {
  required String reason,
}) {
  expect(find.byType(OnboardingFrame), findsNothing, reason: reason);
  expect(find.byType(TodayScreen), findsOneWidget, reason: reason);
  expect(
    container.read(onboardingControllerProvider),
    const OnboardingFlowHidden(),
    reason: reason,
  );
  expect(
    container.read(shellNavigationProvider),
    ShellDestination.today,
    reason: reason,
  );
  expect(
    container.read(onboardingGateProvider).value,
    OnboardingVisibility.hidden,
    reason: reason,
  );
  expect(find.text(_toast), findsOneWidget, reason: reason);
}

void _expectStillOnTour(
  WidgetTester tester,
  ProviderContainer container,
  _Layout layout,
  FakeSettingsRepository settings, {
  required String reason,
}) {
  expect(find.byType(TourChapter), findsOneWidget, reason: reason);
  expect(
    container.read(onboardingControllerProvider),
    isA<OnboardingFlowRunning>().having(
      (OnboardingFlowRunning flow) => flow.chapter,
      'chapter',
      OnboardingChapter.tour,
    ),
    reason: reason,
  );
  final Finder error = find.text(_finishError);
  expect(error, findsOneWidget, reason: reason);
  expect(
    tester.getRect(error).bottom,
    lessThanOrEqualTo(tester.getRect(find.byKey(onboardingPrimaryKey)).top),
    reason: reason,
  );
  expect(_start(layout), findsOneWidget, reason: reason);
  expect(settings.onboardingStatusWrites, <OnboardingStatus>[
    OnboardingStatus.pending,
  ], reason: reason);
  expect(
    container.read(onboardingGateProvider).value,
    OnboardingVisibility.shown,
    reason: reason,
  );
  expect(find.text(_toast), findsNothing, reason: reason);
}

List<TodayEntryTile> _tiles(WidgetTester tester) =>
    tester.widgetList<TodayEntryTile>(find.byType(TodayEntryTile)).toList();

List<Mood?> _bannerMoods(WidgetTester tester) => <Mood?>[
  for (final MoodBanner banner in tester.widgetList<MoodBanner>(
    find.byType(MoodBanner),
  ))
    banner.mood,
];

void main() {
  testWidgets(
    'start asks for permission once, saves the choices and lands on Today',
    (WidgetTester tester) async {
      for (final _Layout layout in _layouts) {
        await _onLayout(layout, () async {
          for (final ReminderPermission permission
              in ReminderPermission.values) {
            final String reason = '${layout.name} ${permission.name}';
            final bool granted = permission == ReminderPermission.granted;
            final _StoredSettings settings = _StoredSettings();
            final RecordingReminderScheduler scheduler =
                RecordingReminderScheduler(permission: permission);
            final ProviderContainer container = await _launch(
              tester,
              layout,
              settings: settings,
              scheduler: scheduler,
            );
            await _walkToTour(
              tester,
              container,
              reminder: ReminderChoice.morning,
              week: WeekStart.monday,
            );
            container
                .read(shellNavigationProvider.notifier)
                .select(ShellDestination.calendar);
            await _settle(tester);

            await _pressStart(tester, layout);

            expect(settings.reminderEnabledWrites, <bool>[
              granted,
            ], reason: reason);
            expect(settings.reminderTimeWrites, <ReminderTime>[
              _morning,
            ], reason: reason);
            expect(settings.weekStartWrites, <WeekStart>[
              WeekStart.monday,
            ], reason: reason);
            expect(settings.onboardingStatusWrites, <OnboardingStatus>[
              OnboardingStatus.pending,
              OnboardingStatus.done,
            ], reason: reason);
            expect(settings.appearanceWrites, isEmpty, reason: reason);
            expect(scheduler.permissionRequests, 1, reason: reason);
            expect(settings.notificationPermissionAskedWrites, <bool>[
              true,
            ], reason: reason);
            _expectToday(tester, container, reason: reason);
            await _close(tester, null);
          }
        });
      }
    },
  );

  testWidgets('start with no reminder never asks for permission', (
    WidgetTester tester,
  ) async {
    for (final _Layout layout in _layouts) {
      await _onLayout(layout, () async {
        final String reason = layout.name;
        final _StoredSettings settings = _StoredSettings();
        final RecordingReminderScheduler scheduler = RecordingReminderScheduler(
          permission: ReminderPermission.unknown,
        );
        final ProviderContainer container = await _launch(
          tester,
          layout,
          settings: settings,
          scheduler: scheduler,
        );
        await _walkToTour(
          tester,
          container,
          reminder: ReminderChoice.off,
          week: WeekStart.sunday,
        );

        await _pressStart(tester, layout);

        expect(scheduler.permissionRequests, 0, reason: reason);
        expect(
          settings.notificationPermissionAskedWrites,
          isEmpty,
          reason: reason,
        );
        expect(settings.reminderEnabledWrites, <bool>[false], reason: reason);
        expect(settings.reminderTimeWrites, <ReminderTime>[
          ReminderTime.defaultTime,
        ], reason: reason);
        expect(settings.weekStartWrites, <WeekStart>[
          WeekStart.sunday,
        ], reason: reason);
        expect(settings.onboardingStatusWrites, <OnboardingStatus>[
          OnboardingStatus.pending,
          OnboardingStatus.done,
        ], reason: reason);
        _expectToday(tester, container, reason: reason);
        await _close(tester, null);
      });
    }
  });

  testWidgets(
    'a failed save at start keeps the tour with the error and does not finish',
    (WidgetTester tester) async {
      for (final _Layout layout in _layouts) {
        await _onLayout(layout, () async {
          final String reason = layout.name;
          final _StoredSettings settings = _StoredSettings()
            ..failReminderEnabled = true;
          final RecordingReminderScheduler scheduler =
              RecordingReminderScheduler(permission: ReminderPermission.denied);
          final ProviderContainer container = await _launch(
            tester,
            layout,
            settings: settings,
            scheduler: scheduler,
          );
          await _walkToTour(
            tester,
            container,
            reminder: ReminderChoice.evening,
            week: WeekStart.saturday,
          );

          await _pressStart(tester, layout);

          _expectStillOnTour(
            tester,
            container,
            layout,
            settings,
            reason: '$reason reminder write',
          );
          expect(settings.reminderEnabledWrites, isEmpty, reason: reason);
          expect(scheduler.permissionRequests, 1, reason: reason);

          settings.failReminderEnabled = false;
          await _pressStart(tester, layout);

          expect(scheduler.permissionRequests, 1, reason: reason);
          expect(settings.reminderEnabledWrites, <bool>[false], reason: reason);
          expect(settings.reminderTimeWrites, <ReminderTime>[
            _evening,
          ], reason: reason);
          expect(settings.weekStartWrites, <WeekStart>[
            WeekStart.saturday,
          ], reason: reason);
          expect(settings.onboardingStatusWrites, <OnboardingStatus>[
            OnboardingStatus.pending,
            OnboardingStatus.done,
          ], reason: reason);
          _expectToday(tester, container, reason: reason);
          await _close(tester, null);

          final _StoredSettings unrecorded = _StoredSettings();
          final RecordingReminderScheduler allowed =
              RecordingReminderScheduler();
          final ProviderContainer stuck = await _launch(
            tester,
            layout,
            settings: unrecorded,
            scheduler: allowed,
          );
          await _walkToTour(
            tester,
            stuck,
            reminder: ReminderChoice.midday,
            week: WeekStart.monday,
          );
          unrecorded.failOnboardingStatus = true;

          await _pressStart(tester, layout);

          _expectStillOnTour(
            tester,
            stuck,
            layout,
            unrecorded,
            reason: '$reason onboarding status write',
          );
          expect(unrecorded.reminderEnabledWrites, <bool>[true]);
          expect(unrecorded.reminderTimeWrites, <ReminderTime>[_midday]);

          unrecorded.failOnboardingStatus = false;
          await _pressStart(tester, layout);

          expect(unrecorded.onboardingStatusWrites, <OnboardingStatus>[
            OnboardingStatus.pending,
            OnboardingStatus.done,
          ], reason: reason);
          _expectToday(tester, stuck, reason: reason);
          await _close(tester, null);
        });
      }
    },
  );

  testWidgets(
    'today shows the onboarding mood and exactly one log with the typed line',
    (WidgetTester tester) async {
      for (final _Layout layout in _layouts) {
        await _onLayout(layout, () async {
          final String reason = layout.name;
          final db.AppDatabase database = newTestDatabase();
          final ProviderContainer container = await _launch(
            tester,
            layout,
            settings: _StoredSettings(),
            scheduler: RecordingReminderScheduler(),
            journal: DriftJournalRepository(database),
          );
          final OnboardingController controller = _controller(container);

          controller
            ..plant()
            ..markGrown()
            ..next()
            ..chooseMood(Mood.calm)
            ..next()
            ..setNote(_firstLine);
          await tester.pump(_pause);
          await _settle(tester);
          controller
            ..back()
            ..chooseMood(Mood.grateful)
            ..next()
            ..setNote(_finalLine)
            ..setMonthFill(1)
            ..setYearDay(365, scrubbed: false)
            ..next()
            ..next()
            ..next()
            ..next()
            ..next()
            ..next();
          await tester.pump();
          expect(find.byType(TourChapter), findsOneWidget, reason: reason);

          await _pressStart(tester, layout);
          _expectToday(tester, container, reason: reason);

          await _until(
            tester,
            () =>
                _bannerMoods(tester).contains(Mood.grateful) &&
                _tiles(tester).length == 1 &&
                _tiles(tester).single.entry.textContent == _finalLine,
          );
          expect(_bannerMoods(tester), <Mood?>[Mood.grateful], reason: reason);
          expect(
            find.text('Feeling ${Mood.grateful.label} today'),
            findsOneWidget,
            reason: reason,
          );
          final List<TodayEntryTile> tiles = _tiles(tester);
          expect(tiles, hasLength(1), reason: reason);
          expect(tiles.single.entry.type, EntryType.text, reason: reason);
          expect(tiles.single.entry.textContent, _finalLine, reason: reason);
          expect(tiles.single.date, _today, reason: reason);

          final List<db.Day> days = await database.select(database.days).get();
          expect(days, hasLength(1), reason: reason);
          expect(days.single.date, _today, reason: reason);
          expect(days.single.moodId, Mood.grateful.id, reason: reason);
          final List<db.Entry> rows = await database
              .select(database.entries)
              .get();
          expect(rows, hasLength(1), reason: reason);
          expect(rows.single.id, tiles.single.entry.id, reason: reason);
          expect(rows.single.dayId, days.single.id, reason: reason);
          expect(rows.single.deletedAt, isNull, reason: reason);
          await _close(tester, database);
        });
      }
    },
  );
}
