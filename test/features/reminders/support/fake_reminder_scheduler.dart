import 'dart:async';

import 'package:field_notes/features/reminders/reminder_scheduler.dart';

class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({
    this.permissionGranted = true,
    this.scheduleError,
    this.scheduleGate,
  });

  final bool permissionGranted;
  final Object? scheduleError;
  final Completer<void>? scheduleGate;
  final List<DateTime> scheduled = <DateTime>[];
  final List<String> calls = <String>[];
  int permissionRequests = 0;
  int cancelCount = 0;

  @override
  Future<bool> ensurePermission() async {
    permissionRequests++;
    calls.add('permission');
    return permissionGranted;
  }

  @override
  Future<void> schedule(DateTime at) async {
    calls.add('schedule');
    final Completer<void>? gate = scheduleGate;
    if (gate != null) {
      await gate.future;
    }
    final Object? error = scheduleError;
    if (error != null) {
      throw error;
    }
    scheduled.add(at);
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    calls.add('cancel');
  }
}
