class ReminderTime {
  const ReminderTime({required this.hour, required this.minute})
      : assert(hour >= 0 && hour < 24, 'hour must be in 0..23'),
        assert(minute >= 0 && minute < 60, 'minute must be in 0..59');

  static const ReminderTime defaultTime = ReminderTime(hour: 20, minute: 30);

  final int hour;
  final int minute;

  int get minutesSinceMidnight => hour * 60 + minute;

  static ReminderTime? fromMinutes(int minutes) {
    if (minutes < 0 || minutes > 1439) {
      return null;
    }
    return ReminderTime(hour: minutes ~/ 60, minute: minutes % 60);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderTime &&
          runtimeType == other.runtimeType &&
          hour == other.hour &&
          minute == other.minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => 'ReminderTime(hour: $hour, minute: $minute)';
}
