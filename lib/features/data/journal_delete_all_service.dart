import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/database/app_database.dart' as db;
import '../../data/media/blob_paths.dart';
import '../../domain/services/delete_all_service.dart';
import 'data_exceptions.dart';

const String _tmpSubdir = '.tmp';

class JournalDeleteAllService implements DeleteAllService {
  JournalDeleteAllService({
    required db.AppDatabase database,
    required this._mediaRoot,
    this._draftsRoot,
  }) : _db = database;

  final db.AppDatabase _db;
  final Directory _mediaRoot;
  final Directory? _draftsRoot;

  @override
  Future<DeleteAllResult> deleteAll() async {
    try {
      final counts = await _db.transaction(() async {
        final photos = await _db.delete(_db.entryPhotos).go();
        final entries = await _db.delete(_db.entries).go();
        final days = await _db.delete(_db.days).go();
        final blobs = await _db.delete(_db.mediaBlobs).go();
        return (photos: photos, entries: entries, days: days, blobs: blobs);
      });

      final deletedFiles = await _wipeMediaFiles();
      await _wipeDrafts();

      return DeleteAllResult(
        deletedDays: counts.days,
        deletedEntries: counts.entries,
        deletedPhotos: counts.photos,
        deletedMediaBlobs: counts.blobs,
        deletedFiles: deletedFiles,
      );
    } on DeleteAllException {
      rethrow;
    } catch (error) {
      throw DeleteAllException('failed to delete all journal data', error);
    }
  }

  Future<int> _wipeMediaFiles() async {
    var deleted = 0;
    final blobsDir = Directory(p.join(_mediaRoot.path, blobsSubdir));
    if (await blobsDir.exists()) {
      await for (final entity
          in blobsDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          deleted++;
        }
      }
      await blobsDir.delete(recursive: true);
    }

    final tmpDir = Directory(p.join(_mediaRoot.path, _tmpSubdir));
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }

    return deleted;
  }

  Future<void> _wipeDrafts() async {
    final draftsRoot = _draftsRoot;
    if (draftsRoot != null && await draftsRoot.exists()) {
      await draftsRoot.delete(recursive: true);
    }
  }
}
