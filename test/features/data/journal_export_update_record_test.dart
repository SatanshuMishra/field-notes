import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/settings/drift_settings_repository.dart';
import 'package:field_notes/data/settings/journal_settings_store.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/data/updates/update_record_store.dart';
import 'package:field_notes/domain/services/export_service.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/features/data/journal_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

ReleaseInfo _release() {
  return ReleaseInfo(
    version: AppVersion(major: 1, minor: 4, patch: 0),
    tag: 'v1.4.0',
    publishedAt: DateTime.utc(2026, 10, 1, 12),
    notes: ReleaseNotes(intro: 'Small fixes.', groups: <ReleaseNoteGroup>[]),
    pageUrl: Uri.parse(
      'https://github.com/SatanshuMishra/field-notes/releases/tag/v1.4.0',
    ),
    assets: <ReleaseAsset>[],
  );
}

void main() {
  late AppDatabase db;
  late Directory root;
  late JournalExportService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('fn_export_update_record');
    service = JournalExportService(
      database: db,
      mediaStore: FilesystemMediaStore(
        database: db,
        recorder: ChangeRecorder(db),
        root: root,
      ),
      clock: () => 1760000000000,
    );
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('the journal export leaves the update record out', () async {
    final DriftSettingsRepository settings = DriftSettingsRepository(
      db,
      JournalSettingsStore(db, ChangeRecorder(db)),
    );
    await settings.setTextSize(TextSize.large);
    await settings.setAppearance(Appearance.dark);
    await settings.setMeadowPausesWhenInactive(false);
    await settings.setCheckForUpdatesAutomatically(false);
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: 'updates_banner_seen', value: 'true'),
        );

    final DriftUpdateRecordStore record = DriftUpdateRecordStore(db);
    await record.recordCheck(DateTime.utc(2026, 10, 11, 9, 30), _release());
    await record.recordSeenVersion('1.3.0');
    final List<Setting> stored = await db.select(db.settings).get();
    expect(
      stored.where((Setting row) => row.key.startsWith('update_')),
      hasLength(3),
    );

    final ExportBundle bundle = await service.buildBundle();
    final Map<String, Object?> journal =
        jsonDecode(bundle.journalJson) as Map<String, Object?>;
    final Map<String, Object?> exported =
        journal['settings']! as Map<String, Object?>;

    expect(exported, <String, Object?>{
      'text_size': '${TextSize.large.value}',
      'appearance': Appearance.dark.id,
      'meadow_pauses_when_inactive': 'false',
      'check_for_updates_automatically': 'false',
      'updates_banner_seen': 'true',
    });
    expect(
      exported.keys.where((String key) => key.startsWith('update_')),
      isEmpty,
    );
    expect(bundle.journalJson, isNot(contains('update_last')));
    expect(bundle.journalJson, isNot(contains('1.3.0')));
  });
}
