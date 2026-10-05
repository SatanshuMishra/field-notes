import 'dart:math';

import 'package:drift/drift.dart' show OrderingTerm, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/data/sync/hlc.dart';
import 'package:field_notes/data/sync/merge/record_state.dart';
import 'package:field_notes/data/sync/merge/state_applier.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:flutter_test/flutter_test.dart';

const int _start = 1790000000000;
const int _minute = 60 * 1000;
const int _orders = 50;
const String _phone = 'phone';
const String _mac = 'mac';

int _at(int minute) => _start + minute * _minute;

String _clock(int minute, String node) {
  return Hlc(millis: _at(minute), counter: 0, nodeId: node).encode();
}

String _blobId(String hexDigit) => List<String>.filled(64, hexDigit).join();

RecordState _created(
  String table,
  String rowId,
  Map<String, Object?> fields,
  String clock,
) {
  return RecordState(
    table: table,
    rowId: rowId,
    fields: fields,
    clocks: <String, String>{
      for (final String field in SyncedTables.fields[table]!) field: clock,
    },
  );
}

RecordState _edited(
  RecordState earlier,
  Map<String, Object?> changes,
  String clock,
) {
  return RecordState(
    table: earlier.table,
    rowId: earlier.rowId,
    fields: <String, Object?>{...earlier.fields, ...changes},
    clocks: <String, String>{
      ...earlier.clocks,
      for (final String field in changes.keys) field: clock,
    },
  );
}

RecordState _day(String date, String? moodId, int minute, String node) {
  return _created(SyncedTables.days, 'day-$date', <String, Object?>{
    'id': 'day-$date',
    'date': date,
    'moodId': moodId,
    'createdAt': _at(minute),
    'updatedAt': _at(minute),
    'deletedAt': null,
  }, _clock(minute, node));
}

RecordState _entry(
  String id, {
  required String dayId,
  required String type,
  required String? text,
  required String version,
  String? mediaId,
  int? durationMs,
  required int minute,
  required String node,
}) {
  return _created(SyncedTables.entries, id, <String, Object?>{
    'id': id,
    'dayId': dayId,
    'type': type,
    'textContent': text,
    'mediaId': mediaId,
    'thumbnailMediaId': null,
    'durationMs': durationMs,
    'createdAt': _at(minute),
    'updatedAt': _at(minute),
    'deletedAt': null,
    'conflictSourceDevice': null,
    'textVersion': version,
  }, _clock(minute, node));
}

RecordState _photoLink(
  String id, {
  required String entryId,
  required String mediaId,
  required int sortOrder,
  required int minute,
  required String node,
}) {
  return _created(SyncedTables.entryPhotos, id, <String, Object?>{
    'id': id,
    'entryId': entryId,
    'mediaId': mediaId,
    'sortOrder': sortOrder,
    'createdAt': _at(minute),
    'updatedAt': _at(minute),
    'deletedAt': null,
  }, _clock(minute, node));
}

RecordState _blob(
  String id, {
  required String mime,
  required String kind,
  required int bytes,
  int? durationMs,
  required int minute,
  required String node,
}) {
  return _created(SyncedTables.mediaBlobs, id, <String, Object?>{
    'id': id,
    'mime': mime,
    'kind': kind,
    'bytes': bytes,
    'width': kind == 'photo' ? 1600 : null,
    'height': kind == 'photo' ? 1200 : null,
    'durationMs': durationMs,
    'createdAt': _at(minute),
    'posterId': null,
  }, _clock(minute, node));
}

RecordState _setting(String key, String value, int minute, String node) {
  return _created(SyncedTables.journalSettings, key, <String, Object?>{
    'key': key,
    'value': value,
  }, _clock(minute, node));
}

