import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/sync/engine/pull_cycle.dart';
import 'package:field_notes/data/sync/media/upload_queue.dart';
import 'package:field_notes/domain/models/media_blob.dart' as domain;

const Duration mediaCacheLifetime = Duration(days: 30);

typedef ReachableMediaIds = Future<Set<String>> Function();

int _systemMillis() => DateTime.now().millisecondsSinceEpoch;

final class MediaCache {
  MediaCache({
    required AppDatabase database,
    required this._store,
    required this._reachable,
    int Function()? clock,
  }) : _db = database,
       _clock = clock ?? _systemMillis;

  final AppDatabase _db;
  final FilesystemMediaStore _store;
  final ReachableMediaIds _reachable;
  final int Function() _clock;

  Future<void> recordOpen(String blobId) =>
      (_db.update(
            _db.syncMediaCache,
          )..where((t) => t.blobId.equals(blobId) & t.downloadedAt.isNotNull()))
          .write(SyncMediaCacheCompanion(lastOpenedAt: Value(_clock())));

  Future<int> trim({required bool keepAll}) async {
    if (keepAll) {
      return 0;
    }
    final Set<String> posters = await posterMediaIds(_db);
    final int now = _clock();
    final List<SyncMediaCacheData> rows =
        await (_db.select(_db.syncMediaCache)..where(
              (t) => t.downloadedAt.isNotNull() & t.uploaded.equals(true),
            ))
            .get();
    int trimmed = 0;
    for (final SyncMediaCacheData row in rows) {
      if (posters.contains(row.blobId)) {
        continue;
      }
      final int lastUse = max(row.downloadedAt!, row.lastOpenedAt ?? 0);
      if (now - lastUse < mediaCacheLifetime.inMilliseconds) {
        continue;
      }
      if (await _deleteFile(row.blobId)) {
        trimmed += 1;
      }
    }
    return trimmed;
  }

  Future<int> reclaim() async {
    if (!await pullHasCompleted(_db)) {
      return 0;
    }
    final Set<String> reachable = await _reachable();
    final Set<String> held = <String>{
      for (final SyncMediaCacheData row in await (_db.select(
        _db.syncMediaCache,
      )..where((t) => t.uploaded.equals(true))).get())
        row.blobId,
    };
    int reclaimed = 0;
    for (final MediaBlob row in await _db.select(_db.mediaBlobs).get()) {
      if (reachable.contains(row.id) || !held.contains(row.id)) {
        continue;
      }
      if (await _deleteFile(row.id)) {
        reclaimed += 1;
      }
    }
    return reclaimed;
  }

  Future<bool> _deleteFile(String blobId) async {
    final domain.MediaBlob? blob = await _store.blobById(blobId);
    if (blob == null) {
      return false;
    }
    final File file = File(_store.absolutePath(blob));
    try {
      if (!await file.exists()) {
        return false;
      }
      await file.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }
}
