import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/synced_tables.dart';

class _FutureSchemaDatabase extends AppDatabase {
  _FutureSchemaDatabase(super.executor);

  @override
  int get schemaVersion => 3;
}

class _HandBuiltFile implements QueryExecutorUser {
  const _HandBuiltFile();

  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}

const List<String> _versionOneSchema = <String>[
  'CREATE TABLE "media_blobs" ("id" TEXT NOT NULL, "rel_path" TEXT NOT NULL, '
      '"mime" TEXT NOT NULL, "kind" TEXT NOT NULL, "bytes" INTEGER NOT NULL, '
      '"width" INTEGER NULL, "height" INTEGER NULL, "duration_ms" INTEGER NULL, '
      '"created_at" INTEGER NOT NULL, "poster_id" TEXT NULL, '
      '"field_clocks" TEXT NOT NULL DEFAULT \'{}\', PRIMARY KEY ("id"))',
  'CREATE TABLE "days" ("id" TEXT NOT NULL, "date" TEXT NOT NULL, '
      '"mood_id" TEXT NULL, "created_at" INTEGER NOT NULL, '
      '"updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, '
      '"field_clocks" TEXT NOT NULL DEFAULT \'{}\', PRIMARY KEY ("id"))',
  'CREATE TABLE "entries" ("id" TEXT NOT NULL, "day_id" TEXT NOT NULL, '
      '"type" TEXT NOT NULL, "text_content" TEXT NULL, "media_id" TEXT NULL, '
      '"thumbnail_media_id" TEXT NULL, "duration_ms" INTEGER NULL, '
      '"created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, '
      '"deleted_at" INTEGER NULL, "conflict_source_device" TEXT NULL, '
      '"text_version" TEXT NOT NULL DEFAULT \'{}\', '
      '"field_clocks" TEXT NOT NULL DEFAULT \'{}\', PRIMARY KEY ("id"))',
  'CREATE TABLE "entry_photos" ("id" TEXT NOT NULL, "entry_id" TEXT NOT NULL, '
      '"media_id" TEXT NOT NULL, "sort_order" INTEGER NOT NULL, '
      '"created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, '
      '"deleted_at" INTEGER NULL, '
      '"field_clocks" TEXT NOT NULL DEFAULT \'{}\', PRIMARY KEY ("id"))',
  'CREATE TABLE "settings" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, '
      'PRIMARY KEY ("key"))',
  'CREATE TABLE "journal_settings" ("key" TEXT NOT NULL, '
      '"value" TEXT NOT NULL, "field_clocks" TEXT NOT NULL DEFAULT \'{}\', '
      'PRIMARY KEY ("key"))',
  'CREATE TABLE "sync_outbox" ("id" INTEGER NOT NULL PRIMARY KEY '
      'AUTOINCREMENT, "record_table" TEXT NOT NULL, "row_id" TEXT NOT NULL, '
      '"change_id" TEXT NULL, "enqueued_at" INTEGER NOT NULL)',
  'CREATE TABLE "sync_record_seqs" ("record_key" TEXT NOT NULL, '
      '"record_table" TEXT NOT NULL, "row_id" TEXT NOT NULL, '
      '"seq" INTEGER NOT NULL, PRIMARY KEY ("record_key"))',
  'CREATE TABLE "sync_text_bases" ("entry_id" TEXT NOT NULL, '
      '"text" TEXT NOT NULL, "clock" TEXT NOT NULL, "version" TEXT NOT NULL, '
      'PRIMARY KEY ("entry_id"))',
  'CREATE TABLE "sync_states" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, '
      'PRIMARY KEY ("key"))',
  'CREATE TABLE "sync_held_states" ("record_key" TEXT NOT NULL, '
      '"state_json" TEXT NOT NULL, "held_at" INTEGER NOT NULL, '
      'PRIMARY KEY ("record_key"))',
  'CREATE TABLE "sync_uploads" ("blob_id" TEXT NOT NULL, '
      '"blob_name" TEXT NOT NULL, "upload_id" TEXT NOT NULL, '
      '"total_bytes" INTEGER NOT NULL, "part_count" INTEGER NOT NULL, '
      '"acked_parts" TEXT NOT NULL DEFAULT \'[]\', "parts_dir" TEXT NULL, '
      '"status" TEXT NOT NULL, PRIMARY KEY ("blob_id"))',
  'CREATE TABLE "sync_media_cache" ("blob_id" TEXT NOT NULL, '
      '"downloaded_at" INTEGER NULL, "last_opened_at" INTEGER NULL, '
      '"uploaded" INTEGER NOT NULL DEFAULT 0 CHECK ("uploaded" IN (0, 1)), '
      '"reported_state" TEXT NOT NULL DEFAULT \'none\', '
      'PRIMARY KEY ("blob_id"))',
  'CREATE UNIQUE INDEX days_date_active ON days (date) '
      'WHERE deleted_at IS NULL',
  'CREATE UNIQUE INDEX sync_outbox_record ON sync_outbox '
      '(record_table, row_id)',
];

