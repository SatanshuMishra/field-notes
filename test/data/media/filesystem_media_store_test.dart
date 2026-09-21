import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:field_notes/data/database/app_database.dart' hide MediaBlob;
import 'package:field_notes/data/media/blob_paths.dart';
import 'package:field_notes/data/media/blob_prefix.dart';
import 'package:field_notes/data/media/content_hash.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/media/media_exceptions.dart';
import 'package:field_notes/domain/models/media_blob.dart';
import 'package:field_notes/domain/models/media_kind.dart';

import 'media_test_support.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late FilesystemMediaStore store;

  setUp(() async {
    db = newTestDatabase();
    root = await newTempRoot();
    store = FilesystemMediaStore(database: db, root: root, clock: () => 1234);
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('putBytes content-addresses the blob and writes it to disk', () async {
    final bytes = [10, 20, 30, 40];

    final blob = await store.putBytes(
      bytes: bytes,
      mime: 'image/jpeg',
      kind: MediaKind.photo,
      width: 100,
      height: 80,
    );

    expect(blob.id, sha256Hex(bytes));
    expect(
      blob.relPath,
      relPathForBlob(
        id: blob.id,
        mime: 'image/jpeg',
        kind: MediaKind.photo,
      ),
    );
    expect(p.extension(blob.relPath), '.jpg');
    expect(blob.mime, 'image/jpeg');
    expect(blob.kind, MediaKind.photo);
    expect(blob.bytes, 4);
    expect(blob.width, 100);
    expect(blob.height, 80);
    expect(blob.createdAt, 1234);

    final file = File(store.absolutePath(blob));
    expect(file.existsSync(), isTrue);
    expect(await file.readAsBytes(), bytes);
  });

  test('putBytes dedupes identical content to a single row and file', () async {
    final first = await store.putBytes(
      bytes: [1, 2, 3],
      mime: 'image/jpeg',
      kind: MediaKind.photo,
    );
    final second = await store.putBytes(
      bytes: [1, 2, 3],
      mime: 'image/png',
      kind: MediaKind.photo,
    );

    expect(second.id, first.id);
    expect(second.mime, 'image/jpeg');

    final rows = await db.select(db.mediaBlobs).get();
    expect(rows.length, 1);
  });

  test('blobById returns the stored blob and null for an unknown id', () async {
    final blob = await store.putBytes(
      bytes: [9],
      mime: 'audio/aac',
      kind: MediaKind.audio,
      durationMs: 3000,
    );

    final loaded = await store.blobById(blob.id);
    expect(loaded, isNotNull);
    expect(loaded!.kind, MediaKind.audio);
    expect(loaded.durationMs, 3000);

    expect(await store.blobById('deadbeef'), isNull);
  });

  Future<void> insertBlobRow(String id) {
    return db.into(db.mediaBlobs).insert(
          MediaBlobsCompanion.insert(
            id: id,
            relPath: relPathForId(id),
            mime: 'image/jpeg',
            kind: 'photo',
            bytes: 1,
            createdAt: 0,
          ),
        );
  }

  group('blobByPrefix', () {
    test('resolves a 12-hex prefix to the one blob that matches', () async {
      final blob = await store.putBytes(
        bytes: [4, 5, 6],
        mime: 'image/jpeg',
        kind: MediaKind.photo,
      );

      final found = await store.blobByPrefix(blobPrefixOf(blob.id));

      expect(found, isNotNull);
      expect(found!.id, blob.id);
    });

    test('returns nothing when no id starts with the prefix', () async {
      await store.putBytes(
        bytes: [4, 5, 6],
        mime: 'image/jpeg',
        kind: MediaKind.photo,
      );

      expect(await store.blobByPrefix('0' * 12), isNull);
    });

    test('returns nothing when the prefix is ambiguous', () async {
      await insertBlobRow('abcdef0123450000${'0' * 48}');
      await insertBlobRow('abcdef0123451111${'0' * 48}');

      expect(await store.blobByPrefix('abcdef012345'), isNull);
    });

    test('rejects a malformed prefix without touching the table', () async {
      expect(await store.blobByPrefix('abc'), isNull);
      expect(await store.blobByPrefix('ABCDEF012345'), isNull);
      expect(await store.blobByPrefix('abcdefghijkl'), isNull);
    });

    test('a prefix at the top of the hex range still matches', () async {
      final id = 'f' * 64;
      await insertBlobRow(id);

      final found = await store.blobByPrefix('f' * 12);

      expect(found?.id, id);
    });

    test('the range bound excludes a neighbour just outside it', () async {
      await insertBlobRow('ab9${'0' * 61}');
      await insertBlobRow('aba${'0' * 61}');

      final found = await store.blobByPrefix('ab9${'0' * 9}');

      expect(found?.id, 'ab9${'0' * 61}');
    });
  });

  group('uniquePrefixFor', () {
    test('hands back the 12-hex prefix when nothing collides', () async {
      final id = 'abcdef012345${'0' * 52}';
      await insertBlobRow(id);

      expect(await store.uniquePrefixFor(id), 'abcdef012345');
    });

    test('extends in 4-character steps past a colliding neighbour', () async {
      final id = 'abcdef0123450000${'0' * 48}';
      await insertBlobRow(id);
      await insertBlobRow('abcdef0123451111${'0' * 48}');

      expect(await store.uniquePrefixFor(id), 'abcdef0123450000');
    });

    test('extends twice when the neighbour agrees for 16 characters',
        () async {
      final id = 'abcdef01234500001111${'0' * 44}';
      await insertBlobRow(id);
      await insertBlobRow('abcdef01234500002222${'0' * 44}');

      expect(await store.uniquePrefixFor(id), 'abcdef01234500001111');
    });

    test('falls back to the full digest rather than a non-hex id', () async {
      expect(await store.uniquePrefixFor('not-a-digest'), 'not-a-digest');
    });
  });

  test('putFile streams the source through the hash and dedupes by content',
      () async {
    final srcDir = await Directory.systemTemp.createTemp('fn_src');
    final source = File(p.join(srcDir.path, 'clip.mp4'));
    final content = List<int>.generate(5000, (i) => i % 256);
    await source.writeAsBytes(content);

    final blob = await store.putFile(
      source: source,
      mime: 'video/mp4',
      kind: MediaKind.video,
      durationMs: 4200,
    );

    expect(blob.id, sha256Hex(content));
    expect(blob.bytes, 5000);
    expect(blob.durationMs, 4200);
    expect(await File(store.absolutePath(blob)).readAsBytes(), content);

    final viaBytes = await store.putBytes(
      bytes: content,
      mime: 'video/mp4',
      kind: MediaKind.video,
    );
    expect(viaBytes.id, blob.id);

    final rows = await db.select(db.mediaBlobs).get();
    expect(rows.length, 1);

    await srcDir.delete(recursive: true);
  });

  test('absolutePath falls back to a legacy file the row still points past',
      () async {
    final bytes = [7, 7, 7, 7];
    final id = sha256Hex(bytes);
    final legacy = relPathForId(id);
    await File(p.join(root.path, legacy)).create(recursive: true);
    await File(p.join(root.path, legacy)).writeAsBytes(bytes, flush: true);

    final blob = MediaBlob(
      id: id,
      relPath: relPathForBlob(
        id: id,
        mime: 'audio/mp4',
        kind: MediaKind.audio,
      ),
      mime: 'audio/mp4',
      kind: MediaKind.audio,
      bytes: bytes.length,
      createdAt: 0,
    );

    expect(store.absolutePath(blob), p.join(root.path, legacy));
  });

  test('absolutePath falls back to the derived path a stale row misses',
      () async {
    final bytes = [8, 8, 8, 8];
    final blob = await store.putBytes(
      bytes: bytes,
      mime: 'audio/mp4',
      kind: MediaKind.audio,
    );
    final stale = MediaBlob(
      id: blob.id,
      relPath: relPathForId(blob.id),
      mime: blob.mime,
      kind: blob.kind,
      bytes: blob.bytes,
      createdAt: blob.createdAt,
    );

    expect(
      store.absolutePath(stale),
      p.join(root.path, blob.relPath),
    );
  });

  test('absolutePath returns the stored path when nothing exists on disk', () {
    final id = sha256Hex([9, 9, 9, 9]);
    final relPath =
        relPathForBlob(id: id, mime: 'image/jpeg', kind: MediaKind.photo);
    final blob = MediaBlob(
      id: id,
      relPath: relPath,
      mime: 'image/jpeg',
      kind: MediaKind.photo,
      bytes: 4,
      createdAt: 0,
    );

    expect(store.absolutePath(blob), p.join(root.path, relPath));
  });

  test('a write failure surfaces MediaWriteException and stores no row',
      () async {
    final bytes = [42, 42, 42];
    final id = sha256Hex(bytes);
    final shardPath = p.dirname(p.join(root.path, relPathForId(id)));
    await File(shardPath).create(recursive: true);

    await expectLater(
      store.putBytes(bytes: bytes, mime: 'image/jpeg', kind: MediaKind.photo),
      throwsA(isA<MediaWriteException>()),
    );

    expect(await store.blobById(id), isNull);
    final rows = await db.select(db.mediaBlobs).get();
    expect(rows, isEmpty);
  });
}
