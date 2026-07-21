import 'package:field_notes/features/reminders/reminder_scheduler.dart';

class RecordingReminderScheduler implements ReminderScheduler {
  final List<DateTime> scheduled = <DateTime>[];
  int cancelCount = 0;

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<void> schedule(DateTime at) async => scheduled.add(at);

  @override
  Future<void> cancel() async => cancelCount++;
}
