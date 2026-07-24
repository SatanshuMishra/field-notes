import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../domain/models/media_kind.dart';
import '../database/app_database.dart';
import 'blob_paths.dart';

class BlobExtensionBackfillResult {
  const BlobExtensionBackfillResult({
    this.scanned = 0,
    this.renamed = 0,
    this.adopted = 0,
    this.missing = 0,
    this.failed = 0,
  });

  final int scanned;
  final int renamed;
  final int adopted;
  final int missing;
  final int failed;

  @override
  String toString() => 'BlobExtensionBackfillResult(scanned: $scanned, '
      'renamed: $renamed, adopted: $adopted, missing: $missing, '
      'failed: $failed)';
}

class BlobExtensionBackfill {
  BlobExtensionBackfill({
    required AppDatabase database,
    required this._root,
  }) : _db = database;

  final AppDatabase _db;
  final Directory _root;

  Future<BlobExtensionBackfillResult> run() async {
    if (await _pendingCount() == 0) {
      return const BlobExtensionBackfillResult();
    }

    final rows = await _pendingRows();
    int renamed = 0;
    int adopted = 0;
    int missing = 0;
    int failed = 0;

    for (final row in rows) {
      switch (await _migrateRow(row)) {
        case _RowOutcome.renamed:
          renamed++;
        case _RowOutcome.adopted:
          adopted++;
        case _RowOutcome.missing:
          missing++;
        case _RowOutcome.failed:
          failed++;
        case _RowOutcome.skipped:
          break;
      }
    }

    final result = BlobExtensionBackfillResult(
      scanned: rows.length,
      renamed: renamed,
      adopted: adopted,
      missing: missing,
      failed: failed,
    );
    if (missing > 0 || failed > 0) {
      debugPrint('Media blob extension backfill incomplete: $result');
    }
    return result;
  }

  Future<int> _pendingCount() {
    final count = _db.mediaBlobs.id.count();
    final query = _db.selectOnly(_db.mediaBlobs)
      ..addColumns([count])
      ..where(_db.mediaBlobs.relPath.like('%.%').not());
    return query.map((row) => row.read(count) ?? 0).getSingle();
  }

  Future<List<MediaBlob>> _pendingRows() {
    return (_db.select(_db.mediaBlobs)
          ..where((t) => t.relPath.like('%.%').not()))
        .get();
  }

  Future<_RowOutcome> _migrateRow(MediaBlob row) async {
    if (p.extension(row.relPath).isNotEmpty) {
      return _RowOutcome.skipped;
    }
    final kind = MediaKind.fromId(row.kind);
    if (kind == null || row.id.length <= blobShardLength) {
      debugPrint('Media blob "${row.id}" is not migratable: '
          'kind "${row.kind}"');
      return _RowOutcome.failed;
    }

    final target = relPathForBlob(id: row.id, mime: row.mime, kind: kind);
    if (target == row.relPath) {
      return _RowOutcome.skipped;
    }
    if (!_isContained(row.relPath) || !_isContained(target)) {
      debugPrint('Media blob "${row.id}" resolves outside the media root: '
          '"${row.relPath}"');
      return _RowOutcome.failed;
    }

    final legacy = File(p.join(_root.path, row.relPath));
    final migrated = File(p.join(_root.path, target));

    try {
      if (await migrated.exists()) {
        await _writeRelPath(row.id, target);
        await _dropVerifiedDuplicate(
          legacy: legacy,
          migrated: migrated,
          bytes: row.bytes,
        );
        return _RowOutcome.adopted;
      }
      if (!await legacy.exists()) {
        return _RowOutcome.missing;
      }
      await migrated.parent.create(recursive: true);
      await legacy.rename(migrated.path);
      await _writeRelPath(row.id, target);
    } catch (error, stackTrace) {
      debugPrint('Media blob "${row.id}" extension backfill failed: '
          '$error\n$stackTrace');
      return _RowOutcome.failed;
    }

    return _RowOutcome.renamed;
  }

  bool _isContained(String relPath) {
    if (relPath.isEmpty || !p.isRelative(relPath)) {
      return false;
    }
    final root = p.normalize(p.absolute(_root.path));
    return p.isWithin(root, p.normalize(p.join(root, relPath)));
  }

  Future<void> _dropVerifiedDuplicate({
    required File legacy,
    required File migrated,
    required int bytes,
  }) async {
    try {
      if (!await legacy.exists()) {
        return;
      }
      if (await legacy.length() != bytes || await migrated.length() != bytes) {
        debugPrint('Media blob duplicate at "${legacy.path}" left in place: '
            'size does not match the recorded $bytes bytes');
        return;
      }
      await legacy.delete();
    } on FileSystemException catch (error) {
      debugPrint('Media blob duplicate cleanup failed: $error');
    }
  }

  Future<void> _writeRelPath(String id, String relPath) {
    return (_db.update(_db.mediaBlobs)..where((t) => t.id.equals(id)))
        .write(MediaBlobsCompanion(relPath: Value(relPath)));
  }
}

enum _RowOutcome { renamed, adopted, missing, failed, skipped }
