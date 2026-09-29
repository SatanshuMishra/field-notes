import 'dart:async';

import 'package:field_notes/domain/settings/settings.dart';

class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({
    this.initial = AppSettings.defaults,
    this.writeError,
    this.storageMode = StorageMode.onDevice,
    this.storedValues = true,
  });

  final AppSettings initial;
  final Object? writeError;
  final bool storedValues;

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
  final List<bool> notificationPermissionAskedWrites = <bool>[];
  final List<bool> reflectionPromptsEnabledWrites = <bool>[];
  final List<OnboardingStatus> onboardingStatusWrites = <OnboardingStatus>[];
  final List<Appearance> appearanceWrites = <Appearance>[];
  late AppSettings _latest = initial;

  void emit(AppSettings settings) {
    _latest = settings;
    _settings.add(settings);
  }

  @override
  Future<AppSettings> load() async => _latest;

  @override
  Stream<AppSettings> watch() async* {
    yield _latest;
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

  @override
  Future<void> setNotificationPermissionAsked(bool value) async {
    _failIfConfigured();
    notificationPermissionAskedWrites.add(value);
  }

  @override
  Future<void> setReflectionPromptsEnabled(bool value) async {
    _failIfConfigured();
    reflectionPromptsEnabledWrites.add(value);
  }

  @override
  Future<void> setOnboardingStatus(OnboardingStatus value) async {
    _failIfConfigured();
    onboardingStatusWrites.add(value);
  }

  @override
  Future<void> setAppearance(Appearance value) async {
    _failIfConfigured();
    appearanceWrites.add(value);
    emit(_latest.copyWith(appearance: value));
  }

  @override
  Future<bool> hasStoredValues() async => storedValues;

  void _failIfConfigured() {
    final Object? error = writeError;
    if (error != null) {
      throw error;
    }
  }
}
