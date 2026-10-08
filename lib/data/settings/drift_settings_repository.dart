import 'dart:math';

import 'package:drift/drift.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/settings/journal_settings_store.dart';
import 'package:field_notes/domain/platform/desktop_platform.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:flutter/foundation.dart';

import 'settings_keys.dart';

const String _trueValue = 'true';
const String _falseValue = 'false';
const int _meadowKeyLimit = 1 << 32;
const String _storedValuesQuery =
    'SELECT key, value, 0 AS journal FROM settings '
    'UNION ALL SELECT key, value, 1 AS journal FROM journal_settings';

class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db, this._journal);

  final AppDatabase _db;
  final JournalSettingsStore _journal;

  @override
  StorageMode get storageMode => StorageMode.onDevice;

  @override
  Future<AppSettings> load() async {
    return _decode(await _storedValues().get());
  }

  @override
  Stream<AppSettings> watch() {
    return _storedValues().watch().map(_decode);
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
      _journal.put(SettingsKeys.weekStart, value.value.toString());

  @override
  Future<void> setSpellCheckEnabled(bool value) =>
      _put(SettingsKeys.spellCheck, value ? _trueValue : _falseValue);

  @override
  Future<void> setNotificationPermissionAsked(bool value) => _put(
    SettingsKeys.notificationPermissionAsked,
    value ? _trueValue : _falseValue,
  );

  @override
  Future<void> setReflectionPromptsEnabled(bool value) => _journal.put(
    SettingsKeys.reflectionPrompts,
    value ? _trueValue : _falseValue,
  );

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
  Future<void> setKeepAllMediaOnDevice(bool value) =>
      _put(SettingsKeys.keepAllMediaOnDevice, value ? _trueValue : _falseValue);

  @override
  Future<void> setAllowMobileDataForMedia(bool value) => _put(
    SettingsKeys.allowMobileDataForMedia,
    value ? _trueValue : _falseValue,
  );

  @override
  Future<bool> hasStoredValues() async {
    final List<Setting> device = await _db.select(_db.settings).get();
    final List<JournalSetting> journal = await (_db.select(
      _db.journalSettings,
    )..where((t) => t.key.isNotValue(SettingsKeys.meadowKey))).get();
    return device.isNotEmpty || journal.isNotEmpty;
  }

  @override
  Future<int> meadowKey() {
    return _db.transaction(() async {
      final String? stored = await _journal.read(SettingsKeys.meadowKey);
      if (stored == null) {
        final int created = Random.secure().nextInt(_meadowKeyLimit);
        await _journal.put(SettingsKeys.meadowKey, created.toString());
        return created;
      }
      final int? kept = _decodeMeadowKey(stored);
      if (kept == null) {
        throw StateError(
          'The stored meadow key is not a whole number from 0 to 4294967295.',
        );
      }
      return kept;
    });
  }

  Selectable<QueryRow> _storedValues() {
    return _db.customSelect(
      _storedValuesQuery,
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        _db.settings,
        _db.journalSettings,
      },
    );
  }

  int? _decodeMeadowKey(String raw) {
    final int? key = int.tryParse(raw);
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

  AppSettings _decode(List<QueryRow> rows) {
    final Map<String, String> values = <String, String>{
      for (final QueryRow row in rows)
        if (row.read<int>('journal') == 0)
          row.read<String>('key'): row.read<String>('value'),
    };
    final Map<String, String> journal = <String, String>{
      for (final QueryRow row in rows)
        if (row.read<int>('journal') == 1)
          row.read<String>('key'): row.read<String>('value'),
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
      textSize:
          TextSize.fromValue(
            int.tryParse(values[SettingsKeys.textSize] ?? ''),
          ) ??
          defaults.textSize,
      weekStart:
          WeekStart.fromValue(
            int.tryParse(journal[SettingsKeys.weekStart] ?? ''),
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
        journal[SettingsKeys.reflectionPrompts],
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
      keepAllMediaOnDevice: _decodeBool(
        values[SettingsKeys.keepAllMediaOnDevice],
        isDesktopPlatform(defaultTargetPlatform),
      ),
      allowMobileDataForMedia: _decodeBool(
        values[SettingsKeys.allowMobileDataForMedia],
        defaults.allowMobileDataForMedia,
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
