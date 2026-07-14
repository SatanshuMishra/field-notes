import 'reminder_time.dart';
import 'text_size.dart';
import 'week_start.dart';

class AppSettings {
  const AppSettings({
    required this.reminderEnabled,
    required this.reminderTime,
    required this.soundEnabled,
    required this.textSize,
    required this.weekStart,
  });

  static const AppSettings defaults = AppSettings(
    reminderEnabled: true,
    reminderTime: ReminderTime.defaultTime,
    soundEnabled: true,
    textSize: TextSize.medium,
    weekStart: WeekStart.sunday,
  );

  final bool reminderEnabled;
  final ReminderTime reminderTime;
  final bool soundEnabled;
  final TextSize textSize;
  final WeekStart weekStart;

  AppSettings copyWith({
    bool? reminderEnabled,
    ReminderTime? reminderTime,
    bool? soundEnabled,
    TextSize? textSize,
    WeekStart? weekStart,
  }) {
    return AppSettings(
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      textSize: textSize ?? this.textSize,
      weekStart: weekStart ?? this.weekStart,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          reminderEnabled == other.reminderEnabled &&
          reminderTime == other.reminderTime &&
          soundEnabled == other.soundEnabled &&
          textSize == other.textSize &&
          weekStart == other.weekStart;

  @override
  int get hashCode => Object.hash(
        reminderEnabled,
        reminderTime,
        soundEnabled,
        textSize,
        weekStart,
      );

  @override
  String toString() =>
      'AppSettings(reminderEnabled: $reminderEnabled, '
      'reminderTime: $reminderTime, soundEnabled: $soundEnabled, '
      'textSize: $textSize, weekStart: $weekStart)';
}