const List<String> _versionOneRows = <String>[
  'INSERT INTO days (id, date, mood_id, created_at, updated_at, field_clocks) '
      'VALUES (\'day-2026-07-11\', \'2026-07-11\', \'calm\', 1000, 2000, '
      '\'{"date":"c1"}\')',
  'INSERT INTO entries (id, day_id, type, media_id, duration_ms, created_at, '
      'updated_at, text_version, field_clocks) '
      'VALUES (\'entry-1\', \'day-2026-07-11\', \'voice\', \'blob-1\', 4200, '
      '1000, 2000, \'{}\', \'{"mediaId":"c2"}\')',
  'INSERT INTO entry_photos (id, entry_id, media_id, sort_order, created_at, '
      'updated_at, field_clocks) '
      'VALUES (\'photo-1\', \'entry-1\', \'blob-2\', 0, 1000, 1000, '
      '\'{"sortOrder":"c3"}\')',
  'INSERT INTO media_blobs (id, rel_path, mime, kind, bytes, duration_ms, '
      'created_at, field_clocks) '
      'VALUES (\'blob-1\', \'blobs/b/blob-1.m4a\', \'audio/mp4\', \'audio\', '
      '2048, 4200, 1000, \'{"mime":"c4"}\')',
  'INSERT INTO sync_outbox (id, record_table, row_id, enqueued_at) '
      'VALUES (1, \'entries\', \'entry-1\', 3000)',
];

Future<void> _writeVersionOneFile(File file) async {
  final NativeDatabase raw = NativeDatabase(
    file,
    setup: (database) {
      for (final String statement in <String>[
        ..._versionOneSchema,
        ..._versionOneRows,
      ]) {
        database.execute(statement);
      }
      database.execute('PRAGMA user_version = 1');
    },
  );
  await raw.ensureOpen(const _HandBuiltFile());
  await raw.close();
}

Future<int> _userVersion(AppDatabase db) async {
  final row = await db.customSelect('PRAGMA user_version').getSingle();
  return row.read<int>('user_version');
}

Future<List<String>> _entryColumns(AppDatabase db) async {
  final rows = await db.customSelect('PRAGMA table_info(entries)').get();
  return rows.map((r) => r.read<String>('name')).toList();
}

