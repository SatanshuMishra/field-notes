import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../sync/change_recorder.dart';
import '../sync/synced_tables.dart';

const List<String> _sortFields = <String>['sortOrder', 'updatedAt'];
const List<String> _deleteFields = <String>['deletedAt', 'updatedAt'];

class EntryPhotosDao {
  EntryPhotosDao(this._db, this._recorder);

  final AppDatabase _db;
  final ChangeRecorder _recorder;

  Future<EntryPhoto> insertPhoto({
    required String id,
    required String entryId,
    required String mediaId,
    required int sortOrder,
    required int createdAt,
    required int updatedAt,
  }) {
    return _db.transaction(() async {
      final String clocks = await _recorder.stamp(
        table: SyncedTables.entryPhotos,
        rowId: id,
        fields: SyncedTables.entryPhotoFields,
        currentClocks: '{}',
      );
      return _db
          .into(_db.entryPhotos)
          .insertReturning(
            EntryPhotosCompanion.insert(
              id: id,
              entryId: entryId,
              mediaId: mediaId,
              sortOrder: sortOrder,
              createdAt: createdAt,
              updatedAt: updatedAt,
              fieldClocks: Value(clocks),
            ),
          );
    });
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

  Future<List<EntryPhoto>> replacePhotos({
    required String entryId,
    required List<String> mediaIds,
    required int now,
    required String Function() newId,
  }) {
    return _db.transaction(() async {
      final List<EntryPhoto> active = await activePhotosForEntry(entryId);
      List<EntryPhoto> linksTo(String mediaId) =>
          active.where((EntryPhoto link) => link.mediaId == mediaId).toList();
      final Iterable<EntryPhoto> removed = active.where(
        (EntryPhoto link) =>
            linksTo(link.mediaId).indexOf(link) >=
            mediaIds.where((String id) => id == link.mediaId).length,
      );
      for (final EntryPhoto link in removed) {
        await softDelete(id: link.id, deletedAt: now);
      }
      final List<EntryPhoto> kept = <EntryPhoto>[];
      for (int index = 0; index < mediaIds.length; index++) {
        final String mediaId = mediaIds[index];
        final int occurrence = mediaIds
            .take(index)
            .where((String id) => id == mediaId)
            .length;
        final List<EntryPhoto> candidates = linksTo(mediaId);
        kept.add(
          occurrence < candidates.length
              ? await _placed(
                  candidates[occurrence],
                  sortOrder: index,
                  now: now,
                )
              : await insertPhoto(
                  id: newId(),
                  entryId: entryId,
                  mediaId: mediaId,
                  sortOrder: index,
                  createdAt: now,
                  updatedAt: now,
                ),
        );
      }
      return kept;
    });
  }

  Future<int> softDelete({required String id, required int deletedAt}) {
    return _db.transaction(() async {
      final EntryPhoto? existing = await _photoById(id);
      if (existing == null) {
        return 0;
      }
      final String clocks = await _recorder.stamp(
        table: SyncedTables.entryPhotos,
        rowId: id,
        fields: _deleteFields,
        currentClocks: existing.fieldClocks,
      );
      return (_db.update(_db.entryPhotos)..where((t) => t.id.equals(id))).write(
        EntryPhotosCompanion(
          deletedAt: Value(deletedAt),
          updatedAt: Value(deletedAt),
          fieldClocks: Value(clocks),
        ),
      );
    });
  }

  Future<EntryPhoto?> _photoById(String id) {
    return (_db.select(
      _db.entryPhotos,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<EntryPhoto> _placed(
    EntryPhoto link, {
    required int sortOrder,
    required int now,
  }) async {
    if (link.sortOrder == sortOrder) {
      return link;
    }
    final String clocks = await _recorder.stamp(
      table: SyncedTables.entryPhotos,
      rowId: link.id,
      fields: _sortFields,
      currentClocks: link.fieldClocks,
    );
    final List<EntryPhoto> moved =
        await (_db.update(
          _db.entryPhotos,
        )..where((t) => t.id.equals(link.id))).writeReturning(
          EntryPhotosCompanion(
            sortOrder: Value(sortOrder),
            updatedAt: Value(now),
            fieldClocks: Value(clocks),
          ),
        );
    return moved.single;
  }
}
