import 'dart:async';

import 'package:field_notes/domain/settings/settings.dart';

class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({
    this.initial = AppSettings.defaults,
    this.writeError,
    this.storageMode = StorageMode.onDevice,
  });

  final AppSettings initial;
  final Object? writeError;

  @override
  final StorageMode storageMode;

  final StreamController<AppSettings> _settings =
      StreamController<AppSettings>.broadcast();
  final List<bool> reminderEnabledWrites = <bool>[];
  final List<ReminderTime> reminderTimeWrites = <ReminderTime>[];
  final List<bool> soundEnabledWrites = <bool>[];
  final List<TextSize> textSizeWrites = <TextSize>[];
  final List<WeekStart> weekStartWrites = <WeekStart>[];
  final List<bool> spellCheckEnabledWrites = <bool>[];

  void emit(AppSettings settings) => _settings.add(settings);

  @override
  Future<AppSettings> load() async => initial;

  @override
  Stream<AppSettings> watch() async* {
    yield initial;
    yield* _settings.stream;
  }

  @override
  Future<void> setReminderEnabled(bool value) async {
    _failIfConfigured();
    reminderEnabledWrites.add(value);
  }

  @override
  Future<void> setReminderTime(ReminderTime value) async {
    _failIfConfigured();
    reminderTimeWrites.add(value);
  }

  @override
  Future<void> setSoundEnabled(bool value) async {
    _failIfConfigured();
    soundEnabledWrites.add(value);
  }

  @override
  Future<void> setTextSize(TextSize value) async {
    _failIfConfigured();
    textSizeWrites.add(value);
  }

  @override
  Future<void> setWeekStart(WeekStart value) async {
    _failIfConfigured();
    weekStartWrites.add(value);
  }

  @override
  Future<void> setSpellCheckEnabled(bool value) async {
    _failIfConfigured();
    spellCheckEnabledWrites.add(value);
  }

  void _failIfConfigured() {
    final Object? error = writeError;
    if (error != null) {
      throw error;
    }
  }
}