List<RecordState> _fixedStates() {
  final String photo = _blobId('a');
  final String voice = _blobId('b');
  final String screenshot = _blobId('c');
  final RecordState firstDay = _day('2026-09-29', 'sunny', 1, _phone);
  final RecordState secondDay = _day('2026-09-30', null, 2, _mac);
  final RecordState secondDayDeleted = _edited(secondDay, <String, Object?>{
    'deletedAt': _at(5),
    'updatedAt': _at(5),
  }, _clock(5, _phone));
  final RecordState note = _entry(
    'entry-note',
    dayId: firstDay.rowId,
    type: 'text',
    text: 'first line',
    version: '{"phone":1}',
    minute: 1,
    node: _phone,
  );
  final RecordState noteSecond = _edited(note, <String, Object?>{
    'textContent': 'first line\nsecond line',
    'textVersion': '{"mac":1,"phone":1}',
    'updatedAt': _at(3),
  }, _clock(3, _mac));
  final RecordState voiceNote = _entry(
    'entry-voice',
    dayId: secondDay.rowId,
    type: 'voice',
    text: null,
    version: '{}',
    mediaId: voice,
    durationMs: 4200,
    minute: 2,
    node: _mac,
  );
  final RecordState aside = _entry(
    'entry-aside',
    dayId: firstDay.rowId,
    type: 'text',
    text: 'an aside',
    version: '{"mac":1}',
    minute: 3,
    node: _mac,
  );
  final RecordState photoLink = _photoLink(
    'photo-1',
    entryId: note.rowId,
    mediaId: photo,
    sortOrder: 0,
    minute: 1,
    node: _phone,
  );
  final RecordState screenshotLink = _photoLink(
    'photo-2',
    entryId: note.rowId,
    mediaId: screenshot,
    sortOrder: 1,
    minute: 1,
    node: _phone,
  );
  final RecordState weekStart = _setting('week_start', '1', 1, _phone);
  return <RecordState>[
    firstDay,
    _edited(firstDay, <String, Object?>{
      'moodId': 'rainy',
      'updatedAt': _at(4),
    }, _clock(4, _mac)),
    secondDay,
    secondDayDeleted,
    _edited(secondDayDeleted, <String, Object?>{
      'moodId': 'calm',
      'deletedAt': null,
      'updatedAt': _at(7),
    }, _clock(7, _mac)),
    note,
    noteSecond,
    _edited(noteSecond, <String, Object?>{
      'textContent': 'first line\nsecond line\nthird line',
      'textVersion': '{"mac":1,"phone":2}',
      'updatedAt': _at(6),
    }, _clock(6, _phone)),
    voiceNote,
    _edited(voiceNote, <String, Object?>{
      'deletedAt': _at(8),
      'updatedAt': _at(8),
    }, _clock(8, _phone)),
    aside,
    photoLink,
    _edited(photoLink, <String, Object?>{
      'sortOrder': 1,
      'updatedAt': _at(4),
    }, _clock(4, _mac)),
    screenshotLink,
    _edited(screenshotLink, <String, Object?>{
      'sortOrder': 0,
      'updatedAt': _at(4),
    }, _clock(4, _mac)),
    _edited(screenshotLink, <String, Object?>{
      'deletedAt': _at(6),
      'updatedAt': _at(6),
    }, _clock(6, _phone)),
    _blob(
      photo,
      mime: 'image/jpeg',
      kind: 'photo',
      bytes: 180000,
      minute: 1,
      node: _phone,
    ),
    _blob(
      voice,
      mime: 'audio/mp4',
      kind: 'audio',
      bytes: 52000,
      durationMs: 4200,
      minute: 2,
      node: _mac,
    ),
    _blob(
      screenshot,
      mime: 'image/png',
      kind: 'photo',
      bytes: 240000,
      minute: 1,
      node: _phone,
    ),
    weekStart,
    _edited(weekStart, <String, Object?>{'value': '0'}, _clock(3, _mac)),
    _setting('meadow_key', '424242', 2, _mac),
  ];
}

