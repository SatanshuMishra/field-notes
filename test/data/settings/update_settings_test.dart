import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/settings/drift_settings_repository.dart';
import 'package:field_notes/data/settings/journal_settings_store.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/data/updates/update_record_store.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/features/settings/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/settings/support/fake_settings_repository.dart';

DriftSettingsRepository _settingsFor(AppDatabase db) {
  return DriftSettingsRepository(
    db,
    JournalSettingsStore(db, ChangeRecorder(db)),
  );
}

ReleaseInfo _release() {
  return ReleaseInfo(
    version: AppVersion(major: 1, minor: 4, patch: 0),
    tag: 'v1.4.0',
    publishedAt: DateTime.utc(2026, 10, 1, 12),
    notes: ReleaseNotes(
      intro: 'Small fixes.',
      groups: <ReleaseNoteGroup>[
        ReleaseNoteGroup(
          title: 'Fixed',
          items: <String>['Drafts are saved before a restart.'],
        ),
      ],
    ),
    pageUrl: Uri.parse(
      'https://github.com/SatanshuMishra/field-notes/releases/tag/v1.4.0',
    ),
    assets: <ReleaseAsset>[
      ReleaseAsset(
        name: 'field-notes-1.4.0-macos.dmg',
        url: Uri.parse(
          'https://github.com/SatanshuMishra/field-notes/releases/download/'
          'v1.4.0/field-notes-1.4.0-macos.dmg',
        ),
        size: 4096,
      ),
    ],
  );
}

Future<Map<String, String>> _deviceRows(AppDatabase db) async {
  final List<Setting> rows = await db.select(db.settings).get();
  return <String, String>{for (final Setting row in rows) row.key: row.value};
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('check automatically is on by default and remembered', () async {
    expect(AppSettings.defaults.checkForUpdatesAutomatically, isTrue);
    expect(
      const AppSettings(
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
      ).checkForUpdatesAutomatically,
      isTrue,
    );

    final DriftSettingsRepository fresh = _settingsFor(db);
    expect((await fresh.load()).checkForUpdatesAutomatically, isTrue);
    expect((await fresh.watch().first).checkForUpdatesAutomatically, isTrue);

    await fresh.setCheckForUpdatesAutomatically(false);

    final DriftSettingsRepository restarted = _settingsFor(db);
    final AppSettings reloaded = await restarted.load();
    expect(reloaded.checkForUpdatesAutomatically, isFalse);
    expect(
      (await restarted.watch().first).checkForUpdatesAutomatically,
      isFalse,
    );
    expect(
      reloaded,
      (await fresh.load()).copyWith(checkForUpdatesAutomatically: false),
    );
    expect(await _deviceRows(db), <String, String>{
      'check_for_updates_automatically': 'false',
    });
    expect(await db.select(db.journalSettings).get(), isEmpty);
    expect(await db.select(db.syncOutbox).get(), isEmpty);

    await restarted.setCheckForUpdatesAutomatically(true);
    expect(
      (await _settingsFor(db).load()).checkForUpdatesAutomatically,
      isTrue,
    );
    expect(await _deviceRows(db), <String, String>{
      'check_for_updates_automatically': 'true',
    });

    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: 'check_for_updates_automatically',
            value: 'sometimes',
          ),
        );
    expect(
      (await _settingsFor(db).load()).checkForUpdatesAutomatically,
      isTrue,
    );
  });

  test(
    'an install holding only the update record still counts as fresh',
    () async {
      final DriftSettingsRepository settings = _settingsFor(db);
      expect(await settings.hasStoredValues(), isFalse);
      final AppSettings before = await settings.load();

      final DriftUpdateRecordStore record = DriftUpdateRecordStore(db);
      await record.recordCheck(DateTime.utc(2026, 10, 11, 9, 30), _release());
      await record.recordAttempt(DateTime.utc(2026, 10, 11, 10));
      await record.recordSeenVersion('1.3.0');

      expect((await _deviceRows(db)).keys.toSet(), <String>{
        'update_last_checked_at',
        'update_last_available',
        'update_last_seen_version',
      });
      expect(await settings.hasStoredValues(), isFalse);
      expect(await _settingsFor(db).hasStoredValues(), isFalse);
      expect(await settings.load(), before);
      expect(await db.select(db.journalSettings).get(), isEmpty);
      expect(await db.select(db.syncOutbox).get(), isEmpty);

      await settings.setCheckForUpdatesAutomatically(true);
      expect(await settings.hasStoredValues(), isTrue);
    },
  );

  test(
    'an install with only a journal setting beside the update record is set up',
    () async {
      final DriftSettingsRepository settings = _settingsFor(db);
      await DriftUpdateRecordStore(db).recordSeenVersion('1.3.0');
      expect(await settings.hasStoredValues(), isFalse);

      await settings.setWeekStart(WeekStart.monday);
      expect(await settings.hasStoredValues(), isTrue);
    },
  );

  test('the settings controller saves check automatically and reports a failed write', () async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    final SettingsController controller = SettingsController(
      repository: repository,
    );

    final SettingsWriteResult saved = await controller
        .setCheckForUpdatesAutomatically(false);
    expect(saved, isA<SettingsWriteSucceeded>());
    expect(repository.checkForUpdatesAutomaticallyWrites, <bool>[false]);
    expect((await repository.load()).checkForUpdatesAutomatically, isFalse);

    final List<Object> errors = <Object>[];
    final SettingsController failing = SettingsController(
      repository: FakeSettingsRepository(writeError: StateError('disk full')),
      onError: (Object error, StackTrace stackTrace) => errors.add(error),
    );
    final SettingsWriteResult failed = await failing
        .setCheckForUpdatesAutomatically(true);
    expect(failed, isA<SettingsWriteFailed>());
    expect(
      (failed as SettingsWriteFailed).message,
      'Could not save your update check setting.',
    );
    expect(errors, hasLength(1));
  });
}
