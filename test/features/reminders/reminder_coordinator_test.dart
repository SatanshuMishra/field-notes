import 'dart:async';

import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_reminder_scheduler.dart';

void main() {
  group('ReminderCoordinator.sync', () {
    test('schedules tonight when enabled and today has no entry', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler();
      final ReminderCoordinator coordinator =
          ReminderCoordinator(scheduler: scheduler);

      final ReminderSyncResult result = await coordinator.sync(
        enabled: true,
        time: ReminderTime.defaultTime,
        now: DateTime(2026, 7, 19, 9),
        todayHasEntry: false,
      );

      expect(result, ReminderSyncResult.scheduled);
      expect(scheduler.scheduled, <DateTime>[DateTime(2026, 7, 19, 20, 30)]);
    });

    test('schedules tomorrow when today already has an entry', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler();
      final ReminderCoordinator coordinator =
          ReminderCoordinator(scheduler: scheduler);

      final ReminderSyncResult result = await coordinator.sync(
        enabled: true,
        time: ReminderTime.defaultTime,
        now: DateTime(2026, 7, 19, 9),
        todayHasEntry: true,
      );

      expect(result, ReminderSyncResult.scheduled);
      expect(scheduler.scheduled, <DateTime>[DateTime(2026, 7, 20, 20, 30)]);
    });

    test('cancels without asking for permission when disabled', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler();
      final ReminderCoordinator coordinator =
          ReminderCoordinator(scheduler: scheduler);

      final ReminderSyncResult result = await coordinator.sync(
        enabled: false,
        time: ReminderTime.defaultTime,
        now: DateTime(2026, 7, 19, 9),
        todayHasEntry: false,
      );

      expect(result, ReminderSyncResult.cancelled);
      expect(scheduler.cancelCount, 1);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.permissionRequests, 0);
    });

    test('cancels and reports denial when permission is refused', () async {
      final FakeReminderScheduler scheduler =
          FakeReminderScheduler(permissionGranted: false);
      final ReminderCoordinator coordinator =
          ReminderCoordinator(scheduler: scheduler);

      final ReminderSyncResult result = await coordinator.sync(
        enabled: true,
        time: ReminderTime.defaultTime,
        now: DateTime(2026, 7, 19, 9),
        todayHasEntry: false,
      );

      expect(result, ReminderSyncResult.permissionDenied);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelCount, 1);
    });

    test('forwards a scheduling failure instead of throwing', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler(
        scheduleError: StateError('alarm manager unavailable'),
      );
      final List<Object> errors = <Object>[];
      final ReminderCoordinator coordinator = ReminderCoordinator(
        scheduler: scheduler,
        onError: (Object error, StackTrace _) => errors.add(error),
      );

      final ReminderSyncResult result = await coordinator.sync(
        enabled: true,
        time: ReminderTime.defaultTime,
        now: DateTime(2026, 7, 19, 9),
        todayHasEntry: false,
      );

      expect(result, ReminderSyncResult.failed);
      expect(errors, hasLength(1));
      expect(errors.single, isStateError);
    });

    test('drops a queued sync that a newer sync superseded', () async {
      final FakeReminderScheduler scheduler = FakeReminderScheduler();
      final ReminderCoordinator coordinator =
          ReminderCoordinator(scheduler: scheduler);

      final Future<ReminderSyncResult> first = coordinator.sync(
        enabled: true,
        time: ReminderTime.defaultTime,
        now: DateTime(2026, 7, 19, 9),
        todayHasEntry: false,
      );
      final Future<ReminderSyncResult> second = coordinator.sync(
        enabled: false,
        time: ReminderTime.defaultTime,
        now: DateTime(2026, 7, 19, 9),
        todayHasEntry: false,
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
      final FakeReminderScheduler scheduler =
          FakeReminderScheduler(scheduleGate: gate);
      final ReminderCoordinator coordinator =
          ReminderCoordinator(scheduler: scheduler);

      final Future<ReminderSyncResult> first = coordinator.sync(
        enabled: true,
        time: ReminderTime.defaultTime,
        now: DateTime(2026, 7, 19, 9),
        todayHasEntry: false,
      );
      await pumpEventQueue();

      expect(scheduler.calls, <String>['permission', 'schedule']);

      final Future<ReminderSyncResult> second = coordinator.sync(
        enabled: false,
        time: ReminderTime.defaultTime,
        now: DateTime(2026, 7, 19, 9),
        todayHasEntry: false,
      );
      await pumpEventQueue();

      expect(scheduler.calls, <String>['permission', 'schedule']);
      expect(scheduler.cancelCount, 0);

      gate.complete();

      expect(await first, ReminderSyncResult.scheduled);
      expect(await second, ReminderSyncResult.cancelled);
      expect(
        scheduler.calls,
        <String>['permission', 'schedule', 'cancel'],
      );
      expect(scheduler.scheduled, <DateTime>[DateTime(2026, 7, 19, 20, 30)]);
      expect(scheduler.cancelCount, 1);
    });
  });
}
