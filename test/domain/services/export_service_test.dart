import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/media/blob_paths.dart';
import 'package:field_notes/data/media/content_hash.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/domain/models/media_kind.dart';
import 'package:field_notes/features/data/journal_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Future<String> seedBlob(
  AppDatabase db,
  Directory root,
  List<int> bytes,
  String mime,
  String kind,
) async {
  final id = sha256Hex(bytes);
  final relPath = relPathForBlob(
    id: id,
    mime: mime,
    kind: MediaKind.fromId(kind)!,
  );
  final file = File(p.join(root.path, relPath));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  await db.into(db.mediaBlobs).insert(
        MediaBlobsCompanion.insert(
          id: id,
          relPath: relPath,
          mime: mime,
          kind: kind,
          bytes: bytes.length,
          createdAt: 0,
        ),
      );
  return id;
}

void main() {
  late AppDatabase db;
  late Directory root;
  late JournalExportService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('fn_export');
    service = JournalExportService(
      database: db,
      mediaStore: FilesystemMediaStore(database: db, root: root),
      clock: () => 1751000000000,
    );
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('buildBundle captures every row, tombstones, and media bytes',
      () async {
    final photoBytes = [1, 2, 3, 4];
    final audioBytes = [9, 9];
    final photoId = await seedBlob(db, root, photoBytes, 'image/jpeg', 'photo');
    final audioId = await seedBlob(db, root, audioBytes, 'audio/aac', 'audio');

    await db.into(db.days).insert(DaysCompanion.insert(
          id: 'd1',
          date: '2026-07-14',
          moodId: const Value('happy'),
          createdAt: 100,
          updatedAt: 100,
        ));
    await db.into(db.days).insert(DaysCompanion.insert(
          id: 'd2',
          date: '2026-07-13',
          createdAt: 90,
          updatedAt: 95,
          deletedAt: const Value(96),
        ));
    await db.into(db.entries).insert(EntriesCompanion.insert(
          id: 'e1',
          dayId: 'd1',
          type: 'text',
          textContent: const Value('hello world'),
          createdAt: 110,
          updatedAt: 110,
        ));
    await db.into(db.entries).insert(EntriesCompanion.insert(
          id: 'e2',
          dayId: 'd1',
          type: 'voice',
          mediaId: Value(audioId),
          durationMs: const Value(3000),
          createdAt: 120,
          updatedAt: 120,
        ));
    await db.into(db.entryPhotos).insert(EntryPhotosCompanion.insert(
          id: 'ph1',
          entryId: 'e1',
          mediaId: photoId,
          sortOrder: 0,
          createdAt: 130,
          updatedAt: 130,
        ));
    await db.into(db.settings).insert(
        SettingsCompanion.insert(key: 'text_size', value: '2'));
    await db.into(db.settings).insert(
        SettingsCompanion.insert(key: 'sound_enabled', value: 'false'));

    final bundle = await service.buildBundle();

    expect(bundle.manifest.formatVersion, 1);
    expect(bundle.manifest.appName, 'Field Notes');
    expect(bundle.manifest.exportedAt, 1751000000000);
    expect(bundle.manifest.stats.dayCount, 2);
    expect(bundle.manifest.stats.entryCount, 2);
    expect(bundle.manifest.stats.photoCount, 1);
    expect(bundle.manifest.stats.mediaBlobCount, 2);

    final journal = jsonDecode(bundle.journalJson) as Map<String, Object?>;
    final days = (journal['days'] as List).cast<Map<String, Object?>>();
    final deletedDay = days.firstWhere((d) => d['id'] == 'd2');
    expect(deletedDay['deletedAt'], 96);
    final activeDay = days.firstWhere((d) => d['id'] == 'd1');
    expect(activeDay['moodId'], 'happy');

    final entries = (journal['entries'] as List).cast<Map<String, Object?>>();
    final voice = entries.firstWhere((e) => e['id'] == 'e2');
    expect(voice['type'], 'voice');
    expect(voice['mediaId'], audioId);
    expect(voice['durationMs'], 3000);

    final photos =
        (journal['entryPhotos'] as List).cast<Map<String, Object?>>();
    expect(photos.single['mediaId'], photoId);

    final mediaBlobs =
        (journal['mediaBlobs'] as List).cast<Map<String, Object?>>();
    expect(mediaBlobs.map((b) => b['id']), containsAll([photoId, audioId]));
    final audioBlob = mediaBlobs.firstWhere((b) => b['id'] == audioId);
    expect(audioBlob['mime'], 'audio/aac');
    expect(audioBlob['kind'], 'audio');
    expect(audioBlob['bytes'], audioBytes.length);
    expect(
      audioBlob['relPath'],
      relPathForBlob(id: audioId, mime: 'audio/aac', kind: MediaKind.audio),
    );

    final settings = journal['settings'] as Map<String, Object?>;
    expect(settings['text_size'], '2');
    expect(settings['sound_enabled'], 'false');

    expect(
      bundle.mediaFiles[
          relPathForBlob(id: photoId, mime: 'image/jpeg', kind: MediaKind.photo)],
      photoBytes,
    );
    expect(
      bundle.mediaFiles[
          relPathForBlob(id: audioId, mime: 'audio/aac', kind: MediaKind.audio)],
      audioBytes,
    );
    for (final key in bundle.mediaFiles.keys) {
      expect(p.extension(key), isNotEmpty, reason: 'archive entry $key');
    }
    expect(bundle.suggestedFileName, 'field-notes-export-20250627-045320.zip');
  });

  test('buildBundle skips a media row whose file is missing on disk',
      () async {
    await db.into(db.mediaBlobs).insert(
          MediaBlobsCompanion.insert(
            id: 'a1b2c3',
            relPath: relPathForId('a1b2c3'),
            mime: 'image/jpeg',
            kind: 'photo',
            bytes: 3,
            createdAt: 0,
          ),
        );

    final bundle = await service.buildBundle();

    expect(bundle.manifest.stats.mediaBlobCount, 1);
    expect(bundle.mediaFiles, isEmpty);
    expect(bundle.skippedMediaIds, ['a1b2c3']);
  });

  test('buildBundle exports a blob whose row still points at the legacy path',
      () async {
    final bytes = [4, 4, 4, 4];
    final id = sha256Hex(bytes);
    final migrated =
        relPathForBlob(id: id, mime: 'video/quicktime', kind: MediaKind.video);
    final file = File(p.join(root.path, migrated));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    await db.into(db.mediaBlobs).insert(
          MediaBlobsCompanion.insert(
            id: id,
            relPath: relPathForId(id),
            mime: 'video/quicktime',
            kind: 'video',
            bytes: bytes.length,
            createdAt: 0,
          ),
        );

    final bundle = await service.buildBundle();

    expect(bundle.skippedMediaIds, isEmpty);
    expect(bundle.mediaFiles[migrated], bytes);
    expect(p.extension(bundle.mediaFiles.keys.single), '.mov');
  });
}
