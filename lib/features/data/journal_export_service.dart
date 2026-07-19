import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/database/app_database.dart' as db;
import '../../domain/services/export_service.dart';
import 'data_exceptions.dart';

const int exportFormatVersion = 1;
const String exportAppName = 'Field Notes';

int _systemMillis() => DateTime.now().millisecondsSinceEpoch;

class JournalExportService implements ExportService {
  JournalExportService({
    required db.AppDatabase database,
    required this._mediaRoot,
    int Function()? clock,
  })  : _db = database,
        _clock = clock ?? _systemMillis;

  final db.AppDatabase _db;
  final Directory _mediaRoot;
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
      for (final blob in blobs) {
        final file = File(p.join(_mediaRoot.path, blob.relPath));
        if (await file.exists()) {
          mediaFiles[blob.relPath] = await file.readAsBytes();
        }
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
      );
    } on ExportException {
      rethrow;
    } catch (error) {
      throw ExportException('failed to build export bundle', error);
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
