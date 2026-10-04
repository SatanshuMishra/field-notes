import 'appearance.dart';
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
    required this.appearance,
    this.sidebarCollapsed = false,
    this.meadowPausesWhenInactive = true,
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
    appearance: Appearance.light,
    sidebarCollapsed: false,
    meadowPausesWhenInactive: true,
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
  final Appearance appearance;
  final bool sidebarCollapsed;
  final bool meadowPausesWhenInactive;

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
    Appearance? appearance,
    bool? sidebarCollapsed,
    bool? meadowPausesWhenInactive,
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
      appearance: appearance ?? this.appearance,
      sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
      meadowPausesWhenInactive:
          meadowPausesWhenInactive ?? this.meadowPausesWhenInactive,
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
          onboardingStatus == other.onboardingStatus &&
          appearance == other.appearance &&
          sidebarCollapsed == other.sidebarCollapsed &&
          meadowPausesWhenInactive == other.meadowPausesWhenInactive;

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
    appearance,
    sidebarCollapsed,
    meadowPausesWhenInactive,
  );

  @override
  String toString() =>
      'AppSettings(reminderEnabled: $reminderEnabled, '
      'reminderTime: $reminderTime, soundEnabled: $soundEnabled, '
      'textSize: $textSize, weekStart: $weekStart, '
      'spellCheckEnabled: $spellCheckEnabled, '
      'notificationPermissionAsked: $notificationPermissionAsked, '
      'reflectionPromptsEnabled: $reflectionPromptsEnabled, '
      'onboardingStatus: $onboardingStatus, appearance: $appearance, '
      'sidebarCollapsed: $sidebarCollapsed, '
      'meadowPausesWhenInactive: $meadowPausesWhenInactive)';
}
