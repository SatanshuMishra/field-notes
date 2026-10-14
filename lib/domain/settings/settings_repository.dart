import 'app_settings.dart';
import 'appearance.dart';
import 'input_profile.dart';
import 'onboarding_status.dart';
import 'reminder_time.dart';
import 'storage_mode.dart';
import 'text_size.dart';
import 'week_start.dart';

abstract interface class SettingsRepository {
  Future<AppSettings> load();

  Stream<AppSettings> watch();

  Future<void> setReminderEnabled(bool value);

  Future<void> setReminderTime(ReminderTime value);

  Future<void> setSoundEnabled(bool value);

  Future<void> setTextSize(TextSize value);

  Future<void> setWeekStart(WeekStart value);

  Future<void> setSpellCheckEnabled(bool value);

  Future<void> setNotificationPermissionAsked(bool value);

  Future<void> setReflectionPromptsEnabled(bool value);

  Future<void> setOnboardingStatus(OnboardingStatus value);

  Future<void> setAppearance(Appearance value);

  Future<void> setSidebarCollapsed(bool value);

  Future<void> setMeadowPausesWhenInactive(bool value);

  Future<void> setKeepAllMediaOnDevice(bool value);

  Future<void> setAllowMobileDataForMedia(bool value);

  Future<void> setCheckForUpdatesAutomatically(bool value);

  Future<void> setAudioInputId(String? value);

  Future<void> setInputProfile(InputProfile value);

  Future<void> setInputVolume(int value);

  Future<bool> hasStoredValues();

  Future<int> meadowKey();

  StorageMode get storageMode;
}
