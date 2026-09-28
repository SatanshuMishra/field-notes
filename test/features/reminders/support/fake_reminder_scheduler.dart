import 'dart:async';

import 'package:field_notes/domain/services/reminder_service.dart';
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
  final List<ReminderBooking> scheduled = <ReminderBooking>[];
  final List<String> calls = <String>[];
  int permissionRequests = 0;
  int statusChecks = 0;
  int cancelCount = 0;

  @override
  Future<ReminderPermission> permissionStatus() async {
    statusChecks++;
    calls.add('permission');
    return permissionGranted
        ? ReminderPermission.granted
        : ReminderPermission.denied;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    calls.add('request');
    return permissionGranted;
  }

  @override
  Future<void> schedule(List<ReminderBooking> bookings) async {
    calls.add('schedule');
    final Completer<void>? gate = scheduleGate;
    if (gate != null) {
      await gate.future;
    }
    final Object? error = scheduleError;
    if (error != null) {
      throw error;
    }
    scheduled.addAll(bookings);
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    calls.add('cancel');
  }
}
