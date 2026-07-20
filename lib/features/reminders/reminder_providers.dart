import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'local_notifications_reminder_scheduler.dart';
import 'reminder_coordinator.dart';
import 'reminder_date.dart';
import 'reminder_scheduler.dart';

part 'reminder_providers.g.dart';

@Riverpod(keepAlive: true)
DateTime Function() reminderClock(Ref ref) => DateTime.now;

@Riverpod(keepAlive: true)
ReminderScheduler reminderScheduler(Ref ref) =>
    LocalNotificationsReminderScheduler();

@Riverpod(keepAlive: true)
ReminderCoordinator reminderCoordinator(Ref ref) => ReminderCoordinator(
      scheduler: ref.watch(reminderSchedulerProvider),
      onError: (Object error, StackTrace _) =>
          debugPrint('Reminder scheduling failed: $error'),
    );

@Riverpod(keepAlive: true)
Future<ReminderSyncResult?> reminderSync(Ref ref) async {
  final AppSettings? settings = ref.watch(appSettingsProvider).value;
  if (settings == null) {
    return null;
  }
  final DateTime now = ref.watch(reminderClockProvider)();
  final List<Entry>? entries =
      ref.watch(entriesForDateProvider(reminderDateKey(now))).value;
  if (entries == null) {
    return null;
  }
  return ref.watch(reminderCoordinatorProvider).sync(
        enabled: settings.reminderEnabled,
        time: settings.reminderTime,
        now: now,
        todayHasEntry: entries.isNotEmpty,
      );
}
