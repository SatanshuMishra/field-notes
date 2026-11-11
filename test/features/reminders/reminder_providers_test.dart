import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/reminder_service.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_coordinator.dart';
import 'package:field_notes/features/reminders/reminder_date.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_reminder_scheduler.dart';

Entry _entry() => const Entry(
  id: 'entry-1',
  dayId: 'day-1',
  type: EntryType.text,
  textContent: 'a note',
  createdAt: 0,
  updatedAt: 0,
);

Day _bloomed(String date) => Day(
  id: 'day-$date',
  date: date,
  createdAt: 0,
  updatedAt: 0,
  mood: Mood.happy,
);

List<ReminderBooking> _evenings(
  DateTime now, {
  ReminderDay today = const ReminderDay(),
}) => const ReminderService().upcomingReminders(
  enabled: true,
  schedule: ReminderSchedule.evenings,
  customTime: ReminderTime.defaultTime,
  now: now,
  days: <DateTime, ReminderDay>{DateTime(now.year, now.month, now.day): today},
)!;

ProviderContainer _container({
  required AppSettings settings,
  required List<Entry> todayEntries,
  required FakeReminderScheduler scheduler,
  required DateTime now,
  bool todayBloomed = false,
  List<String>? queriedDates,
}) {
  final container = ProviderContainer(
    overrides: <Override>[
      appSettingsProvider.overrideWith(
        (ref) => Stream<AppSettings>.value(settings),
      ),
      entriesForDateProvider.overrideWith((ref, date) {
        queriedDates?.add(date);
        return Stream<List<Entry>>.value(
          date == reminderDateKey(now) ? todayEntries : const <Entry>[],
        );
      }),
      dayForDateProvider.overrideWith(
        (ref, date) => Stream<Day?>.value(
          todayBloomed && date == reminderDateKey(now) ? _bloomed(date) : null,
        ),
      ),
      reminderClockProvider.overrideWithValue(() => now),
      reminderSchedulerProvider.overrideWithValue(scheduler),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<ReminderSyncResult?> _settledSync(ProviderContainer container) async {
  final sub = container.listen(
    reminderSyncProvider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(sub.close);
  await pumpEventQueue();
  return container.read(reminderSyncProvider.future);
}

void main() {
  group('reminderSyncProvider', () {
    test('schedules tonight when today has nothing yet', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler();
      final ProviderContainer container = _container(
        settings: AppSettings.defaults,
        todayEntries: const <Entry>[],
        scheduler: scheduler,
        now: DateTime(2026, 7, 19, 9),
      );

      final ReminderSyncResult? result = await _settledSync(container);

      expect(result, ReminderSyncResult.scheduled);
      expect(scheduler.scheduled, _evenings(DateTime(2026, 7, 19, 9)));
      expect(scheduler.scheduled.first.at, DateTime(2026, 7, 19, 20, 30));
    });

    test(
      'keeps tonight, asking for a bloom, when today has only a log',
      () async {
        final FakeReminderScheduler scheduler = FakeReminderScheduler();
        final ProviderContainer container = _container(
          settings: AppSettings.defaults,
          todayEntries: <Entry>[_entry()],
          scheduler: scheduler,
          now: DateTime(2026, 7, 19, 9),
        );

        await _settledSync(container);

        expect(
          scheduler.scheduled,
          _evenings(
            DateTime(2026, 7, 19, 9),
            today: const ReminderDay(logCount: 1),
          ),
        );
        expect(scheduler.scheduled[1].at, DateTime(2026, 7, 19, 22, 30));
        expect(scheduler.scheduled[1].body, reminderLastCallBloomBody);
      },
    );

    test('skips today once it has its bloom and a log', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler();
      final ProviderContainer container = _container(
        settings: AppSettings.defaults,
        todayEntries: <Entry>[_entry()],
        todayBloomed: true,
        scheduler: scheduler,
        now: DateTime(2026, 7, 19, 9),
      );

      final ReminderSyncResult? result = await _settledSync(container);

      expect(result, ReminderSyncResult.scheduled);
      expect(scheduler.scheduled.first.at, DateTime(2026, 7, 20, 20, 30));
      expect(scheduler.scheduled, hasLength(12));
    });

    test('follows the chosen schedule and custom time', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler();
      final ProviderContainer container = _container(
        settings: AppSettings.defaults.copyWith(
          reminderSchedule: ReminderSchedule.custom,
          reminderTime: const ReminderTime(hour: 7, minute: 15),
        ),
        todayEntries: const <Entry>[],
        scheduler: scheduler,
        now: DateTime(2026, 7, 19, 6),
      );

      await _settledSync(container);

      expect(
        scheduler.scheduled.take(2).map((ReminderBooking b) => b.at).toList(),
        <DateTime>[DateTime(2026, 7, 19, 7, 15), DateTime(2026, 7, 19, 22, 30)],
      );
    });

    test('cancels when the reminder toggle is off', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler();
      final ProviderContainer container = _container(
        settings: AppSettings.defaults.copyWith(reminderEnabled: false),
        todayEntries: const <Entry>[],
        scheduler: scheduler,
        now: DateTime(2026, 7, 19, 9),
      );

      final ReminderSyncResult? result = await _settledSync(container);

      expect(result, ReminderSyncResult.cancelled);
      expect(scheduler.cancelCount, 1);
      expect(scheduler.scheduled, isEmpty);
    });

    test("looks up today's entries by today's date key", () async {
      final List<String> queriedDates = <String>[];
      final ProviderContainer container = _container(
        settings: AppSettings.defaults,
        todayEntries: const <Entry>[],
        scheduler: FakeReminderScheduler(),
        now: DateTime(2026, 7, 19, 9),
        queriedDates: queriedDates,
      );

      await _settledSync(container);

      expect(queriedDates, contains('2026-07-19'));
    });

    test('schedules nothing while an input is still loading', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler();
      final container = ProviderContainer(
        overrides: <Override>[
          appSettingsProvider.overrideWith(
            (ref) => Stream<AppSettings>.value(AppSettings.defaults),
          ),
          entriesForDateProvider.overrideWith(
            (ref, date) => Stream<List<Entry>>.value(const <Entry>[]),
          ),
          dayForDateProvider.overrideWith(
            (ref, date) => const Stream<Day?>.empty(),
          ),
          reminderClockProvider.overrideWithValue(
            () => DateTime(2026, 7, 19, 9),
          ),
          reminderSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
      addTearDown(container.dispose);

      final ReminderSyncResult? result = await _settledSync(container);

      expect(result, isNull);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelCount, 0);
    });
  });
}
