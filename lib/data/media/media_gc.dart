import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import 'blob_paths.dart';

class MediaGarbageCollector {
  MediaGarbageCollector({
    required AppDatabase database,
    required this._root,
  }) : _db = database;

  final AppDatabase _db;
  final Directory _root;

  Future<int> collectGarbage() {
    return _db.transaction(() async {
      final reachable = await _reachableMediaIds();
      await _sweepFiles(reachable);
      return _sweepRows(reachable);
    });
  }

  Future<Set<String>> _reachableMediaIds() async {
    final ids = <String>{};

    final entries = await (_db.select(_db.entries)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    for (final entry in entries) {
      final media = entry.mediaId;
      final thumbnail = entry.thumbnailMediaId;
      if (media != null) {
        ids.add(media);
      }
      if (thumbnail != null) {
        ids.add(thumbnail);
      }
    }

    final photos = await (_db.select(_db.entryPhotos)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    for (final photo in photos) {
      ids.add(photo.mediaId);
    }

    return ids;
  }

  Future<void> _sweepFiles(Set<String> reachable) async {
    final blobsDir = Directory(p.join(_root.path, blobsSubdir));
    if (!await blobsDir.exists()) {
      return;
    }

    final shardDirs = <Directory>{};
    await for (final entity
        in blobsDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final id = idFromRelPath(p.relative(entity.path, from: _root.path));
      if (id != null && !reachable.contains(id)) {
        shardDirs.add(entity.parent);
        await _bestEffortDeleteFile(entity);
      }
    }

    for (final shardDir in shardDirs) {
      await _bestEffortRemoveIfEmpty(shardDir);
    }
  }

  Future<void> _bestEffortDeleteFile(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      return;
    }
  }

  Future<void> _bestEffortRemoveIfEmpty(Directory dir) async {
    try {
      final hasEntries = await dir.list().isEmpty.then((empty) => !empty);
      if (!hasEntries) {
        await dir.delete();
      }
    } on FileSystemException {
      return;
    }
  }

  Future<int> _sweepRows(Set<String> reachable) async {
    final rows = await _db.select(_db.mediaBlobs).get();
    final unreachable = <String>{
      for (final row in rows)
        if (!reachable.contains(row.id)) row.id,
    };
    if (unreachable.isEmpty) {
      return 0;
    }

    await _detachSoftDeletedReferences(unreachable);

    return (_db.delete(_db.mediaBlobs)..where((t) => t.id.isIn(unreachable)))
        .go();
  }

  Future<void> _detachSoftDeletedReferences(Set<String> unreachable) async {
    final staleEntries = await (_db.select(_db.entries)
          ..where(
            (t) =>
                t.deletedAt.isNotNull() &
                (t.mediaId.isIn(unreachable) |
                    t.thumbnailMediaId.isIn(unreachable)),
          ))
        .get();
    for (final entry in staleEntries) {
      final clearMedia =
          entry.mediaId != null && unreachable.contains(entry.mediaId);
      final clearThumbnail = entry.thumbnailMediaId != null &&
          unreachable.contains(entry.thumbnailMediaId);
      if (!clearMedia && !clearThumbnail) {
        continue;
      }
      await (_db.update(_db.entries)..where((t) => t.id.equals(entry.id)))
          .write(
        EntriesCompanion(
          mediaId: clearMedia ? const Value(null) : const Value.absent(),
          thumbnailMediaId:
              clearThumbnail ? const Value(null) : const Value.absent(),
        ),
      );
    }

    await (_db.delete(_db.entryPhotos)
          ..where(
            (t) => t.deletedAt.isNotNull() & t.mediaId.isIn(unreachable),
          ))
        .go();
  }
}
