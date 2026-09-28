import 'package:field_notes/domain/services/reminder_service.dart';
import 'package:field_notes/domain/settings/settings.dart';

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

  Future<ReminderSyncResult> sync({
    required bool enabled,
    required ReminderTime time,
    required DateTime now,
    required bool todayHasEntry,
    Set<DateTime> daysWithEntries = const <DateTime>{},
  }) {
    final int generation = ++_generation;
    final Future<ReminderSyncResult> result = _pending.then(
      (void _) => _run(
        generation: generation,
        enabled: enabled,
        time: time,
        now: now,
        todayHasEntry: todayHasEntry,
        daysWithEntries: daysWithEntries,
      ),
    );
    _pending = result.then<void>((ReminderSyncResult _) {});
    return result;
  }

  Future<ReminderSyncResult> _run({
    required int generation,
    required bool enabled,
    required ReminderTime time,
    required DateTime now,
    required bool todayHasEntry,
    required Set<DateTime> daysWithEntries,
  }) async {
    if (generation != _generation) {
      return ReminderSyncResult.superseded;
    }
    try {
      final List<ReminderBooking>? bookings = _service.upcomingReminders(
        enabled: enabled,
        time: time,
        now: now,
        todayHasEntry: todayHasEntry,
        daysWithEntries: daysWithEntries,
      );
      if (bookings == null || bookings.isEmpty) {
        await _scheduler.cancel();
        return ReminderSyncResult.cancelled;
      }
      final ReminderPermission permission =
          await _scheduler.permissionStatus();
      if (permission == ReminderPermission.denied) {
        await _scheduler.cancel();
        return ReminderSyncResult.permissionDenied;
      }
      await _scheduler.schedule(bookings);
      return ReminderSyncResult.scheduled;
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
      return ReminderSyncResult.failed;
    }
  }
}
