import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/media/blob_paths.dart';
import 'package:field_notes/data/media/content_hash.dart';
import 'package:field_notes/domain/models/media_kind.dart';
import 'package:field_notes/features/data/journal_delete_all_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Future<String> seedBlobWithFile(
  AppDatabase db,
  Directory root,
  List<int> bytes,
) async {
  final id = sha256Hex(bytes);
  final relPath =
      relPathForBlob(id: id, mime: 'image/jpeg', kind: MediaKind.photo);
  final file = File(p.join(root.path, relPath));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  await db.into(db.mediaBlobs).insert(
        MediaBlobsCompanion.insert(
          id: id,
          relPath: relPath,
          mime: 'image/jpeg',
          kind: 'photo',
          bytes: bytes.length,
          createdAt: 0,
        ),
      );
  return id;
}

void main() {
  late AppDatabase db;
  late Directory root;
  late JournalDeleteAllService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('fn_delete');
    service = JournalDeleteAllService(database: db, mediaRoot: root);
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('deleteAll clears content and media, preserves settings, returns counts',
      () async {
    final photoId = await seedBlobWithFile(db, root, [1, 2, 3]);
    final audioId = await seedBlobWithFile(db, root, [4, 5]);

    await db.into(db.days).insert(DaysCompanion.insert(
          id: 'd1',
          date: '2026-07-14',
          createdAt: 100,
          updatedAt: 100,
        ));
    await db.into(db.entries).insert(EntriesCompanion.insert(
          id: 'e1',
          dayId: 'd1',
          type: 'voice',
          mediaId: Value(audioId),
          createdAt: 110,
          updatedAt: 110,
        ));
    await db.into(db.entries).insert(EntriesCompanion.insert(
          id: 'e2',
          dayId: 'd1',
          type: 'text',
          createdAt: 111,
          updatedAt: 111,
          deletedAt: const Value(112),
        ));
    await db.into(db.entryPhotos).insert(EntryPhotosCompanion.insert(
          id: 'ph1',
          entryId: 'e1',
          mediaId: photoId,
          sortOrder: 0,
          createdAt: 120,
          updatedAt: 120,
        ));
    await db.into(db.settings).insert(
        SettingsCompanion.insert(key: 'text_size', value: '3'));

    final result = await service.deleteAll();

    expect(result.deletedDays, 1);
    expect(result.deletedEntries, 2);
    expect(result.deletedPhotos, 1);
    expect(result.deletedMediaBlobs, 2);
    expect(result.deletedFiles, 2);

    expect(await db.select(db.days).get(), isEmpty);
    expect(await db.select(db.entries).get(), isEmpty);
    expect(await db.select(db.entryPhotos).get(), isEmpty);
    expect(await db.select(db.mediaBlobs).get(), isEmpty);

    final settings = await db.select(db.settings).get();
    expect(settings.single.key, 'text_size');
    expect(settings.single.value, '3');

    final blobsDir = Directory(p.join(root.path, blobsSubdir));
    expect(await blobsDir.exists(), isFalse);
  });

  test('deleteAll on an empty store returns zero counts and does not throw',
      () async {
    final result = await service.deleteAll();

    expect(result.deletedDays, 0);
    expect(result.deletedEntries, 0);
    expect(result.deletedPhotos, 0);
    expect(result.deletedMediaBlobs, 0);
    expect(result.deletedFiles, 0);
  });
}
