import 'dart:async';

import 'package:field_notes/domain/services/reminder_service.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_reminder_scheduler.dart';

final DateTime _morning = DateTime(2026, 7, 19, 9);

List<ReminderBooking> _evenings(
  DateTime now, {
  Set<int> skippedDays = const <int>{},
}) => const ReminderService().upcomingReminders(
  enabled: true,
  schedule: ReminderSchedule.evenings,
  customTime: ReminderTime.defaultTime,
  now: now,
  days: <DateTime, ReminderDay>{
    for (final int day in skippedDays)
      DateTime(now.year, now.month, day): const ReminderDay(
        hasBloom: true,
        logCount: 1,
      ),
  },
)!;

Future<ReminderSyncResult> _sync(
  ReminderCoordinator coordinator, {
  bool enabled = true,
  ReminderSchedule schedule = ReminderSchedule.evenings,
  ReminderTime customTime = ReminderTime.defaultTime,
  DateTime? now,
  Map<DateTime, ReminderDay> days = const <DateTime, ReminderDay>{},
}) => coordinator.sync(
  enabled: enabled,
  schedule: schedule,
  customTime: customTime,
  now: now ?? _morning,
  days: days,
);

void main() {
  group('ReminderCoordinator.sync', () {
    test('schedules tonight and the next six days when enabled', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler();
      final ReminderCoordinator coordinator = ReminderCoordinator(
        scheduler: scheduler,
      );

      final ReminderSyncResult result = await _sync(coordinator);

      expect(result, ReminderSyncResult.scheduled);
      expect(scheduler.scheduled, _evenings(_morning));
      expect(scheduler.scheduled.first.at, DateTime(2026, 7, 19, 20, 30));
    });

    test('schedules from tomorrow once today is complete', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler();
      final ReminderCoordinator coordinator = ReminderCoordinator(
        scheduler: scheduler,
      );

      final ReminderSyncResult result = await _sync(
        coordinator,
        days: <DateTime, ReminderDay>{
          DateTime(2026, 7, 19): const ReminderDay(hasBloom: true, logCount: 2),
        },
      );

      expect(result, ReminderSyncResult.scheduled);
      expect(scheduler.scheduled, _evenings(_morning, skippedDays: <int>{19}));
      expect(scheduler.scheduled.first.at, DateTime(2026, 7, 20, 20, 30));
    });

    test(
      'makes no scheduler calls when the same inputs arrive again',
      () async {
        final FakeReminderScheduler scheduler = FakeReminderScheduler();
        final ReminderCoordinator coordinator = ReminderCoordinator(
          scheduler: scheduler,
        );
        await _sync(coordinator);
        final List<String> before = List<String>.of(scheduler.calls);

        final ReminderSyncResult again = await _sync(
          coordinator,
          now: _morning.add(const Duration(minutes: 5)),
        );

        expect(again, ReminderSyncResult.scheduled);
        expect(before, <String>['permission', 'schedule']);
        expect(scheduler.calls, before);
      },
    );

    test(
      'makes no scheduler calls when a change leaves the same nudges',
      () async {
        final FakeReminderScheduler scheduler = FakeReminderScheduler();
        final ReminderCoordinator coordinator = ReminderCoordinator(
          scheduler: scheduler,
        );
        await _sync(
          coordinator,
          days: <DateTime, ReminderDay>{
            DateTime(2026, 7, 19): const ReminderDay(logCount: 1),
          },
        );
        final int calls = scheduler.calls.length;

        await _sync(
          coordinator,
          customTime: const ReminderTime(hour: 7, minute: 15),
          days: <DateTime, ReminderDay>{
            DateTime(2026, 7, 19): const ReminderDay(logCount: 3),
          },
        );

        expect(scheduler.calls, hasLength(calls));
      },
    );

    test('reschedules when completing today changes the nudges', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler();
      final ReminderCoordinator coordinator = ReminderCoordinator(
        scheduler: scheduler,
      );
      await _sync(coordinator);
      scheduler.scheduled.clear();

      await _sync(
        coordinator,
        days: <DateTime, ReminderDay>{
          DateTime(2026, 7, 19): const ReminderDay(hasBloom: true, logCount: 1),
        },
      );

      expect(scheduler.calls, <String>[
        'permission',
        'schedule',
        'permission',
        'schedule',
      ]);
      expect(scheduler.scheduled, _evenings(_morning, skippedDays: <int>{19}));
    });

    test('cancels without asking for permission when disabled', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler();
      final ReminderCoordinator coordinator = ReminderCoordinator(
        scheduler: scheduler,
      );

      final ReminderSyncResult result = await _sync(
        coordinator,
        enabled: false,
      );

      expect(result, ReminderSyncResult.cancelled);
      expect(scheduler.cancelCount, 1);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.permissionRequests, 0);
    });

    test('cancels only once while reminders stay off', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler();
      final ReminderCoordinator coordinator = ReminderCoordinator(
        scheduler: scheduler,
      );

      await _sync(coordinator, enabled: false);
      await _sync(coordinator, enabled: false);

      expect(scheduler.calls, <String>['cancel']);
    });

    test('cancels and reports denial when permission is refused', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler(
        permissionGranted: false,
      );
      final ReminderCoordinator coordinator = ReminderCoordinator(
        scheduler: scheduler,
      );

      final ReminderSyncResult result = await _sync(coordinator);

      expect(result, ReminderSyncResult.permissionDenied);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelCount, 1);
    });

    test('books the nudges once a refused permission is granted', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler(
        permissionGranted: false,
      );
      final ReminderCoordinator coordinator = ReminderCoordinator(
        scheduler: scheduler,
      );
      await _sync(coordinator);

      scheduler.permissionGranted = true;
      final ReminderSyncResult result = await _sync(coordinator);

      expect(result, ReminderSyncResult.scheduled);
      expect(scheduler.calls, <String>[
        'permission',
        'cancel',
        'permission',
        'schedule',
      ]);
    });

    test('forwards a scheduling failure and retries the same nudges', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler(
        scheduleError: StateError('alarm manager unavailable'),
      );
      final List<Object> errors = <Object>[];
      final ReminderCoordinator coordinator = ReminderCoordinator(
        scheduler: scheduler,
        onError: (Object error, StackTrace _) => errors.add(error),
      );

      final ReminderSyncResult result = await _sync(coordinator);
      final ReminderSyncResult retry = await _sync(coordinator);

      expect(result, ReminderSyncResult.failed);
      expect(retry, ReminderSyncResult.failed);
      expect(errors, hasLength(2));
      expect(errors.first, isStateError);
    });

    test('drops a queued sync that a newer sync superseded', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler();
      final ReminderCoordinator coordinator = ReminderCoordinator(
        scheduler: scheduler,
      );

      final Future<ReminderSyncResult> first = _sync(coordinator);
      final Future<ReminderSyncResult> second = _sync(
        coordinator,
        enabled: false,
      );

      expect(await first, ReminderSyncResult.superseded);
      expect(await second, ReminderSyncResult.cancelled);
      expect(scheduler.calls, <String>['cancel']);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelCount, 1);
      expect(scheduler.permissionRequests, 0);
    });

    test('serializes a later cancel behind an in-flight schedule', () async {
      final Completer<void> gate = Completer<void>();
      final FakeReminderScheduler scheduler = FakeReminderScheduler(
        scheduleGate: gate,
      );
      final ReminderCoordinator coordinator = ReminderCoordinator(
        scheduler: scheduler,
      );

      final Future<ReminderSyncResult> first = _sync(coordinator);
      await pumpEventQueue();

      expect(scheduler.calls, <String>['permission', 'schedule']);

      final Future<ReminderSyncResult> second = _sync(
        coordinator,
        enabled: false,
      );
      await pumpEventQueue();

      expect(scheduler.calls, <String>['permission', 'schedule']);
      expect(scheduler.cancelCount, 0);

      gate.complete();

      expect(await first, ReminderSyncResult.scheduled);
      expect(await second, ReminderSyncResult.cancelled);
      expect(scheduler.calls, <String>['permission', 'schedule', 'cancel']);
      expect(scheduler.scheduled, _evenings(_morning));
      expect(scheduler.cancelCount, 1);
    });
  });
}
