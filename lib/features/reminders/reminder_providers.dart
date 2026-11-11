import 'dart:async';

import 'package:field_notes/data/settings/drift_reminder_ledger_store.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/reminder_service.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderListenableSelect;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'local_notifications_reminder_scheduler.dart';
import 'notification_settings_opener.dart';
import 'reminder_coordinator.dart';
import 'reminder_date.dart';
import 'reminder_scheduler.dart';

part 'reminder_providers.g.dart';

@Riverpod(keepAlive: true)
DateTime Function() reminderClock(Ref ref) => DateTime.now;

@Riverpod(keepAlive: true)
ReminderScheduler reminderScheduler(Ref ref) =>
    LocalNotificationsReminderScheduler(
      ledger: DriftReminderLedgerStore(ref.watch(databaseProvider)),
    );

@Riverpod(keepAlive: true)
ReminderCoordinator reminderCoordinator(Ref ref) => ReminderCoordinator(
  scheduler: ref.watch(reminderSchedulerProvider),
  onError: (Object error, StackTrace _) =>
      debugPrint('Reminder scheduling failed: $error'),
);

typedef ReminderPlan = ({
  bool enabled,
  ReminderSchedule schedule,
  ReminderTime customTime,
});

@Riverpod(keepAlive: true)
Future<ReminderSyncResult?> reminderSync(Ref ref) async {
  final ReminderPlan? plan = ref.watch(
    appSettingsProvider.select(
      (AsyncValue<AppSettings> settings) => switch (settings.value) {
        final AppSettings value => (
          enabled: value.reminderEnabled,
          schedule: value.reminderSchedule,
          customTime: value.reminderTime,
        ),
        null => null,
      },
    ),
  );
  if (plan == null) {
    return null;
  }
  final DateTime now = ref.watch(reminderClockProvider)();
  final ReminderCoordinator coordinator = ref.watch(
    reminderCoordinatorProvider,
  );
  if (!plan.enabled) {
    return coordinator.sync(
      enabled: false,
      schedule: plan.schedule,
      customTime: plan.customTime,
      now: now,
    );
  }
  final Timer midnight = Timer(
    DateTime(now.year, now.month, now.day + 1).difference(now),
    ref.invalidateSelf,
  );
  ref.onDispose(midnight.cancel);
  final List<DateTime> days = const ReminderService().windowDays(now);
  final List<AsyncValue<List<Entry>>> entries = <AsyncValue<List<Entry>>>[
    for (final DateTime day in days)
      ref.watch(entriesForDateProvider(reminderDateKey(day))),
  ];
  final List<AsyncValue<Day?>> blooms = <AsyncValue<Day?>>[
    for (final DateTime day in days)
      ref.watch(dayForDateProvider(reminderDateKey(day))),
  ];
  if (<AsyncValue<Object?>>[
    ...entries,
    ...blooms,
  ].any((AsyncValue<Object?> value) => !value.hasValue)) {
    return null;
  }
  return coordinator.sync(
    enabled: true,
    schedule: plan.schedule,
    customTime: plan.customTime,
    now: now,
    days: <DateTime, ReminderDay>{
      for (int offset = 0; offset < days.length; offset++)
        days[offset]: ReminderDay(
          hasBloom: blooms[offset].requireValue?.mood != null,
          logCount: entries[offset].requireValue.length,
        ),
    },
  );
}

@Riverpod(keepAlive: true)
NotificationSettingsOpener notificationSettingsOpener(Ref ref) =>
    const ChannelNotificationSettingsOpener();

@Riverpod(keepAlive: true)
class ReminderPermissionStatus extends _$ReminderPermissionStatus {
  @override
  Future<ReminderPermission> build() =>
      _checkPermission(ref.watch(reminderSchedulerProvider));

  Future<void> askOnFirstLaunch() async {
    try {
      await ref
          .read(settingsRepositoryProvider)
          .setNotificationPermissionAsked(true);
    } catch (error) {
      debugPrint('Could not record the notification prompt: $error');
      return;
    }
    await _request();
  }

  Future<void> requestUnlessGranted() async {
    final ReminderPermission current = await _checkPermission(
      ref.read(reminderSchedulerProvider),
    );
    if (current == ReminderPermission.granted) {
      state = const AsyncData<ReminderPermission>(ReminderPermission.granted);
      return;
    }
    try {
      await ref
          .read(settingsRepositoryProvider)
          .setNotificationPermissionAsked(true);
    } catch (error) {
      debugPrint('Could not record the notification prompt: $error');
    }
    await _request();
  }

  Future<void> _request() async {
    try {
      await ref.read(reminderSchedulerProvider).requestPermission();
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
    }
    ref.invalidateSelf();
    ref.invalidate(reminderSyncProvider);
  }
}

Future<ReminderPermission> _checkPermission(ReminderScheduler scheduler) async {
  try {
    return await scheduler.permissionStatus();
  } catch (error) {
    debugPrint('Notification permission check failed: $error');
    return ReminderPermission.unknown;
  }
}
