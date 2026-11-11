import 'dart:async';

import 'package:field_notes/domain/services/reminder_service.dart';
import 'package:field_notes/features/reminders/reminder_scheduler.dart';

class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({
    this.permissionGranted = true,
    this.grantOnRequest = false,
    this.scheduleError,
    this.scheduleGate,
    this.unsettledSchedules = 0,
    this.unsettledCancels = 0,
  });

  bool permissionGranted;
  final bool grantOnRequest;
  final Object? scheduleError;
  final Completer<void>? scheduleGate;
  int unsettledSchedules;
  int unsettledCancels;
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
    if (grantOnRequest) {
      permissionGranted = true;
    }
    return permissionGranted;
  }

  @override
  Future<bool> schedule(List<ReminderBooking> bookings) async {
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
    if (unsettledSchedules > 0) {
      unsettledSchedules--;
      return false;
    }
    return true;
  }

  @override
  Future<bool> cancel() async {
    cancelCount++;
    calls.add('cancel');
    if (unsettledCancels > 0) {
      unsettledCancels--;
      return false;
    }
    return true;
  }
}
