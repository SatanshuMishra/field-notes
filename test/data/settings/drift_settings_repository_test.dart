import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/settings/drift_settings_repository.dart';
import 'package:field_notes/domain/settings/settings.dart';

void main() {
  group('DriftSettingsRepository', () {
    late AppDatabase db;
    late DriftSettingsRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = DriftSettingsRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('load returns the defaults for an empty settings table', () async {
      expect(await repository.load(), AppSettings.defaults);
    });

    test('storageMode is locked to on_device', () {
      expect(repository.storageMode, StorageMode.onDevice);
    });

    test('setReminderEnabled persists and load reflects it', () async {
      await repository.setReminderEnabled(false);
      expect((await repository.load()).reminderEnabled, isFalse);
    });

    test('setReminderTime round-trips through storage', () async {
      await repository.setReminderTime(const ReminderTime(hour: 7, minute: 5));
      expect(
        (await repository.load()).reminderTime,
        const ReminderTime(hour: 7, minute: 5),
      );
    });

    test('setSoundEnabled persists and load reflects it', () async {
      await repository.setSoundEnabled(false);
      expect((await repository.load()).soundEnabled, isFalse);
    });

    test('setTextSize persists and load reflects it', () async {
      await repository.setTextSize(TextSize.large);
      expect((await repository.load()).textSize, TextSize.large);
    });

    test('setWeekStart persists and load reflects it', () async {
      await repository.setWeekStart(WeekStart.monday);
      expect((await repository.load()).weekStart, WeekStart.monday);
    });

    test('a repeated setter upserts the key rather than duplicating it',
        () async {
      await repository.setTextSize(TextSize.small);
      await repository.setTextSize(TextSize.large);

      final rows = await db.select(db.settings).get();
      final textRows = rows.where((r) => r.key == 'text_size');
      expect(textRows.length, 1);
      expect((await repository.load()).textSize, TextSize.large);
    });

    test('load falls back to defaults for malformed stored values', () async {
      await db.into(db.settings).insert(
            SettingsCompanion.insert(
              key: 'reminder_time',
              value: 'not-a-number',
            ),
          );
      await db.into(db.settings).insert(
            SettingsCompanion.insert(key: 'text_size', value: '9'),
          );
      await db.into(db.settings).insert(
            SettingsCompanion.insert(key: 'week_start', value: 'xyz'),
          );
      await db.into(db.settings).insert(
            SettingsCompanion.insert(key: 'sound_enabled', value: 'maybe'),
          );

      final settings = await repository.load();
      expect(settings.reminderTime, ReminderTime.defaultTime);
      expect(settings.textSize, TextSize.medium);
      expect(settings.weekStart, WeekStart.sunday);
      expect(settings.soundEnabled, isTrue);
    });

    test('watch emits the current settings and re-emits after a change',
        () async {
      final emissions = <AppSettings>[];
      final subscription = repository.watch().listen(emissions.add);
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      await repository.setTextSize(TextSize.large);
      await pumpEventQueue();

      expect(emissions.first, AppSettings.defaults);
      expect(emissions.last.textSize, TextSize.large);
    });
  });
}
