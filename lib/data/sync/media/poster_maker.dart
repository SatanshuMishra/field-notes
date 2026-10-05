import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/media/jpeg_resize.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/data/sync/media/upload_queue.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:field_notes/domain/models/media_blob.dart' as domain;
import 'package:field_notes/domain/models/media_kind.dart';

const int posterLongEdge = 720;
const int posterMaxBytes = 100 * 1024;
const String posterMime = 'image/jpeg';
const List<int> posterQualities = <int>[82, 70, 60, 50, 40, 30, 20, 10];
const List<String> _posterFields = <String>['posterId'];

final class PosterMaker {
  PosterMaker({
    required AppDatabase database,
    required this._store,
    required this._recorder,
  }) : _db = database;

  final AppDatabase _db;
  final FilesystemMediaStore _store;
  final ChangeRecorder _recorder;

  Future<int> makeMissing() async {
    final Set<String> posters = await posterMediaIds(_db);
    final Set<String> uploaded = <String>{
      for (final SyncMediaCacheData row in await (_db.select(
        _db.syncMediaCache,
      )..where((t) => t.uploaded.equals(true))).get())
        row.blobId,
    };
    final List<MediaBlob> photos =
        await (_db.select(_db.mediaBlobs)..where(
              (t) => t.kind.equals(MediaKind.photo.id) & t.posterId.isNull(),
            ))
            .get();
    int made = 0;
    for (final MediaBlob photo in photos) {
      if (posters.contains(photo.id) || uploaded.contains(photo.id)) {
        continue;
      }
      if (await makePoster(photo.id) != null) {
        made += 1;
      }
    }
    return made;
  }

  Future<String?> makePoster(String blobId) async {
    final domain.MediaBlob? blob = await _store.blobById(blobId);
    if (blob == null || blob.kind != MediaKind.photo) {
      return null;
    }
    final File file = File(_store.absolutePath(blob));
    if (!await file.exists()) {
      return null;
    }
    final Uint8List bytes = await file.readAsBytes();
    final ResizedJpeg? poster = await _smallEnough(bytes, blob);
    if (poster == null) {
      return null;
    }
    final domain.MediaBlob stored = await _store.putBytes(
      bytes: poster.bytes,
      mime: posterMime,
      kind: MediaKind.photo,
      width: poster.width,
      height: poster.height,
    );
    await _db.transaction(() async {
      final MediaBlob? row = await (_db.select(
        _db.mediaBlobs,
      )..where((t) => t.id.equals(blobId))).getSingleOrNull();
      if (row == null || row.posterId != null) {
        return;
      }
      final String clocks = await _recorder.stamp(
        table: SyncedTables.mediaBlobs,
        rowId: blobId,
        fields: _posterFields,
        currentClocks: row.fieldClocks,
      );
      await (_db.update(
        _db.mediaBlobs,
      )..where((t) => t.id.equals(blobId))).write(
        MediaBlobsCompanion(
          posterId: Value(stored.id),
          fieldClocks: Value(clocks),
        ),
      );
    });
    return stored.id;
  }

  Future<ResizedJpeg?> _smallEnough(
    Uint8List bytes,
    domain.MediaBlob blob,
  ) async {
    final (int, int)? size = await _sizeOf(bytes, blob);
    if (size == null) {
      return null;
    }
    for (final int quality in posterQualities) {
      final ResizedJpeg resized;
      try {
        resized = await resizeToJpeg(
          bytes: bytes,
          sourceWidth: size.$1,
          sourceHeight: size.$2,
          longEdge: posterLongEdge,
          quality: quality,
        );
      } on JpegResizeException {
        return null;
      }
      if (resized.bytes.length <= posterMaxBytes) {
        return resized;
      }
    }
    return null;
  }

  Future<(int, int)?> _sizeOf(Uint8List bytes, domain.MediaBlob blob) async {
    final int? width = blob.width;
    final int? height = blob.height;
    if (width != null && height != null && width > 0 && height > 0) {
      return (width, height);
    }
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return (descriptor.width, descriptor.height);
    } on Exception {
      return null;
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
