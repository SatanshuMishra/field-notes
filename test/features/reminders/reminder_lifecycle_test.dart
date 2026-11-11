import 'dart:async';

import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/reminder_service.dart';
import 'package:field_notes/domain/services/streak_service.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/onboarding/onboarding_gate.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/reminders/reminder_scheduler.dart';
import 'package:field_notes/features/search/search_entries_provider.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/spell_check_availability.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart' show FakeJournalRepository;
import '../settings/support/fake_settings_repository.dart';
import '../settings/support/recording_reminder_scheduler.dart';

Entry _entry(String id) => Entry(
  id: id,
  dayId: 'day-$id',
  type: EntryType.text,
  textContent: 'a note',
  createdAt: 0,
  updatedAt: 0,
);

Stream<List<Entry>> _noEntries(String date) =>
    Stream<List<Entry>>.value(const <Entry>[]);

Stream<Day?> _noDay(String date) => Stream<Day?>.value(null);

Day _bloomed(String date) => Day(
  id: 'day-$date',
  date: date,
  createdAt: 0,
  updatedAt: 0,
  mood: Mood.happy,
);

Map<int, DateTime> _eveningsOn(Iterable<int> julyDays) => <int, DateTime>{
  for (final int day in julyDays) ...<int, DateTime>{
    ReminderService.bookingIdFor(DateTime(2026, 7, day), ReminderNudge.evening):
        DateTime(2026, 7, day, 20, 30),
    ReminderService.bookingIdFor(
      DateTime(2026, 7, day),
      ReminderNudge.lastCall,
    ): DateTime(
      2026,
      7,
      day,
      22,
      30,
    ),
  },
};

Iterable<int> _julyDays(int first, int last) => <int>[
  for (int day = first; day <= last; day++) day,
];

