import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import '../drafts/draft_paths.dart';
import 'blob_paths.dart';
import 'blob_prefix.dart';

class MediaGarbageCollector {
  MediaGarbageCollector({
    required AppDatabase database,
    required this._root,
    this._drafts,
  }) : _db = database;

  final AppDatabase _db;
  final Directory _root;
  final Directory? _drafts;

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

    ids.addAll(await _draftReferencedMediaIds());

    return ids;
  }

  Future<Set<String>> _draftReferencedMediaIds() async {
    final drafts = _drafts;
    if (drafts == null || !await drafts.exists()) {
      return const <String>{};
    }

    final prefixes = <String>{};
    await for (final entity in drafts.list(followLinks: false)) {
      if (entity is! File || p.extension(entity.path) != draftExtension) {
        continue;
      }
      try {
        prefixes.addAll(blobPrefixesIn(await entity.readAsString()));
      } on FileSystemException {
        continue;
      }
    }

    final ids = <String>{};
    for (final prefix in prefixes) {
      ids.addAll(await _idsWithPrefix(prefix));
    }
    return ids;
  }

  Future<List<String>> _idsWithPrefix(String prefix) async {
    final upper = blobPrefixUpperBound(prefix);
    final rows = await (_db.select(_db.mediaBlobs)
          ..where(
            (t) => upper == null
                ? t.id.isBiggerOrEqualValue(prefix)
                : t.id.isBiggerOrEqualValue(prefix) &
                    t.id.isSmallerThanValue(upper),
          ))
        .get();
    return rows.map((row) => row.id).toList(growable: false);
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
