import 'dart:io';

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

  Future<int> collectGarbage() async {
    final reachable = await _reachableMediaIds();
    await _sweepFiles(reachable);
    return _sweepRows(reachable);
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
    await for (final entity
        in blobsDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final id = idFromRelPath(p.relative(entity.path, from: _root.path));
      if (id != null && !reachable.contains(id)) {
        await entity.delete();
      }
    }
  }

  Future<int> _sweepRows(Set<String> reachable) async {
    final rows = await _db.select(_db.mediaBlobs).get();
    final unreachable =
        rows.where((row) => !reachable.contains(row.id)).toList();
    if (unreachable.isEmpty) {
      return 0;
    }
    await _db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      for (final row in unreachable) {
        await (_db.delete(_db.mediaBlobs)..where((t) => t.id.equals(row.id)))
            .go();
      }
    } finally {
      await _db.customStatement('PRAGMA foreign_keys = ON');
    }
    return unreachable.length;
  }
}
