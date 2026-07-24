import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../data/database/app_database.dart' as db;
import '../../data/media/blob_paths.dart';
import '../../data/media/media_exceptions.dart';
import '../../domain/services/export_service.dart';
import '../../domain/services/media_store.dart';
import 'data_exceptions.dart';

const int exportFormatVersion = 1;
const String exportAppName = 'Field Notes';

int _systemMillis() => DateTime.now().millisecondsSinceEpoch;

class JournalExportService implements ExportService {
  JournalExportService({
    required db.AppDatabase database,
    required this._mediaStore,
    int Function()? clock,
  })  : _db = database,
        _clock = clock ?? _systemMillis;

  final db.AppDatabase _db;
  final MediaStore _mediaStore;
  final int Function() _clock;

  @override
  Future<ExportBundle> buildBundle() async {
    try {
      final days = await _db.select(_db.days).get();
      final entries = await _db.select(_db.entries).get();
      final photos = await _db.select(_db.entryPhotos).get();
      final blobs = await _db.select(_db.mediaBlobs).get();
      final settings = await _db.select(_db.settings).get();

      final journal = <String, Object?>{
        'days': [for (final d in days) _dayJson(d)],
        'entries': [for (final e in entries) _entryJson(e)],
        'entryPhotos': [for (final ph in photos) _photoJson(ph)],
        'mediaBlobs': [for (final b in blobs) _mediaBlobJson(b)],
        'settings': {for (final s in settings) s.key: s.value},
      };

      final mediaFiles = <String, List<int>>{};
      final skippedMediaIds = <String>[];
      for (final blob in blobs) {
        final bytes = await _readMediaBytes(blob.id);
        if (bytes == null) {
          skippedMediaIds.add(blob.id);
          continue;
        }
        mediaFiles[bytes.archiveName] = bytes.content;
      }
      if (skippedMediaIds.isNotEmpty) {
        debugPrint('Export skipped ${skippedMediaIds.length} unreadable media '
            'blobs: ${skippedMediaIds.join(', ')}');
      }

      final manifest = ExportManifest(
        formatVersion: exportFormatVersion,
        appName: exportAppName,
        exportedAt: _clock(),
        stats: ExportStats(
          dayCount: days.length,
          entryCount: entries.length,
          photoCount: photos.length,
          mediaBlobCount: blobs.length,
        ),
      );

      return ExportBundle(
        manifest: manifest,
        journalJson: const JsonEncoder.withIndent('  ').convert(journal),
        mediaFiles: mediaFiles,
        skippedMediaIds: List<String>.unmodifiable(skippedMediaIds),
      );
    } on ExportException {
      rethrow;
    } catch (error) {
      throw ExportException('failed to build export bundle', error);
    }
  }

  Future<({String archiveName, List<int> content})?> _readMediaBytes(
    String id,
  ) async {
    try {
      final blob = await _mediaStore.blobById(id);
      if (blob == null) {
        return null;
      }
      final file = File(_mediaStore.absolutePath(blob));
      if (!await file.exists()) {
        return null;
      }
      return (
        archiveName: relPathForBlob(
          id: blob.id,
          mime: blob.mime,
          kind: blob.kind,
        ),
        content: await file.readAsBytes(),
      );
    } on MediaReadException catch (error) {
      debugPrint('Export could not read media blob "$id": $error');
      return null;
    } on FileSystemException catch (error) {
      debugPrint('Export could not read media blob "$id": $error');
      return null;
    }
  }

  Map<String, Object?> _dayJson(db.Day d) => {
        'id': d.id,
        'date': d.date,
        'moodId': d.moodId,
        'createdAt': d.createdAt,
        'updatedAt': d.updatedAt,
        'deletedAt': d.deletedAt,
      };

  Map<String, Object?> _entryJson(db.Entry e) => {
        'id': e.id,
        'dayId': e.dayId,
        'type': e.type,
        'textContent': e.textContent,
        'mediaId': e.mediaId,
        'thumbnailMediaId': e.thumbnailMediaId,
        'durationMs': e.durationMs,
        'createdAt': e.createdAt,
        'updatedAt': e.updatedAt,
        'deletedAt': e.deletedAt,
      };

  Map<String, Object?> _photoJson(db.EntryPhoto ph) => {
        'id': ph.id,
        'entryId': ph.entryId,
        'mediaId': ph.mediaId,
        'sortOrder': ph.sortOrder,
        'createdAt': ph.createdAt,
        'updatedAt': ph.updatedAt,
        'deletedAt': ph.deletedAt,
      };

  Map<String, Object?> _mediaBlobJson(db.MediaBlob b) => {
        'id': b.id,
        'relPath': b.relPath,
        'mime': b.mime,
        'kind': b.kind,
        'bytes': b.bytes,
        'width': b.width,
        'height': b.height,
        'durationMs': b.durationMs,
        'createdAt': b.createdAt,
      };
}
