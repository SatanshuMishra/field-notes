import 'dart:io';

import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/settings/drift_settings_repository.dart';
import 'package:field_notes/data/settings/journal_settings_store.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Future<String?> _storedValue(AppDatabase db) async {
  final Setting? row =
      await (db.select(db.settings)..where(
            ($SettingsTable t) => t.key.equals('meadow_pauses_when_inactive'),
          ))
          .getSingleOrNull();
  return row?.value;
}

DriftSettingsRepository _settingsFor(AppDatabase db) {
  return DriftSettingsRepository(
    db,
    JournalSettingsStore(db, ChangeRecorder(db)),
  );
}

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fn_meadow_pause');
    file = File(p.join(directory.path, 'field_notes.sqlite'));
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('the Meadow background pause setting saves and reloads, defaulting to pause', () async {
    final AppDatabase first = AppDatabase(NativeDatabase(file));
    final DriftSettingsRepository fresh = _settingsFor(first);

    expect((await fresh.load()).meadowPausesWhenInactive, isTrue);
    expect((await fresh.watch().first).meadowPausesWhenInactive, isTrue);
    expect(await _storedValue(first), isNull);

    await fresh.setMeadowPausesWhenInactive(false);
    expect(await _storedValue(first), 'false');
    await first.close();

    final AppDatabase reopened = AppDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    final DriftSettingsRepository restored = _settingsFor(reopened);

    expect((await restored.load()).meadowPausesWhenInactive, isFalse);
    expect((await restored.watch().first).meadowPausesWhenInactive, isFalse);
  });
}
