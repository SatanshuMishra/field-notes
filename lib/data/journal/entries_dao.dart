import 'dart:collection';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/services/note_limits.dart';
import '../database/app_database.dart';
import '../sync/change_recorder.dart';
import '../sync/synced_tables.dart';

const String _emptyVersion = '{}';
const List<String> _textFields = <String>[
  'textContent',
  'textVersion',
  'updatedAt',
];
const List<String> _deleteFields = <String>['deletedAt', 'updatedAt'];
const List<String> _deleteUnsyncableFields = <String>[
  'deletedAt',
  'updatedAt',
  'textContent',
  'textVersion',
];

class EntriesDao {
  EntriesDao(this._db, this._recorder);

  final AppDatabase _db;
  final ChangeRecorder _recorder;

  Future<Entry> insertEntry({
    required String id,
    required String dayId,
    required String type,
    required String? textContent,
    required String? mediaId,
    required String? thumbnailMediaId,
    required int? durationMs,
    required int createdAt,
    required int updatedAt,
  }) {
    return _db.transaction(() async {
      final String clocks = await _recorder.stamp(
        table: SyncedTables.entries,
        rowId: id,
        fields: SyncedTables.entryFields,
        currentClocks: '{}',
      );
      final String version = textContent == null
          ? _emptyVersion
          : _raisedVersion(_emptyVersion, _recorder.nodeId);
      return _db
          .into(_db.entries)
          .insertReturning(
            EntriesCompanion.insert(
              id: id,
              dayId: dayId,
              type: type,
              textContent: Value(textContent),
              mediaId: Value(mediaId),
              thumbnailMediaId: Value(thumbnailMediaId),
              durationMs: Value(durationMs),
              createdAt: createdAt,
              updatedAt: updatedAt,
              textVersion: Value(version),
              fieldClocks: Value(clocks),
            ),
          );
    });
  }

  Future<Entry?> entryById(String id) {
    return (_db.select(
      _db.entries,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<Entry>> activeEntriesForDay(String dayId) {
    return (_db.select(_db.entries)
          ..where((t) => t.dayId.equals(dayId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<int> updateText({
    required String id,
    required String textContent,
    required int updatedAt,
  }) {
    return _db.transaction(() async {
      final Entry? existing = await entryById(id);
      if (existing == null) {
        return 0;
      }
      if (existing.textContent == textContent) {
        return 1;
      }
      final String clocks = await _recorder.stamp(
        table: SyncedTables.entries,
        rowId: id,
        fields: _textFields,
        currentClocks: existing.fieldClocks,
      );
      return (_db.update(_db.entries)..where((t) => t.id.equals(id))).write(
        EntriesCompanion(
          textContent: Value(textContent),
          textVersion: Value(
            _raisedVersion(existing.textVersion, _recorder.nodeId),
          ),
          updatedAt: Value(updatedAt),
          fieldClocks: Value(clocks),
        ),
      );
    });
  }

  Future<int> softDelete({required String id, required int deletedAt}) {
    return _db.transaction(() async {
      final Entry? existing = await entryById(id);
      if (existing == null) {
        return 0;
      }
      final String? text = existing.textContent;
      final bool unsyncable = text != null && !noteFitsSync(text);
      final String clocks = await _recorder.stamp(
        table: SyncedTables.entries,
        rowId: id,
        fields: unsyncable ? _deleteUnsyncableFields : _deleteFields,
        currentClocks: existing.fieldClocks,
      );
      return (_db.update(_db.entries)..where((t) => t.id.equals(id))).write(
        EntriesCompanion(
          deletedAt: Value(deletedAt),
          updatedAt: Value(deletedAt),
          textContent: unsyncable ? const Value('') : const Value.absent(),
          textVersion: unsyncable
              ? Value(_raisedVersion(existing.textVersion, _recorder.nodeId))
              : const Value.absent(),
          fieldClocks: Value(clocks),
        ),
      );
    });
  }

  Stream<List<Entry>> watchActiveEntriesForDay(String dayId) {
    return (_db.select(_db.entries)
          ..where((t) => t.dayId.equals(dayId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Stream<List<Entry>> watchActiveEntriesForDate(String date) {
    final query =
        _db.select(_db.entries).join([
            innerJoin(_db.days, _db.days.id.equalsExp(_db.entries.dayId)),
          ])
          ..where(
            _db.days.date.equals(date) &
                _db.days.deletedAt.isNull() &
                _db.entries.deletedAt.isNull(),
          )
          ..orderBy([OrderingTerm.asc(_db.entries.createdAt)]);
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(_db.entries)).toList(),
    );
  }
}

String _raisedVersion(String encoded, String nodeId) {
  final Object? decoded = jsonDecode(encoded);
  if (decoded is! Map<String, Object?> ||
      decoded.values.any((Object? count) => count is! int)) {
    throw FormatException(
      'A text version is not a JSON object of edit counts.',
      encoded,
    );
  }
  final Map<String, int> counts = decoded.cast<String, int>();
  return jsonEncode(
    SplayTreeMap<String, int>.of(<String, int>{
      ...counts,
      nodeId: (counts[nodeId] ?? 0) + 1,
    }),
  );
}
