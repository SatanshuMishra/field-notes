import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/domain/settings/settings.dart';

import 'settings_keys.dart';

const String _trueValue = 'true';
const String _falseValue = 'false';

class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db);

  final AppDatabase _db;

  @override
  StorageMode get storageMode => StorageMode.onDevice;

  @override
  Future<AppSettings> load() async {
    final rows = await _db.select(_db.settings).get();
    return _decode(rows);
  }

  @override
  Stream<AppSettings> watch() {
    return _db.select(_db.settings).watch().map(_decode);
  }

  @override
  Future<void> setReminderEnabled(bool value) =>
      _put(SettingsKeys.reminderEnabled, value ? _trueValue : _falseValue);

  @override
  Future<void> setReminderTime(ReminderTime value) =>
      _put(SettingsKeys.reminderTime, value.minutesSinceMidnight.toString());

  @override
  Future<void> setSoundEnabled(bool value) =>
      _put(SettingsKeys.soundEnabled, value ? _trueValue : _falseValue);

  @override
  Future<void> setTextSize(TextSize value) =>
      _put(SettingsKeys.textSize, value.value.toString());

  @override
  Future<void> setWeekStart(WeekStart value) =>
      _put(SettingsKeys.weekStart, value.value.toString());

  @override
  Future<void> setSpellCheckEnabled(bool value) =>
      _put(SettingsKeys.spellCheck, value ? _trueValue : _falseValue);

  Future<void> _put(String key, String value) async {
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(key: key, value: value),
        );
  }

  AppSettings _decode(List<Setting> rows) {
    final values = <String, String>{
      for (final row in rows) row.key: row.value,
    };
    const defaults = AppSettings.defaults;
    return AppSettings(
      reminderEnabled: _decodeBool(
        values[SettingsKeys.reminderEnabled],
        defaults.reminderEnabled,
      ),
      reminderTime: _decodeReminderTime(values[SettingsKeys.reminderTime]),
      soundEnabled: _decodeBool(
        values[SettingsKeys.soundEnabled],
        defaults.soundEnabled,
      ),
      textSize: TextSize.fromValue(
            int.tryParse(values[SettingsKeys.textSize] ?? ''),
          ) ??
          defaults.textSize,
      weekStart: WeekStart.fromValue(
            int.tryParse(values[SettingsKeys.weekStart] ?? ''),
          ) ??
          defaults.weekStart,
      spellCheckEnabled: _decodeBool(
        values[SettingsKeys.spellCheck],
        defaults.spellCheckEnabled,
      ),
    );
  }

  bool _decodeBool(String? raw, bool fallback) {
    if (raw == _trueValue) {
      return true;
    }
    if (raw == _falseValue) {
      return false;
    }
    return fallback;
  }

  ReminderTime _decodeReminderTime(String? raw) {
    final minutes = int.tryParse(raw ?? '');
    if (minutes == null) {
      return AppSettings.defaults.reminderTime;
    }
    return ReminderTime.fromMinutes(minutes) ??
        AppSettings.defaults.reminderTime;
  }
}
