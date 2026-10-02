import 'package:field_notes/domain/settings/reminder_time.dart';

enum ReminderChoice {
  morning(ReminderTime(hour: 8, minute: 0)),
  midday(ReminderTime(hour: 12, minute: 30)),
  evening(ReminderTime(hour: 20, minute: 30)),
  off(null);

  const ReminderChoice(this.time);

  final ReminderTime? time;
}