Future<void> _insertVoiceWithPeaks(AppDatabase db) async {
  await db
      .into(db.days)
      .insert(
        DaysCompanion.insert(
          id: 'day-2026-07-11',
          date: '2026-07-11',
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );
  await db
      .into(db.entries)
      .insert(
        EntriesCompanion.insert(
          id: 'entry-1',
          dayId: 'day-2026-07-11',
          type: 'voice',
          mediaId: const Value('blob-1'),
          durationMs: const Value(4200),
          createdAt: 1000,
          updatedAt: 1000,
          peaks: const Value('[0.1,0.9]'),
        ),
      );
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

    test('a fresh database reports schema version 2', () async {
      expect(db.schemaVersion, 2);
      expect(await _userVersion(db), 2);
      expect(await _entryColumns(db), contains('peaks'));
    });

    test(
      'creates every journal and sync table and the partial unique index',
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
      },
    );

    test(
      'allows one active day per date and frees the date after soft-delete',
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

        await db.customStatement(
          "UPDATE days SET deleted_at = 1 WHERE id = 'a'",
        );

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
      },
    );

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

    test('every column but the field clocks and local paths is synced', () async {
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
        SyncedTables.days: (await db.select(db.days).getSingle())
            .toJson()
            .keys
            .toSet(),
        SyncedTables.entries: (await db.select(db.entries).getSingle())
            .toJson()
            .keys
            .toSet(),
        SyncedTables.entryPhotos: (await db.select(db.entryPhotos).getSingle())
            .toJson()
            .keys
            .toSet(),
        SyncedTables.mediaBlobs: (await db.select(db.mediaBlobs).getSingle())
            .toJson()
            .keys
            .toSet(),
        SyncedTables.journalSettings:
            (await db.select(db.journalSettings).getSingle())
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

  group('AppDatabase migration', () {
    late Directory dir;
    late File file;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('fn_db');
      file = File(p.join(dir.path, 'field_notes.sqlite'));
    });

    tearDown(() async {
      await dir.delete(recursive: true);
    });

    test('a version 1 database upgrades to 2 keeping its rows', () async {
      await _writeVersionOneFile(file);

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);

      expect(await _userVersion(upgraded), 2);
      expect(await _entryColumns(upgraded), contains('peaks'));
      expect(await upgraded.select(upgraded.days).get(), const <Day>[
        Day(
          id: 'day-2026-07-11',
          date: '2026-07-11',
          moodId: 'calm',
          createdAt: 1000,
          updatedAt: 2000,
          fieldClocks: '{"date":"c1"}',
        ),
      ]);
      expect(await upgraded.select(upgraded.entries).get(), const <Entry>[
        Entry(
          id: 'entry-1',
          dayId: 'day-2026-07-11',
          type: 'voice',
          mediaId: 'blob-1',
          durationMs: 4200,
          createdAt: 1000,
          updatedAt: 2000,
          textVersion: '{}',
          fieldClocks: '{"mediaId":"c2"}',
        ),
      ]);
      expect(
        (await upgraded.select(upgraded.entries).getSingle()).peaks,
        isNull,
      );
      expect(
        await upgraded.select(upgraded.entryPhotos).get(),
        const <EntryPhoto>[
          EntryPhoto(
            id: 'photo-1',
            entryId: 'entry-1',
            mediaId: 'blob-2',
            sortOrder: 0,
            createdAt: 1000,
            updatedAt: 1000,
            fieldClocks: '{"sortOrder":"c3"}',
          ),
        ],
      );
      expect(
        await upgraded.select(upgraded.mediaBlobs).get(),
        const <MediaBlob>[
          MediaBlob(
            id: 'blob-1',
            relPath: 'blobs/b/blob-1.m4a',
            mime: 'audio/mp4',
            kind: 'audio',
            bytes: 2048,
            durationMs: 4200,
            createdAt: 1000,
            fieldClocks: '{"mime":"c4"}',
          ),
        ],
      );
      expect(
        await upgraded.select(upgraded.syncOutbox).get(),
        const <SyncOutboxData>[
          SyncOutboxData(
            id: 1,
            recordTable: 'entries',
            rowId: 'entry-1',
            enqueuedAt: 3000,
          ),
        ],
      );
    });

    test('a version 2 database reopens unchanged', () async {
      final created = AppDatabase(NativeDatabase(file));
      await _insertVoiceWithPeaks(created);
      await created.close();

      final reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);

      expect(await _userVersion(reopened), 2);
      expect(
        (await _entryColumns(reopened)).where((name) => name == 'peaks'),
        hasLength(1),
      );
      final Entry entry = await reopened.select(reopened.entries).getSingle();
      expect(entry.id, 'entry-1');
      expect(entry.peaks, '[0.1,0.9]');
    });

    test(
      'an upgrade past version 2 keeps the data and raises the recovery error',
      () async {
        final created = AppDatabase(NativeDatabase(file));
        await _insertVoiceWithPeaks(created);
        await created.close();

        final upgraded = _FutureSchemaDatabase(NativeDatabase(file));
        await expectLater(
          upgraded.customSelect('SELECT 1 AS ok').getSingle(),
          throwsA(
            predicate(
              (Object e) => e.toString().contains(
                'cannot migrate its database from schema version 2 to 3',
              ),
            ),
          ),
        );
        await upgraded.close();

        final reopened = AppDatabase(NativeDatabase(file));
        addTearDown(reopened.close);
        expect(await _userVersion(reopened), 2);
        expect(
          (await reopened.select(reopened.days).getSingle()).id,
          'day-2026-07-11',
        );
        final Entry entry = await reopened.select(reopened.entries).getSingle();
        expect(entry.id, 'entry-1');
        expect(entry.peaks, '[0.1,0.9]');
      },
    );
  });
}
