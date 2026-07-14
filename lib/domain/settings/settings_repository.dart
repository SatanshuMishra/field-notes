import 'app_settings.dart';
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

  StorageMode get storageMode;
}
