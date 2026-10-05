import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/hlc.dart';
import 'package:field_notes/data/sync/merge/record_reader.dart';
import 'package:field_notes/data/sync/synced_tables.dart';

const String joinPendingKey = 'join_pending';
const String joinDoneKey = 'join_done';
const String _joinValue = 'true';

final String lowestClock = const Hlc(
  millis: 0,
  counter: 0,
  nodeId: '0',
).encode();

enum JoinStage { notStarted, pending, done }

typedef MeadowKeyReader = Future<Object?> Function();

int _systemMillis() => DateTime.now().millisecondsSinceEpoch;

String _lowestClocks() => jsonEncode(<String, String>{
  for (final String field in SyncedTables.journalSettingFields)
    field: lowestClock,
});

final class JoinMerge {
  JoinMerge({
    required AppDatabase database,
    required this._recorder,
    required this._readMeadowKey,
    int Function()? wallClock,
  }) : _db = database,
       _wallClock = wallClock ?? _systemMillis;

  final AppDatabase _db;
  final ChangeRecorder _recorder;
  final MeadowKeyReader _readMeadowKey;
  final int Function() _wallClock;

  Future<JoinStage> stage() async {
    if (await readSyncState(_db, joinDoneKey) == _joinValue) {
      return JoinStage.done;
    }
    if (await readSyncState(_db, joinPendingKey) == _joinValue) {
      return JoinStage.pending;
    }
    return JoinStage.notStarted;
  }

  Future<void> prepare() async {
    await _readMeadowKey();
    await _db.transaction(() async {
      await writeSyncState(_db, joinPendingKey, _joinValue);
      await _db
          .update(_db.journalSettings)
          .write(JournalSettingsCompanion(fieldClocks: Value(_lowestClocks())));
      await (_db.delete(
        _db.syncOutbox,
      )..where((t) => t.recordTable.equals(SyncedTables.journalSettings))).go();
      await _enqueueAll(
        SyncedTables.days,
        (await _db.select(_db.days).get()).map((Day row) => row.id),
      );
      await _enqueueAll(
        SyncedTables.entries,
        (await _db.select(_db.entries).get()).map((Entry row) => row.id),
      );
      await _enqueueAll(
        SyncedTables.entryPhotos,
        (await _db.select(_db.entryPhotos).get()).map(
          (EntryPhoto row) => row.id,
        ),
      );
      await _enqueueAll(
        SyncedTables.mediaBlobs,
        (await _db.select(_db.mediaBlobs).get()).map((MediaBlob row) => row.id),
      );
    });
  }

  Future<void> finish() => _db.transaction(() async {
    for (final JournalSetting row
        in await _db.select(_db.journalSettings).get()) {
      final Map<String, String> clocks = decodeFieldClocks(row.fieldClocks);
      final bool lacking = SyncedTables.journalSettingFields.every(
        (String field) => clocks[field] == lowestClock,
      );
      if (!lacking) {
        continue;
      }
      final String stamped = await _recorder.stamp(
        table: SyncedTables.journalSettings,
        rowId: row.key,
        fields: SyncedTables.journalSettingFields,
        currentClocks: row.fieldClocks,
      );
      await (_db.update(_db.journalSettings)
            ..where((t) => t.key.equals(row.key)))
          .write(JournalSettingsCompanion(fieldClocks: Value(stamped)));
    }
    await (_db.delete(
      _db.syncStates,
    )..where((t) => t.key.equals(joinPendingKey))).go();
    await writeSyncState(_db, joinDoneKey, _joinValue);
  });

  Future<void> _enqueueAll(String table, Iterable<String> rowIds) async {
    final int now = _wallClock();
    await _db.batch((Batch batch) {
      for (final String rowId in rowIds) {
        batch.insert(
          _db.syncOutbox,
          SyncOutboxCompanion.insert(
            recordTable: table,
            rowId: rowId,
            enqueuedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }
}
