import 'package:field_notes/domain/settings/reminder_schedule.dart';

enum ReminderChoice {
  evenings(ReminderSchedule.evenings),
  middayAndEvening(ReminderSchedule.middayAndEvening),
  custom(ReminderSchedule.custom),
  off(null);

  const ReminderChoice(this.schedule);

  final ReminderSchedule? schedule;
}