Future<Map<String, Object?>> _syncedTables(AppDatabase db) async {
  return <String, Object?>{
    SyncedTables.days: <Map<String, Object?>>[
      for (final Day row in await (db.select(
        db.days,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get())
        row.toJson(),
    ],
    SyncedTables.entries: <Map<String, Object?>>[
      for (final Entry row in await (db.select(
        db.entries,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get())
        row.toJson(),
    ],
    SyncedTables.entryPhotos: <Map<String, Object?>>[
      for (final EntryPhoto row in await (db.select(
        db.entryPhotos,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get())
        row.toJson(),
    ],
    SyncedTables.mediaBlobs: <Map<String, Object?>>[
      for (final MediaBlob row in await (db.select(
        db.mediaBlobs,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get())
        row.toJson(),
    ],
    SyncedTables.journalSettings: <Map<String, Object?>>[
      for (final JournalSetting row in await (db.select(
        db.journalSettings,
      )..orderBy([(t) => OrderingTerm.asc(t.key)])).get())
        row.toJson(),
    ],
  };
}

bool _childBeforeParent(
  List<RecordState> order, {
  required String childTable,
  required String parentField,
  required String parentTable,
}) {
  int firstIndexOf(String rowId) => order.indexWhere(
    (RecordState state) => state.table == parentTable && state.rowId == rowId,
  );
  return order.asMap().entries.any(
    (MapEntry<int, RecordState> placed) =>
        placed.value.table == childTable &&
        firstIndexOf(placed.value.fields[parentField]! as String) > placed.key,
  );
}

Map<String, Object?> _row(
  Map<String, Object?> tables,
  String table,
  String rowId,
) {
  final String keyField = table == SyncedTables.journalSettings ? 'key' : 'id';
  return (tables[table]! as List<Map<String, Object?>>).singleWhere(
    (Map<String, Object?> row) => row[keyField] == rowId,
  );
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test('applying states in fifty random orders converges', () async {
    final List<RecordState> states = _fixedStates();
    bool entryBeforeDay = false;
    bool linkBeforeMedia = false;
    Map<String, Object?>? reference;

    for (int seed = 0; seed < _orders; seed++) {
      for (final int database in <int>[0, 1]) {
        final List<RecordState> order = <RecordState>[...states]
          ..shuffle(Random(seed * 2 + database));
        entryBeforeDay =
            entryBeforeDay ||
            _childBeforeParent(
              order,
              childTable: SyncedTables.entries,
              parentField: 'dayId',
              parentTable: SyncedTables.days,
            );
        linkBeforeMedia =
            linkBeforeMedia ||
            _childBeforeParent(
              order,
              childTable: SyncedTables.entryPhotos,
              parentField: 'mediaId',
              parentTable: SyncedTables.mediaBlobs,
            );
        final AppDatabase db = AppDatabase(NativeDatabase.memory());
        try {
          final StateApplier applier = StateApplier(
            database: db,
            recorder: ChangeRecorder(db, wallClock: () => _at(60)),
            localDeviceName: 'Device $database',
            wallClock: () => _at(60),
          );
          for (final RecordState state in order) {
            expect(
              await applier.apply(state),
              ApplyOutcome.applied,
              reason: 'seed $seed, database $database, ${state.rowId}',
            );
          }
          final Map<String, Object?> tables = await _syncedTables(db);
          reference ??= tables;
          expect(tables, reference, reason: 'seed $seed, database $database');
          expect(await db.select(db.syncOutbox).get(), isEmpty);
        } finally {
          await db.close();
        }
      }
    }

    final Map<String, Object?> converged = reference!;
    expect(entryBeforeDay, isTrue);
    expect(linkBeforeMedia, isTrue);
    expect(
      _row(converged, SyncedTables.days, 'day-2026-09-29')['moodId'],
      'rainy',
    );
    expect(
      _row(converged, SyncedTables.days, 'day-2026-09-30')['moodId'],
      'calm',
    );
    expect(
      _row(converged, SyncedTables.days, 'day-2026-09-30')['deletedAt'],
      isNull,
    );
    expect(
      _row(converged, SyncedTables.entries, 'entry-note')['textContent'],
      'first line\nsecond line\nthird line',
    );
    expect(
      _row(converged, SyncedTables.entries, 'entry-voice')['deletedAt'],
      _at(8),
    );
    expect(
      _row(converged, SyncedTables.entryPhotos, 'photo-1')['sortOrder'],
      1,
    );
    expect(
      _row(converged, SyncedTables.entryPhotos, 'photo-2')['deletedAt'],
      _at(6),
    );
    expect(converged[SyncedTables.mediaBlobs], hasLength(3));
    expect(
      _row(converged, SyncedTables.journalSettings, 'week_start')['value'],
      '0',
    );
    expect(
      _row(converged, SyncedTables.journalSettings, 'meadow_key')['value'],
      '424242',
    );
  });
}
