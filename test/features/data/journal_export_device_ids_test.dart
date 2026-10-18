import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/settings/drift_settings_repository.dart';
import 'package:field_notes/data/settings/journal_settings_store.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/domain/services/export_service.dart';
import 'package:field_notes/features/data/journal_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late JournalExportService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('fn_export_device_ids');
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

  test('the journal export leaves the audio device ids out', () async {
    final DriftSettingsRepository settings = DriftSettingsRepository(
      db,
      JournalSettingsStore(db, ChangeRecorder(db)),
    );
    await settings.setAudioOutputId('8:WH-1000XM5:AA:BB:CC:DD:EE:FF');
    await settings.setAudioInputId('AA-BB-CC-DD-EE-FF:input');
    await settings.setOutputVolume(40);

    final ExportBundle bundle = await service.buildBundle();
    final Map<String, Object?> exported =
        (jsonDecode(bundle.journalJson) as Map<String, Object?>)['settings']!
            as Map<String, Object?>;

    expect(exported.keys, isNot(contains('audio_output_id')));
    expect(exported.keys, isNot(contains('audio_input_id')));
    expect(exported['output_volume'], '40');
    expect(bundle.journalJson, isNot(contains('AA:BB:CC:DD:EE:FF')));
    expect(bundle.journalJson, isNot(contains('AA-BB-CC-DD-EE-FF')));
  });
}
