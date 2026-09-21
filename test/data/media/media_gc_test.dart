import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/media/blob_paths.dart';
import 'package:field_notes/data/media/blob_prefix.dart';
import 'package:field_notes/data/media/content_hash.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/media/media_gc.dart';
import 'package:field_notes/domain/models/media_kind.dart';

import 'media_test_support.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late FilesystemMediaStore store;
  late Directory drafts;

  setUp(() async {
    db = newTestDatabase();
    root = await newTempRoot();
    drafts = await Directory.systemTemp.createTemp('fn_drafts');
    store = FilesystemMediaStore(
      database: db,
      root: root,
      drafts: drafts,
      clock: () => 0,
    );
    await db.into(db.days).insert(
          DaysCompanion.insert(
            id: 'd1',
            date: '2026-07-12',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    if (await drafts.exists()) {
      await drafts.delete(recursive: true);
    }
  });

  Future<void> writeDraft(String name, String source) =>
      File(p.join(drafts.path, name)).writeAsString(source);

  Future<void> insertEntry({
    required String id,
    String type = 'video',
    String? mediaId,
    String? thumbnailMediaId,
    int? deletedAt,
  }) {
    return db.into(db.entries).insert(
          EntriesCompanion.insert(
            id: id,
            dayId: 'd1',
            type: type,
            mediaId: Value(mediaId),
            thumbnailMediaId: Value(thumbnailMediaId),
            createdAt: 0,
            updatedAt: 0,
            deletedAt: Value(deletedAt),
          ),
        );
  }

  test('keeps blobs referenced by active rows and reclaims the rest', () async {
    final video = await store.putBytes(
        bytes: [1, 1, 1], mime: 'video/mp4', kind: MediaKind.video);
    final thumb = await store.putBytes(
        bytes: [2, 2, 2], mime: 'image/jpeg', kind: MediaKind.photo);
    final photo = await store.putBytes(
        bytes: [3, 3, 3], mime: 'image/jpeg', kind: MediaKind.photo);
    final deadAudio = await store.putBytes(
        bytes: [4, 4, 4], mime: 'audio/aac', kind: MediaKind.audio);
    final unreferenced = await store.putBytes(
        bytes: [5, 5, 5], mime: 'image/jpeg', kind: MediaKind.photo);

    await insertEntry(id: 'e1', mediaId: video.id, thumbnailMediaId: thumb.id);
    await db.into(db.entryPhotos).insert(
          EntryPhotosCompanion.insert(
            id: 'p1',
            entryId: 'e1',
            mediaId: photo.id,
            sortOrder: 0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await insertEntry(
        id: 'e2', type: 'voice', mediaId: deadAudio.id, deletedAt: 5);

    final orphanId = sha256Hex([9, 9]);
    final orphanFile = File(p.join(root.path, relPathForId(orphanId)));
    await orphanFile.create(recursive: true);
    await orphanFile.writeAsBytes([9, 9]);

    final extensionedOrphanId = sha256Hex([8, 8]);
    final extensionedOrphanFile = File(p.join(
      root.path,
      relPathForBlob(
        id: extensionedOrphanId,
        mime: 'video/quicktime',
        kind: MediaKind.video,
      ),
    ));
    await extensionedOrphanFile.create(recursive: true);
    await extensionedOrphanFile.writeAsBytes([8, 8]);

    final removed = await store.collectGarbage();

    expect(File(store.absolutePath(video)).existsSync(), isTrue);
    expect(File(store.absolutePath(thumb)).existsSync(), isTrue);
    expect(File(store.absolutePath(photo)).existsSync(), isTrue);
    expect(File(store.absolutePath(deadAudio)).existsSync(), isFalse);
    expect(File(store.absolutePath(unreferenced)).existsSync(), isFalse);
    expect(orphanFile.existsSync(), isFalse);
    expect(extensionedOrphanFile.existsSync(), isFalse);

    expect(await store.blobById(video.id), isNotNull);
    expect(await store.blobById(deadAudio.id), isNull);
    expect(await store.blobById(unreferenced.id), isNull);

    expect(removed, 2);
  });

  test('keeps a deduped blob while any active row still references it',
      () async {
    final shared = await store.putBytes(
        bytes: [7, 7, 7], mime: 'image/jpeg', kind: MediaKind.photo);

    await insertEntry(id: 'e1', mediaId: shared.id);
    await insertEntry(id: 'e2', mediaId: shared.id, deletedAt: 5);

    final removed = await store.collectGarbage();

    expect(removed, 0);
    expect(File(store.absolutePath(shared)).existsSync(), isTrue);
    expect(await store.blobById(shared.id), isNotNull);
  });

  test('a blob referenced only from a draft file survives collection',
      () async {
    final drafted = await store.putBytes(
        bytes: [11, 11, 11], mime: 'image/jpeg', kind: MediaKind.photo);
    final orphan = await store.putBytes(
        bytes: [12, 12, 12], mime: 'image/jpeg', kind: MediaKind.photo);

    await writeDraft(
      '01J0000000000000000000000A.md',
      'a note\n\n![p](photo/${blobPrefixOf(drafted.id)} "right medium")\n',
    );

    final removed = await store.collectGarbage();

    expect(removed, 1);
    expect(await store.blobById(drafted.id), isNotNull);
    expect(File(store.absolutePath(drafted)).existsSync(), isTrue);
    expect(await store.blobById(orphan.id), isNull);
  });

  test('a draft reference written as a full digest also keeps the blob',
      () async {
    final drafted = await store.putBytes(
        bytes: [13, 13, 13], mime: 'image/jpeg', kind: MediaKind.photo);

    await writeDraft(
      '01J0000000000000000000000B.md',
      '![p](photo/${drafted.id})',
    );

    expect(await store.collectGarbage(), 0);
    expect(await store.blobById(drafted.id), isNotNull);
  });

  test('a non-draft file in the drafts directory keeps nothing alive',
      () async {
    final orphan = await store.putBytes(
        bytes: [14, 14, 14], mime: 'image/jpeg', kind: MediaKind.photo);

    await writeDraft(
      'scratch.txt',
      '![p](photo/${blobPrefixOf(orphan.id)})',
    );

    expect(await store.collectGarbage(), 1);
    expect(await store.blobById(orphan.id), isNull);
  });

  test('a store with no drafts root sweeps exactly as before', () async {
    final bare = FilesystemMediaStore(database: db, root: root, clock: () => 0);
    final orphan = await bare.putBytes(
        bytes: [15, 15, 15], mime: 'image/jpeg', kind: MediaKind.photo);

    await writeDraft(
      '01J0000000000000000000000C.md',
      '![p](photo/${blobPrefixOf(orphan.id)})',
    );

    expect(await bare.collectGarbage(), 1);
    expect(await bare.blobById(orphan.id), isNull);
  });

  test('MediaGarbageCollector run directly reclaims an unreachable blob',
      () async {
    final dead = await store.putBytes(
        bytes: [8, 8, 8], mime: 'image/jpeg', kind: MediaKind.photo);

    final removed =
        await MediaGarbageCollector(database: db, root: root).collectGarbage();

    expect(removed, 1);
    expect(File(store.absolutePath(dead)).existsSync(), isFalse);
    expect(await store.blobById(dead.id), isNull);
  });
}
