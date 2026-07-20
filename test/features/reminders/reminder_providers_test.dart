import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_coordinator.dart';
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

ProviderContainer _container({
  required AppSettings settings,
  required List<Entry> todayEntries,
  required FakeReminderScheduler scheduler,
  required DateTime now,
  List<String>? queriedDates,
}) {
  final container = ProviderContainer(
    overrides: <Override>[
      appSettingsProvider.overrideWith(
        (ref) => Stream<AppSettings>.value(settings),
      ),
      entriesForDateProvider.overrideWith((ref, date) {
        queriedDates?.add(date);
        return Stream<List<Entry>>.value(todayEntries);
      }),
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
    test('schedules tonight when today has no entry', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler();
      final ProviderContainer container = _container(
        settings: AppSettings.defaults,
        todayEntries: const <Entry>[],
        scheduler: scheduler,
        now: DateTime(2026, 7, 19, 9),
      );

      final ReminderSyncResult? result = await _settledSync(container);

      expect(result, ReminderSyncResult.scheduled);
      expect(scheduler.scheduled, <DateTime>[DateTime(2026, 7, 19, 20, 30)]);
    });

    test('suppresses today and schedules tomorrow once an entry exists',
        () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler();
      final ProviderContainer container = _container(
        settings: AppSettings.defaults,
        todayEntries: <Entry>[_entry()],
        scheduler: scheduler,
        now: DateTime(2026, 7, 19, 9),
      );

      final ReminderSyncResult? result = await _settledSync(container);

      expect(result, ReminderSyncResult.scheduled);
      expect(scheduler.scheduled, <DateTime>[DateTime(2026, 7, 20, 20, 30)]);
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
            (ref) => const Stream<AppSettings>.empty(),
          ),
          entriesForDateProvider.overrideWith(
            (ref, date) => const Stream<List<Entry>>.empty(),
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
