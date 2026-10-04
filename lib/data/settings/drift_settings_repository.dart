import 'dart:math';

import 'package:drift/drift.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/domain/settings/settings.dart';

import 'settings_keys.dart';

const String _trueValue = 'true';
const String _falseValue = 'false';
const int _meadowKeyLimit = 1 << 32;

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

  @override
  Future<void> setNotificationPermissionAsked(bool value) => _put(
    SettingsKeys.notificationPermissionAsked,
    value ? _trueValue : _falseValue,
  );

  @override
  Future<void> setReflectionPromptsEnabled(bool value) =>
      _put(SettingsKeys.reflectionPrompts, value ? _trueValue : _falseValue);

  @override
  Future<void> setOnboardingStatus(OnboardingStatus value) =>
      _put(SettingsKeys.onboardingStatus, value.id);

  @override
  Future<void> setAppearance(Appearance value) =>
      _put(SettingsKeys.appearance, value.id);

  @override
  Future<void> setSidebarCollapsed(bool value) =>
      _put(SettingsKeys.sidebarCollapsed, value ? _trueValue : _falseValue);

  @override
  Future<void> setMeadowPausesWhenInactive(bool value) => _put(
    SettingsKeys.meadowPausesWhenInactive,
    value ? _trueValue : _falseValue,
  );

  @override
  Future<bool> hasStoredValues() async {
    final List<Setting> rows = await (_db.select(
      _db.settings,
    )..where((t) => t.key.isNotValue(SettingsKeys.meadowKey))).get();
    return rows.isNotEmpty;
  }

  @override
  Future<int> meadowKey() async {
    final int? stored = _decodeMeadowKey(await _readMeadowKey());
    if (stored != null) {
      return stored;
    }
    await _db
        .into(_db.settings)
        .insert(
          SettingsCompanion.insert(
            key: SettingsKeys.meadowKey,
            value: Random.secure().nextInt(_meadowKeyLimit).toString(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    final int? kept = _decodeMeadowKey(await _readMeadowKey());
    if (kept == null) {
      throw StateError(
        'The stored meadow key is not a whole number from 0 to 4294967295.',
      );
    }
    return kept;
  }

  Future<String?> _readMeadowKey() async {
    final Setting? row = await (_db.select(
      _db.settings,
    )..where((t) => t.key.equals(SettingsKeys.meadowKey))).getSingleOrNull();
    return row?.value;
  }

  int? _decodeMeadowKey(String? raw) {
    final int? key = int.tryParse(raw ?? '');
    if (key == null || key < 0 || key >= _meadowKeyLimit) {
      return null;
    }
    return key;
  }

  Future<void> _put(String key, String value) async {
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: key, value: value),
        );
  }

  AppSettings _decode(List<Setting> rows) {
    final values = <String, String>{for (final row in rows) row.key: row.value};
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
      textSize:
          TextSize.fromValue(
            int.tryParse(values[SettingsKeys.textSize] ?? ''),
          ) ??
          defaults.textSize,
      weekStart:
          WeekStart.fromValue(
            int.tryParse(values[SettingsKeys.weekStart] ?? ''),
          ) ??
          defaults.weekStart,
      spellCheckEnabled: _decodeBool(
        values[SettingsKeys.spellCheck],
        defaults.spellCheckEnabled,
      ),
      notificationPermissionAsked: _decodeBool(
        values[SettingsKeys.notificationPermissionAsked],
        defaults.notificationPermissionAsked,
      ),
      reflectionPromptsEnabled: _decodeBool(
        values[SettingsKeys.reflectionPrompts],
        defaults.reflectionPromptsEnabled,
      ),
      onboardingStatus: OnboardingStatus.fromId(
        values[SettingsKeys.onboardingStatus],
      ),
      appearance:
          Appearance.fromId(values[SettingsKeys.appearance]) ??
          defaults.appearance,
      sidebarCollapsed: _decodeBool(
        values[SettingsKeys.sidebarCollapsed],
        defaults.sidebarCollapsed,
      ),
      meadowPausesWhenInactive: _decodeBool(
        values[SettingsKeys.meadowPausesWhenInactive],
        defaults.meadowPausesWhenInactive,
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
