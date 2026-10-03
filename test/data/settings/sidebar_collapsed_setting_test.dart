import 'dart:io';

import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/settings/drift_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Future<String?> _storedValue(AppDatabase db) async {
  final Setting? row = await (db.select(
    db.settings,
  )..where((t) => t.key.equals('sidebar_collapsed'))).getSingleOrNull();
  return row?.value;
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
      final DriftSettingsRepository fresh = DriftSettingsRepository(first);

      expect((await fresh.load()).sidebarCollapsed, isFalse);

      await fresh.setSidebarCollapsed(true);
      await first.close();

      final AppDatabase reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      final DriftSettingsRepository restored = DriftSettingsRepository(
        reopened,
      );

      expect((await restored.load()).sidebarCollapsed, isTrue);
      expect((await restored.watch().first).sidebarCollapsed, isTrue);
    },
  );

  test(
    'collapsing stores true under sidebar_collapsed and opening stores false',
    () async {
      final AppDatabase db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final DriftSettingsRepository repository = DriftSettingsRepository(db);

      await repository.setSidebarCollapsed(true);
      expect(await _storedValue(db), 'true');

      await repository.setSidebarCollapsed(false);
      expect(await _storedValue(db), 'false');
      expect((await repository.load()).sidebarCollapsed, isFalse);
    },
  );
}
