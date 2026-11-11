import 'package:field_notes/domain/services/reminder_service.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:flutter/foundation.dart';

import 'reminder_scheduler.dart';

enum ReminderSyncResult {
  scheduled,
  cancelled,
  permissionDenied,
  superseded,
  failed,
}

typedef ReminderErrorHandler = void Function(
  Object error,
  StackTrace stackTrace,
);

class ReminderCoordinator {
  ReminderCoordinator({
    required this._scheduler,
    this._service = const ReminderService(),
    this._onError,
  });

  final ReminderScheduler _scheduler;
  final ReminderService _service;
  final ReminderErrorHandler? _onError;

  Future<void> _pending = Future<void>.value();
  int _generation = 0;
  List<ReminderBooking>? _applied;

  Future<ReminderSyncResult> sync({
    required bool enabled,
    required ReminderSchedule schedule,
    required ReminderTime customTime,
    required DateTime now,
    Map<DateTime, ReminderDay> days = const <DateTime, ReminderDay>{},
  }) {
    final int generation = ++_generation;
    final Future<ReminderSyncResult> result = _pending.then(
      (void _) => _run(
        generation: generation,
        enabled: enabled,
        schedule: schedule,
        customTime: customTime,
        now: now,
        days: days,
      ),
    );
    _pending = result.then<void>((ReminderSyncResult _) {});
    return result;
  }

  Future<ReminderSyncResult> _run({
    required int generation,
    required bool enabled,
    required ReminderSchedule schedule,
    required ReminderTime customTime,
    required DateTime now,
    required Map<DateTime, ReminderDay> days,
  }) async {
    if (generation != _generation) {
      return ReminderSyncResult.superseded;
    }
    try {
      final List<ReminderBooking> bookings =
          _service.upcomingReminders(
            enabled: enabled,
            schedule: schedule,
            customTime: customTime,
            now: now,
            days: days,
          ) ??
          const <ReminderBooking>[];
      if (bookings.isEmpty) {
        await _clear();
        return ReminderSyncResult.cancelled;
      }
      if (listEquals(bookings, _applied)) {
        return ReminderSyncResult.scheduled;
      }
      final ReminderPermission permission = await _scheduler.permissionStatus();
      if (permission == ReminderPermission.denied) {
        await _clear();
        return ReminderSyncResult.permissionDenied;
      }
      _applied = null;
      final bool settled = await _scheduler.schedule(bookings);
      _applied = settled ? bookings : null;
      return ReminderSyncResult.scheduled;
    } catch (error, stackTrace) {
      _applied = null;
      _onError?.call(error, stackTrace);
      return ReminderSyncResult.failed;
    }
  }

  Future<void> _clear() async {
    if (_applied case final List<ReminderBooking> applied
        when applied.isEmpty) {
      return;
    }
    _applied = null;
    final bool settled = await _scheduler.cancel();
    _applied = settled ? const <ReminderBooking>[] : null;
  }
}
