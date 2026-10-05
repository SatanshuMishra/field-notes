import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/synced_tables.dart';

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

    test('creates every journal and sync table and the partial unique index',
        () async {
      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final names = tables.map((r) => r.read<String>('name')).toSet();
      expect(
        names.containsAll({
          'days',
          'entries',
          'entry_photos',
          'media_blobs',
          'settings',
          'journal_settings',
          'sync_outbox',
          'sync_record_seqs',
          'sync_text_bases',
          'sync_states',
          'sync_held_states',
          'sync_uploads',
          'sync_media_cache',
        }),
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

    test('an entry can be inserted whose day does not exist', () async {
      await db.customStatement(
        "INSERT INTO entries "
        "(id, day_id, type, media_id, thumbnail_media_id, created_at, "
        "updated_at) "
        "VALUES ('e', 'missing-day', 'video', 'missing-blob', "
        "'missing-poster', 0, 0)",
      );
      await db.customStatement(
        "INSERT INTO entry_photos "
        "(id, entry_id, media_id, sort_order, created_at, updated_at) "
        "VALUES ('p', 'missing-entry', 'missing-blob', 0, 0, 0)",
      );

      final Entry entry = await db.select(db.entries).getSingle();
      expect(entry.dayId, 'missing-day');
      expect(entry.fieldClocks, '{}');
      expect(entry.textVersion, '{}');
      final EntryPhoto photo = await db.select(db.entryPhotos).getSingle();
      expect(photo.entryId, 'missing-entry');
    });

    test('a record can hold only one pending outbox entry', () async {
      await db.customStatement(
        "INSERT INTO sync_outbox (record_table, row_id, enqueued_at) "
        "VALUES ('days', 'day-2026-07-11', 0)",
      );

      await expectLater(
        db.customStatement(
          "INSERT INTO sync_outbox (record_table, row_id, enqueued_at) "
          "VALUES ('days', 'day-2026-07-11', 1)",
        ),
        throwsA(predicate((Object e) => e.toString().contains('UNIQUE'))),
      );
    });

    test('every column but the field clocks and local paths is synced',
        () async {
      await db.customStatement(
        "INSERT INTO days (id, date, created_at, updated_at) "
        "VALUES ('d', '2026-07-11', 0, 0)",
      );
      await db.customStatement(
        "INSERT INTO entries (id, day_id, type, created_at, updated_at) "
        "VALUES ('e', 'd', 'text', 0, 0)",
      );
      await db.customStatement(
        "INSERT INTO entry_photos "
        "(id, entry_id, media_id, sort_order, created_at, updated_at) "
        "VALUES ('p', 'e', 'm', 0, 0, 0)",
      );
      await db.customStatement(
        "INSERT INTO media_blobs "
        "(id, rel_path, mime, kind, bytes, created_at) "
        "VALUES ('m', 'blobs/m', 'image/jpeg', 'photo', 1, 0)",
      );
      await db.customStatement(
        "INSERT INTO journal_settings (key, value) VALUES ('week_start', '1')",
      );
      final Map<String, Set<String>> columns = {
        SyncedTables.days:
            (await db.select(db.days).getSingle()).toJson().keys.toSet(),
        SyncedTables.entries:
            (await db.select(db.entries).getSingle()).toJson().keys.toSet(),
        SyncedTables.entryPhotos:
            (await db.select(db.entryPhotos).getSingle()).toJson().keys.toSet(),
        SyncedTables.mediaBlobs:
            (await db.select(db.mediaBlobs).getSingle()).toJson().keys.toSet(),
        SyncedTables.journalSettings: (await db.select(db.journalSettings)
                .getSingle())
            .toJson()
            .keys
            .toSet(),
      };

      expect(
        SyncedTables.fields.map(
          (String table, List<String> fields) =>
              MapEntry(table, fields.toSet()),
        ),
        columns.map(
          (String table, Set<String> names) =>
              MapEntry(table, names.difference({'fieldClocks', 'relPath'})),
        ),
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
