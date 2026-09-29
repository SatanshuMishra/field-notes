import 'onboarding_status.dart';
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
    required this.spellCheckEnabled,
    required this.notificationPermissionAsked,
    required this.reflectionPromptsEnabled,
    required this.onboardingStatus,
  });

  static const AppSettings defaults = AppSettings(
    reminderEnabled: true,
    reminderTime: ReminderTime.defaultTime,
    soundEnabled: true,
    textSize: TextSize.medium,
    weekStart: WeekStart.sunday,
    spellCheckEnabled: false,
    notificationPermissionAsked: false,
    reflectionPromptsEnabled: false,
    onboardingStatus: null,
  );

  final bool reminderEnabled;
  final ReminderTime reminderTime;
  final bool soundEnabled;
  final TextSize textSize;
  final WeekStart weekStart;
  final bool spellCheckEnabled;
  final bool notificationPermissionAsked;
  final bool reflectionPromptsEnabled;
  final OnboardingStatus? onboardingStatus;

  AppSettings copyWith({
    bool? reminderEnabled,
    ReminderTime? reminderTime,
    bool? soundEnabled,
    TextSize? textSize,
    WeekStart? weekStart,
    bool? spellCheckEnabled,
    bool? notificationPermissionAsked,
    bool? reflectionPromptsEnabled,
    OnboardingStatus? onboardingStatus,
  }) {
    return AppSettings(
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      textSize: textSize ?? this.textSize,
      weekStart: weekStart ?? this.weekStart,
      spellCheckEnabled: spellCheckEnabled ?? this.spellCheckEnabled,
      notificationPermissionAsked:
          notificationPermissionAsked ?? this.notificationPermissionAsked,
      reflectionPromptsEnabled:
          reflectionPromptsEnabled ?? this.reflectionPromptsEnabled,
      onboardingStatus: onboardingStatus ?? this.onboardingStatus,
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
          weekStart == other.weekStart &&
          spellCheckEnabled == other.spellCheckEnabled &&
          notificationPermissionAsked == other.notificationPermissionAsked &&
          reflectionPromptsEnabled == other.reflectionPromptsEnabled &&
          onboardingStatus == other.onboardingStatus;

  @override
  int get hashCode => Object.hash(
    reminderEnabled,
    reminderTime,
    soundEnabled,
    textSize,
    weekStart,
    spellCheckEnabled,
    notificationPermissionAsked,
    reflectionPromptsEnabled,
    onboardingStatus,
  );

  @override
  String toString() =>
      'AppSettings(reminderEnabled: $reminderEnabled, '
      'reminderTime: $reminderTime, soundEnabled: $soundEnabled, '
      'textSize: $textSize, weekStart: $weekStart, '
      'spellCheckEnabled: $spellCheckEnabled, '
      'notificationPermissionAsked: $notificationPermissionAsked, '
      'reflectionPromptsEnabled: $reflectionPromptsEnabled, '
      'onboardingStatus: $onboardingStatus)';
}
