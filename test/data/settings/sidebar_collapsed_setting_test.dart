import 'dart:io';

import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/settings/drift_settings_repository.dart';
import 'package:field_notes/data/settings/journal_settings_store.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Future<String?> _storedValue(AppDatabase db) async {
  final Setting? row = await (db.select(
    db.settings,
  )..where((t) => t.key.equals('sidebar_collapsed'))).getSingleOrNull();
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
    directory = await Directory.systemTemp.createTemp('fn_sidebar');
    file = File(p.join(directory.path, 'field_notes.sqlite'));
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'the sidebar collapsed setting saves and reloads, defaulting to open',
    () async {
      final AppDatabase first = AppDatabase(NativeDatabase(file));
      final DriftSettingsRepository fresh = _settingsFor(first);

      expect((await fresh.load()).sidebarCollapsed, isFalse);

      await fresh.setSidebarCollapsed(true);
      await first.close();

      final AppDatabase reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      final DriftSettingsRepository restored = _settingsFor(reopened);

      expect((await restored.load()).sidebarCollapsed, isTrue);
      expect((await restored.watch().first).sidebarCollapsed, isTrue);
    },
  );

  test(
    'collapsing stores true under sidebar_collapsed and opening stores false',
    () async {
      final AppDatabase db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final DriftSettingsRepository repository = _settingsFor(db);

      await repository.setSidebarCollapsed(true);
      expect(await _storedValue(db), 'true');

      await repository.setSidebarCollapsed(false);
      expect(await _storedValue(db), 'false');
      expect((await repository.load()).sidebarCollapsed, isFalse);
    },
  );
}
