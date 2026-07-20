import '../settings/reminder_time.dart';

class ReminderService {
  const ReminderService();

  DateTime? nextReminderAt({
    required bool enabled,
    required ReminderTime time,
    required DateTime now,
    required bool todayHasEntry,
  }) {
    if (!enabled) {
      return null;
    }
    final DateTime todaySlot = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!todayHasEntry && todaySlot.isAfter(now)) {
      return todaySlot;
    }
    return DateTime(
      now.year,
      now.month,
      now.day + 1,
      time.hour,
      time.minute,
    );
  }
}
