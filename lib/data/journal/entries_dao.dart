import 'package:drift/drift.dart';

import '../database/app_database.dart';

class EntriesDao {
  EntriesDao(this._db);

  final AppDatabase _db;

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
    return _db.into(_db.entries).insertReturning(
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
          ),
        );
  }

  Future<Entry?> entryById(String id) {
    return (_db.select(_db.entries)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
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
    return (_db.update(_db.entries)..where((t) => t.id.equals(id))).write(
      EntriesCompanion(
        textContent: Value(textContent),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<int> softDelete({required String id, required int deletedAt}) {
    return (_db.update(_db.entries)..where((t) => t.id.equals(id))).write(
      EntriesCompanion(
        deletedAt: Value(deletedAt),
        updatedAt: Value(deletedAt),
      ),
    );
  }

  Stream<List<Entry>> watchActiveEntriesForDay(String dayId) {
    return (_db.select(_db.entries)
          ..where((t) => t.dayId.equals(dayId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Stream<List<Entry>> watchActiveEntriesForDate(String date) {
    final query = _db.select(_db.entries).join([
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
