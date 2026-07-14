import 'package:drift/drift.dart';

import '../database/app_database.dart';

class EntryPhotosDao {
  EntryPhotosDao(this._db);

  final AppDatabase _db;

  Future<EntryPhoto> insertPhoto({
    required String id,
    required String entryId,
    required String mediaId,
    required int sortOrder,
    required int createdAt,
    required int updatedAt,
  }) {
    return _db.into(_db.entryPhotos).insertReturning(
          EntryPhotosCompanion.insert(
            id: id,
            entryId: entryId,
            mediaId: mediaId,
            sortOrder: sortOrder,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        );
  }

  Future<List<EntryPhoto>> activePhotosForEntry(String entryId) {
    return (_db.select(_db.entryPhotos)
          ..where((t) => t.entryId.equals(entryId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  Stream<List<EntryPhoto>> watchActivePhotosForEntry(String entryId) {
    return (_db.select(_db.entryPhotos)
          ..where((t) => t.entryId.equals(entryId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<int> softDelete({required String id, required int deletedAt}) {
    return (_db.update(_db.entryPhotos)..where((t) => t.id.equals(id))).write(
      EntryPhotosCompanion(
        deletedAt: Value(deletedAt),
        updatedAt: Value(deletedAt),
      ),
    );
  }
}
