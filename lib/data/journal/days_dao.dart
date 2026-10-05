import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../sync/change_recorder.dart';
import '../sync/synced_tables.dart';
import 'day_ids.dart';

const List<String> _reviveFields = <String>['moodId', 'updatedAt', 'deletedAt'];
const List<String> _moodFields = <String>['moodId', 'updatedAt'];
const List<String> _deleteFields = <String>['deletedAt', 'updatedAt'];

class DaysDao {
  DaysDao(this._db, this._recorder);

  final AppDatabase _db;
  final ChangeRecorder _recorder;

  Future<Day> insertDay({
    required String date,
    required String? moodId,
    required int createdAt,
    required int updatedAt,
  }) {
    return _db.transaction(() async {
      final String id = dayIdForDate(date);
      final Day? existing = await dayById(id);
      if (existing != null && existing.deletedAt != null) {
        return _revive(existing, moodId: moodId, updatedAt: updatedAt);
      }
      final String clocks = await _recorder.stamp(
        table: SyncedTables.days,
        rowId: id,
        fields: SyncedTables.dayFields,
        currentClocks: '{}',
      );
      return _db
          .into(_db.days)
          .insertReturning(
            DaysCompanion.insert(
              id: id,
              date: date,
              moodId: Value(moodId),
              createdAt: createdAt,
              updatedAt: updatedAt,
              fieldClocks: Value(clocks),
            ),
          );
    });
  }

  Future<Day?> dayById(String id) {
    return (_db.select(
      _db.days,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Day?> activeDayForDate(String date) {
    return (_db.select(_db.days)
          ..where((t) => t.date.equals(date) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<int> updateMood({
    required String id,
    required String? moodId,
    required int updatedAt,
  }) {
    return _db.transaction(() async {
      final Day? existing = await dayById(id);
      if (existing == null) {
        return 0;
      }
      final String clocks = await _recorder.stamp(
        table: SyncedTables.days,
        rowId: id,
        fields: _moodFields,
        currentClocks: existing.fieldClocks,
      );
      return (_db.update(_db.days)..where((t) => t.id.equals(id))).write(
        DaysCompanion(
          moodId: Value(moodId),
          updatedAt: Value(updatedAt),
          fieldClocks: Value(clocks),
        ),
      );
    });
  }

  Future<int> softDelete({required String id, required int deletedAt}) {
    return _db.transaction(() async {
      final Day? existing = await dayById(id);
      if (existing == null) {
        return 0;
      }
      final String clocks = await _recorder.stamp(
        table: SyncedTables.days,
        rowId: id,
        fields: _deleteFields,
        currentClocks: existing.fieldClocks,
      );
      return (_db.update(_db.days)..where((t) => t.id.equals(id))).write(
        DaysCompanion(
          deletedAt: Value(deletedAt),
          updatedAt: Value(deletedAt),
          fieldClocks: Value(clocks),
        ),
      );
    });
  }

  Stream<Day?> watchActiveDayForDate(String date) {
    return (_db.select(_db.days)
          ..where((t) => t.date.equals(date) & t.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  Stream<List<Day>> watchActiveDaysInMonth(String monthPrefix) {
    return (_db.select(_db.days)
          ..where((t) => t.date.like('$monthPrefix%') & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .watch();
  }

  Stream<List<Day>> watchAllActiveDays() {
    return (_db.select(_db.days)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  Future<List<Day>> activeDaysOnMonthDay(String monthDaySuffix) {
    return (_db.select(_db.days)
          ..where((t) => t.date.like('%$monthDaySuffix') & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  Future<Day> _revive(
    Day existing, {
    required String? moodId,
    required int updatedAt,
  }) async {
    final String clocks = await _recorder.stamp(
      table: SyncedTables.days,
      rowId: existing.id,
      fields: _reviveFields,
      currentClocks: existing.fieldClocks,
    );
    final List<Day> revived =
        await (_db.update(
          _db.days,
        )..where((t) => t.id.equals(existing.id))).writeReturning(
          DaysCompanion(
            moodId: Value(moodId),
            updatedAt: Value(updatedAt),
            deletedAt: const Value(null),
            fieldClocks: Value(clocks),
          ),
        );
    return revived.single;
  }
}
