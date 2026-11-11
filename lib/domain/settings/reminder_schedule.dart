enum ReminderSchedule {
  evenings('evenings'),
  middayAndEvening('midday_and_evening'),
  custom('custom');

  const ReminderSchedule(this.id);

  final String id;

  static ReminderSchedule? fromId(String? id) {
    for (final ReminderSchedule schedule in ReminderSchedule.values) {
      if (schedule.id == id) {
        return schedule;
      }
    }
    return null;
  }
}
