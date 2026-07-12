import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:field_notes/data/database/app_database.dart';

class _FutureSchemaDatabase extends AppDatabase {
  _FutureSchemaDatabase(super.executor);

  @override
  int get schemaVersion => 2;
}

void main() {
  group('AppDatabase schema', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('a fresh database reports schema version 1', () async {
      expect(db.schemaVersion, 1);
      final row = await db.customSelect('PRAGMA user_version').getSingle();
      expect(row.read<int>('user_version'), 1);
    });

    test('creates all five tables and the partial unique index', () async {
      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final names = tables.map((r) => r.read<String>('name')).toSet();
      expect(
        names.containsAll(
          {'days', 'entries', 'entry_photos', 'media_blobs', 'settings'},
        ),
        isTrue,
      );

      final indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'index' AND name = 'days_date_active'",
          )
          .get();
      expect(indexes.length, 1);
    });

    test('allows one active day per date and frees the date after soft-delete',
        () async {
      await db.customStatement(
        "INSERT INTO days (id, date, created_at, updated_at) "
        "VALUES ('a', '2026-07-11', 0, 0)",
      );

      await expectLater(
        db.customStatement(
          "INSERT INTO days (id, date, created_at, updated_at) "
          "VALUES ('b', '2026-07-11', 0, 0)",
        ),
        throwsA(predicate((Object e) => e.toString().contains('UNIQUE'))),
      );

      await db.customStatement("UPDATE days SET deleted_at = 1 WHERE id = 'a'");

      await db.customStatement(
        "INSERT INTO days (id, date, created_at, updated_at) "
        "VALUES ('c', '2026-07-11', 0, 0)",
      );

      final active = await db
          .customSelect(
            "SELECT id FROM days "
            "WHERE date = '2026-07-11' AND deleted_at IS NULL",
          )
          .get();
      expect(active.length, 1);
      expect(active.single.read<String>('id'), 'c');
    });

    test('enforces foreign keys', () async {
      await expectLater(
        db.customStatement(
          "INSERT INTO entries (id, day_id, type, created_at, updated_at) "
          "VALUES ('e', 'missing-day', 'text', 0, 0)",
        ),
        throwsA(predicate((Object e) => e.toString().contains('FOREIGN KEY'))),
      );
    });
  });

  group('AppDatabase migration fail-safe', () {
    test('preserves data and surfaces a recovery error on an unknown upgrade',
        () async {
      final dir = await Directory.systemTemp.createTemp('fn_db');
      final file = File(p.join(dir.path, 'field_notes.sqlite'));

      final created = AppDatabase(NativeDatabase(file));
      await created.customStatement(
        "INSERT INTO days (id, date, created_at, updated_at) "
        "VALUES ('01', '2026-07-11', 0, 0)",
      );
      await created.close();

      final upgraded = _FutureSchemaDatabase(NativeDatabase(file));
      await expectLater(
        upgraded.customSelect('SELECT 1 AS ok').getSingle(),
        throwsA(
          predicate(
            (Object e) => e.toString().contains('cannot migrate its database'),
          ),
        ),
      );
      await upgraded.close();

      final reopened = AppDatabase(NativeDatabase(file));
      final rows = await reopened.customSelect('SELECT id FROM days').get();
      expect(rows.length, 1);
      await reopened.close();

      await dir.delete(recursive: true);
    });
  });
}
