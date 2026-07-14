import 'package:drift/drift.dart';

import '../database/app_database.dart';

class DaysDao {
  DaysDao(this._db);

  final AppDatabase _db;

  Future<Day> insertDay({
    required String id,
    required String date,
    required String? moodId,
    required int createdAt,
    required int updatedAt,
  }) {
    return _db.into(_db.days).insertReturning(
          DaysCompanion.insert(
            id: id,
            date: date,
            moodId: Value(moodId),
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        );
  }

  Future<Day?> dayById(String id) {
    return (_db.select(_db.days)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
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
    return (_db.update(_db.days)..where((t) => t.id.equals(id))).write(
      DaysCompanion(moodId: Value(moodId), updatedAt: Value(updatedAt)),
    );
  }

  Future<int> softDelete({required String id, required int deletedAt}) {
    return (_db.update(_db.days)..where((t) => t.id.equals(id))).write(
      DaysCompanion(
        deletedAt: Value(deletedAt),
        updatedAt: Value(deletedAt),
      ),
    );
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
}
