import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../domain/models/media_blob.dart';
import '../../domain/models/media_kind.dart';
import '../../domain/services/media_store.dart';
import '../database/app_database.dart' as db;
import 'blob_paths.dart';
import 'content_hash.dart';
import 'media_exceptions.dart';
import 'media_gc.dart';

const String _tmpSubdir = '.tmp';

int _systemMillis() => DateTime.now().millisecondsSinceEpoch;

class FilesystemMediaStore implements MediaStore {
  FilesystemMediaStore({
    required db.AppDatabase database,
    required this._root,
    int Function()? clock,
  })  : _db = database,
        _clock = clock ?? _systemMillis;

  final db.AppDatabase _db;
  final Directory _root;
  final int Function() _clock;
  final Random _random = Random();

  @override
  Future<MediaBlob> putBytes({
    required List<int> bytes,
    required String mime,
    required MediaKind kind,
    int? width,
    int? height,
    int? durationMs,
  }) {
    return _finalize(
      id: sha256Hex(bytes),
      bytes: bytes.length,
      write: (tmpPath) async {
        await File(tmpPath).writeAsBytes(bytes, flush: true);
      },
      mime: mime,
      kind: kind,
      width: width,
      height: height,
      durationMs: durationMs,
    );
  }

  @override
  Future<MediaBlob> putFile({
    required File source,
    required String mime,
    required MediaKind kind,
    int? width,
    int? height,
    int? durationMs,
  }) async {
    final id = await sha256HexOfStream(source.openRead());
    final length = await source.length();
    return _finalize(
      id: id,
      bytes: length,
      write: (tmpPath) async {
        await source.copy(tmpPath);
      },
      mime: mime,
      kind: kind,
      width: width,
      height: height,
      durationMs: durationMs,
    );
  }

  @override
  Future<MediaBlob?> blobById(String id) async {
    final row = await (_db.select(_db.mediaBlobs)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  String absolutePath(MediaBlob blob) {
    final stored = p.join(_root.path, blob.relPath);
    if (_existsSync(stored) || blob.id.length <= blobShardLength) {
      return stored;
    }
    final fallbacks = <String>[
      p.join(
        _root.path,
        relPathForBlob(id: blob.id, mime: blob.mime, kind: blob.kind),
      ),
      p.join(_root.path, relPathForId(blob.id)),
    ];
    for (final candidate in fallbacks) {
      if (_existsSync(candidate)) {
        return candidate;
      }
    }
    return stored;
  }

  bool _existsSync(String path) {
    try {
      return File(path).existsSync();
    } on FileSystemException {
      return false;
    }
  }

  @override
  Future<int> collectGarbage() {
    return MediaGarbageCollector(database: _db, root: _root).collectGarbage();
  }

  Future<MediaBlob> _finalize({
    required String id,
    required int bytes,
    required Future<void> Function(String tmpPath) write,
    required String mime,
    required MediaKind kind,
    int? width,
    int? height,
    int? durationMs,
  }) async {
    final existing = await blobById(id);
    if (existing != null) {
      return existing;
    }

    final relPath = relPathForBlob(id: id, mime: mime, kind: kind);
    final finalPath = p.join(_root.path, relPath);
    await _atomicWrite(finalPath: finalPath, write: write, id: id);

    try {
      await _db.into(_db.mediaBlobs).insert(
            db.MediaBlobsCompanion.insert(
              id: id,
              relPath: relPath,
              mime: mime,
              kind: kind.id,
              bytes: bytes,
              width: Value(width),
              height: Value(height),
              durationMs: Value(durationMs),
              createdAt: _clock(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    } catch (_) {
      await _bestEffortDelete(File(finalPath));
      rethrow;
    }

    final stored = await blobById(id);
    if (stored == null) {
      throw MediaWriteException('media blob $id was not stored');
    }
    return stored;
  }

  Future<void> _atomicWrite({
    required String finalPath,
    required Future<void> Function(String tmpPath) write,
    required String id,
  }) async {
    final tmpDir = Directory(p.join(_root.path, _tmpSubdir));
    final shardDir = Directory(p.dirname(finalPath));
    File? tmp;
    try {
      await tmpDir.create(recursive: true);
      await shardDir.create(recursive: true);
      tmp = File(p.join(tmpDir.path, _tmpName()));
      await write(tmp.path);
      await tmp.rename(finalPath);
    } on FileSystemException catch (e) {
      if (tmp != null) {
        await _bestEffortDelete(tmp);
      }
      throw MediaWriteException('failed to write media blob $id', e);
    }
  }

  String _tmpName() =>
      'blob-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}.part';

  Future<void> _bestEffortDelete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      return;
    }
  }

  MediaBlob _toDomain(db.MediaBlob row) {
    final kind = MediaKind.fromId(row.kind);
    if (kind == null) {
      throw MediaReadException(
        'unknown media kind "${row.kind}" for blob ${row.id}',
      );
    }
    return MediaBlob(
      id: row.id,
      relPath: row.relPath,
      mime: row.mime,
      kind: kind,
      bytes: row.bytes,
      width: row.width,
      height: row.height,
      durationMs: row.durationMs,
      createdAt: row.createdAt,
    );
  }
}
