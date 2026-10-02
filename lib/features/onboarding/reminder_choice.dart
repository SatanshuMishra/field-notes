import 'package:field_notes/domain/settings/reminder_time.dart';

enum ReminderChoice {
  morning(ReminderTime(hour: 8, minute: 0), '08:00'),
  midday(ReminderTime(hour: 12, minute: 30), '12:30'),
  evening(ReminderTime(hour: 20, minute: 30), '20:30'),
  off(null, 'Off');

  const ReminderChoice(this.time, this.clock);

  final ReminderTime? time;
  final String clock;
}
