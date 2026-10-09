import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/settings/drift_settings_repository.dart';
import 'package:field_notes/data/settings/journal_settings_store.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/domain/settings/settings.dart';

DriftSettingsRepository _settingsFor(AppDatabase db) {
  return DriftSettingsRepository(
    db,
    JournalSettingsStore(db, ChangeRecorder(db)),
  );
}

void main() {
  group('DriftSettingsRepository', () {
    late AppDatabase db;
    late DriftSettingsRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = _settingsFor(db);
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

    test(
      'a repeated setter upserts the key rather than duplicating it',
      () async {
        await repository.setTextSize(TextSize.small);
        await repository.setTextSize(TextSize.large);

        final rows = await db.select(db.settings).get();
        final textRows = rows.where((r) => r.key == 'text_size');
        expect(textRows.length, 1);
        expect((await repository.load()).textSize, TextSize.large);
      },
    );

    test('load falls back to defaults for malformed stored values', () async {
      await db
          .into(db.settings)
          .insert(
            SettingsCompanion.insert(
              key: 'reminder_time',
              value: 'not-a-number',
            ),
          );
      await db
          .into(db.settings)
          .insert(SettingsCompanion.insert(key: 'text_size', value: '9'));
      await db
          .into(db.journalSettings)
          .insert(
            JournalSettingsCompanion.insert(key: 'week_start', value: 'xyz'),
          );
      await db
          .into(db.settings)
          .insert(
            SettingsCompanion.insert(key: 'sound_enabled', value: 'maybe'),
          );

      final settings = await repository.load();
      expect(settings.reminderTime, ReminderTime.defaultTime);
      expect(settings.textSize, TextSize.medium);
      expect(settings.weekStart, WeekStart.sunday);
      expect(settings.soundEnabled, isTrue);
    });

    test(
      'watch emits the current settings and re-emits after a change',
      () async {
        final emissions = <AppSettings>[];
        final subscription = repository.watch().listen(emissions.add);
        addTearDown(subscription.cancel);

        await pumpEventQueue();
        await repository.setTextSize(TextSize.large);
        await pumpEventQueue();

        expect(emissions.first, AppSettings.defaults);
        expect(emissions.last.textSize, TextSize.large);
      },
    );

    test('a new store reports no onboarding status, reflection questions off and no stored values', () async {
      final settings = await repository.load();

      expect(settings.onboardingStatus, isNull);
      expect(settings.reflectionPromptsEnabled, isFalse);
      expect(await repository.hasStoredValues(), isFalse);
    });

    test(
      'Saturday, reflection questions and onboarding status survive a reload',
      () async {
        await repository.setWeekStart(WeekStart.saturday);
        await repository.setReflectionPromptsEnabled(true);
        await repository.setOnboardingStatus(OnboardingStatus.pending);
        await repository.setOnboardingStatus(OnboardingStatus.done);

        final reloaded = _settingsFor(db);
        final settings = await reloaded.load();

        expect(settings.weekStart, WeekStart.saturday);
        expect(settings.reflectionPromptsEnabled, isTrue);
        expect(settings.onboardingStatus, OnboardingStatus.done);
      },
    );

    test(
      'appearance defaults to light and dark and system survive a reload',
      () async {
        expect((await repository.load()).appearance, Appearance.light);

        await repository.setAppearance(Appearance.dark);
        expect((await _settingsFor(db).load()).appearance, Appearance.dark);

        await repository.setAppearance(Appearance.system);
        final List<Setting> rows = await db.select(db.settings).get();
        expect(
          rows.where((Setting row) => row.key == 'appearance').single.value,
          'system',
        );
        expect((await _settingsFor(db).load()).appearance, Appearance.system);
      },
    );

    test('an unknown stored appearance reads as light', () async {
      await db
          .into(db.settings)
          .insert(SettingsCompanion.insert(key: 'appearance', value: 'sepia'));

      expect((await repository.load()).appearance, Appearance.light);
    });

    test('any stored setting makes hasStoredValues true', () async {
      await repository.setSoundEnabled(false);

      expect(await repository.hasStoredValues(), isTrue);
    });

    test('the meadow key is made once and kept', () async {
      final int first = await repository.meadowKey();

      final List<JournalSetting> rows = await db
          .select(db.journalSettings)
          .get();
      expect(
        rows
            .where((JournalSetting row) => row.key == 'meadow_key')
            .single
            .value,
        '$first',
      );
      expect(await db.select(db.settings).get(), isEmpty);
      expect(first, inInclusiveRange(0, 4294967295));
      expect(await repository.meadowKey(), first);
      expect(await _settingsFor(db).meadowKey(), first);
    });

    test('a meadow key alone does not count as stored settings', () async {
      await repository.meadowKey();

      expect(await repository.hasStoredValues(), isFalse);
    });

    test('a stored meadow key at the top of the range is kept', () async {
      await db
          .into(db.journalSettings)
          .insert(
            JournalSettingsCompanion.insert(
              key: 'meadow_key',
              value: '4294967295',
            ),
          );

      expect(await repository.meadowKey(), 4294967295);
      final List<JournalSetting> rows = await db
          .select(db.journalSettings)
          .get();
      expect(
        rows
            .where((JournalSetting row) => row.key == 'meadow_key')
            .single
            .value,
        '4294967295',
      );
    });

    test(
      'week start and reflection questions are kept as journal settings',
      () async {
        await repository.setWeekStart(WeekStart.monday);
        await repository.setReflectionPromptsEnabled(true);

        final List<JournalSetting> journal = await db
            .select(db.journalSettings)
            .get();
        expect(
          <String, String>{
            for (final JournalSetting row in journal) row.key: row.value,
          },
          <String, String>{'week_start': '1', 'reflection_prompts': 'true'},
        );
        expect(await db.select(db.settings).get(), isEmpty);
      },
    );

    test('watch re-emits when a journal setting changes', () async {
      final emissions = <AppSettings>[];
      final subscription = repository.watch().listen(emissions.add);
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      await repository.setWeekStart(WeekStart.saturday);
      await pumpEventQueue();

      expect(emissions.first.weekStart, WeekStart.sunday);
      expect(emissions.last.weekStart, WeekStart.saturday);
    });

    test('a journal setting alone counts as stored settings', () async {
      await repository.setWeekStart(WeekStart.monday);

      expect(await repository.hasStoredValues(), isTrue);
    });

    test(
      'media is kept on a Mac by default and fetched on demand on a phone',
      () async {
        expect((await repository.load()).keepAllMediaOnDevice, isFalse);

        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        final bool onMac = (await repository.load()).keepAllMediaOnDevice;
        debugDefaultTargetPlatformOverride = null;

        expect(onMac, isTrue);
        expect((await repository.load()).allowMobileDataForMedia, isFalse);
      },
    );

    test('keeping all media on the device defaults on for Windows', () async {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      expect((await repository.load()).keepAllMediaOnDevice, isTrue);
    });

    test('the two media settings are saved on this device', () async {
      await repository.setKeepAllMediaOnDevice(true);
      await repository.setAllowMobileDataForMedia(true);

      final AppSettings reloaded = await _settingsFor(db).load();
      expect(reloaded.keepAllMediaOnDevice, isTrue);
      expect(reloaded.allowMobileDataForMedia, isTrue);
      final List<Setting> rows = await db.select(db.settings).get();
      expect(
        <String, String>{for (final Setting row in rows) row.key: row.value},
        <String, String>{
          'keep_all_media_on_device': 'true',
          'allow_mobile_data_for_media': 'true',
        },
      );
      expect(await db.select(db.journalSettings).get(), isEmpty);
    });
  });
}