void _holdStill(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<RecordingReminderScheduler> _launch(
  WidgetTester tester, {
  required DateTime Function() clock,
  Stream<List<Entry>> Function(String date) entriesFor = _noEntries,
  Stream<Day?> Function(String date) dayFor = _noDay,
  FakeSettingsRepository? settings,
  RecordingReminderScheduler? recorder,
}) async {
  final RecordingReminderScheduler scheduler =
      recorder ?? RecordingReminderScheduler();
  _holdStill(tester);
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(FakeJournalRepository()),
        settingsRepositoryProvider.overrideWithValue(
          settings ?? FakeSettingsRepository(),
        ),
        journaledDatesProvider.overrideWith(
          (Ref ref) => Stream<List<String>>.value(const <String>[]),
        ),
        streakDaysProvider.overrideWith(
          (Ref ref) => Stream<List<StreakDay>>.value(const <StreakDay>[]),
        ),
        searchAllEntriesProvider.overrideWith(
          (Ref ref) => Stream<List<Entry>>.value(const <Entry>[]),
        ),
        spellCheckAvailabilityProvider.overrideWithValue(
          const AsyncValue<SpellCheckAvailability>.data(
            SpellCheckAvailability.available,
          ),
        ),
        entriesForDateProvider.overrideWith(
          (Ref ref, String date) => entriesFor(date),
        ),
        dayForDateProvider.overrideWith((Ref ref, String date) => dayFor(date)),
        reminderClockProvider.overrideWithValue(clock),
        reminderSchedulerProvider.overrideWithValue(scheduler),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return scheduler;
}

void main() {
  testWidgets('the reminder is booked at launch without opening Settings', (
    WidgetTester tester,
  ) async {
    final RecordingReminderScheduler scheduler = await _launch(
      tester,
      clock: () => DateTime(2026, 7, 20, 9),
    );

    expect(find.byType(SettingsScreen), findsNothing);
    expect(scheduler.booked, _eveningsOn(_julyDays(20, 26)));
  });

  testWidgets(
    'the next seven days are booked and only days with a bloom and a log are skipped',
    (WidgetTester tester) async {
      final RecordingReminderScheduler scheduler = await _launch(
        tester,
        clock: () => DateTime(2026, 7, 20, 9),
        entriesFor: (String date) => Stream<List<Entry>>.value(switch (date) {
          '2026-07-20' => <Entry>[_entry('monday')],
          '2026-07-22' => <Entry>[_entry('wednesday')],
          _ => const <Entry>[],
        }),
        dayFor: (String date) =>
            Stream<Day?>.value(date == '2026-07-22' ? _bloomed(date) : null),
      );

      expect(scheduler.booked, _eveningsOn(<int>[20, 21, 23, 24, 25, 26]));
    },
  );

  testWidgets(
    "finishing today cancels today's nudges and keeps the next six days",
    (WidgetTester tester) async {
      final StreamController<List<Entry>> today =
          StreamController<List<Entry>>();
      final StreamController<Day?> todayDay = StreamController<Day?>();
      addTearDown(() {
        today.close();
        todayDay.close();
      });
      today.add(const <Entry>[]);
      todayDay.add(null);
      final RecordingReminderScheduler scheduler = await _launch(
        tester,
        clock: () => DateTime(2026, 7, 20, 9),
        entriesFor: (String date) =>
            date == '2026-07-20' ? today.stream : _noEntries(date),
        dayFor: (String date) =>
            date == '2026-07-20' ? todayDay.stream : _noDay(date),
      );

      expect(scheduler.booked, _eveningsOn(_julyDays(20, 26)));

      today.add(<Entry>[_entry('tonight')]);
      await tester.pumpAndSettle();

      expect(scheduler.booked, _eveningsOn(_julyDays(20, 26)));
      expect(
        scheduler.bookings.last
            .firstWhere(
              (ReminderBooking booking) =>
                  booking.at == DateTime(2026, 7, 20, 22, 30),
            )
            .body,
        reminderLastCallBloomBody,
      );

      todayDay.add(_bloomed('2026-07-20'));
      await tester.pumpAndSettle();

      expect(scheduler.booked, _eveningsOn(_julyDays(21, 26)));
    },
  );

  testWidgets('resuming the app re-books the next seven days', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime(2026, 7, 20, 9);
    final RecordingReminderScheduler scheduler = await _launch(
      tester,
      clock: () => now,
    );

    for (final AppLifecycleState state in <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    now = DateTime(2026, 7, 21, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(scheduler.booked, _eveningsOn(_julyDays(21, 27)));
  });

  testWidgets('permission is asked once at first launch', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository firstSettings = FakeSettingsRepository();
    final RecordingReminderScheduler firstLaunch = await _launch(
      tester,
      clock: () => DateTime(2026, 7, 20, 9),
      settings: firstSettings,
      recorder: RecordingReminderScheduler(
        permission: ReminderPermission.denied,
      ),
    );

    expect(firstLaunch.permissionRequests, 1);
    expect(firstSettings.notificationPermissionAskedWrites, <bool>[true]);

    await tester.pumpWidget(const SizedBox());
    final RecordingReminderScheduler relaunch = await _launch(
      tester,
      clock: () => DateTime(2026, 7, 20, 9),
      settings: FakeSettingsRepository(
        initial: AppSettings.defaults.copyWith(
          notificationPermissionAsked:
              firstSettings.notificationPermissionAskedWrites.last,
        ),
      ),
    );

    expect(relaunch.permissionRequests, 0);
    expect(relaunch.statusChecks, greaterThan(0));
  });

  testWidgets(
    'the first-launch notification request waits until onboarding is done',
    (WidgetTester tester) async {
      final RecordingReminderScheduler scheduler = await _launch(
        tester,
        clock: () => DateTime(2026, 7, 20, 9),
        settings: FakeSettingsRepository(storedValues: false),
      );
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
      );

      expect(
        await container.read(onboardingGateProvider.future),
        OnboardingVisibility.shown,
      );
      expect(scheduler.permissionRequests, 0);

      await container.read(onboardingGateProvider.notifier).complete();
      await tester.pumpAndSettle();

      expect(scheduler.permissionRequests, 1);
    },
  );
}
