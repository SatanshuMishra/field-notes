import 'dart:io';

import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/media/blob_extension_backfill.dart';
import 'package:field_notes/data/media/blob_paths.dart';
import 'package:field_notes/data/media/content_hash.dart';
import 'package:field_notes/domain/models/media_kind.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'media_test_support.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late BlobExtensionBackfill backfill;

  setUp(() async {
    db = newTestDatabase();
    root = await newTempRoot();
    backfill = BlobExtensionBackfill(database: db, root: root);
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  Future<String> insertRow({
    required List<int> bytes,
    required String mime,
    required MediaKind kind,
    required String relPath,
  }) async {
    final id = sha256Hex(bytes);
    await db.into(db.mediaBlobs).insert(
          MediaBlobsCompanion.insert(
            id: id,
            relPath: relPath,
            mime: mime,
            kind: kind.id,
            bytes: bytes.length,
            createdAt: 0,
          ),
        );
    return id;
  }

  Future<void> writeAt(String relPath, List<int> bytes) async {
    final file = File(p.join(root.path, relPath));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<String> storedRelPath(String id) async {
    final row = await (db.select(db.mediaBlobs)..where((t) => t.id.equals(id)))
        .getSingle();
    return row.relPath;
  }

  test('renames legacy blobs, rewrites rows, keeps bytes, and re-runs cleanly',
      () async {
    final seeds = <String, ({List<int> bytes, String mime, MediaKind kind})>{
      'video': (bytes: [1, 1, 1], mime: 'video/quicktime', kind: MediaKind.video),
      'audio': (bytes: [2, 2, 2], mime: 'audio/mp4', kind: MediaKind.audio),
      'photo': (bytes: [3, 3, 3], mime: 'image/png', kind: MediaKind.photo),
    };
    final ids = <String, String>{};
    for (final entry in seeds.entries) {
      final seed = entry.value;
      final id = sha256Hex(seed.bytes);
      await writeAt(relPathForId(id), seed.bytes);
      ids[entry.key] = await insertRow(
        bytes: seed.bytes,
        mime: seed.mime,
        kind: seed.kind,
        relPath: relPathForId(id),
      );
    }

    final result = await backfill.run();

    expect(result.scanned, 3);
    expect(result.renamed, 3);
    expect(result.adopted, 0);
    expect(result.missing, 0);
    expect(result.failed, 0);

    for (final entry in seeds.entries) {
      final seed = entry.value;
      final id = ids[entry.key]!;
      final relPath = await storedRelPath(id);

      expect(
        relPath,
        relPathForBlob(id: id, mime: seed.mime, kind: seed.kind),
      );
      expect(p.extension(relPath), isNotEmpty);
      expect(File(p.join(root.path, relPathForId(id))).existsSync(), isFalse);

      final migrated = File(p.join(root.path, relPath));
      expect(migrated.existsSync(), isTrue);
      expect(sha256Hex(await migrated.readAsBytes()), id);
    }

    final second = await backfill.run();
    expect(second.scanned, 0);
    expect(second.renamed, 0);
    expect(second.adopted, 0);
    expect(second.missing, 0);
    expect(second.failed, 0);

    for (final entry in seeds.entries) {
      final seed = entry.value;
      final id = ids[entry.key]!;
      expect(
        await storedRelPath(id),
        relPathForBlob(id: id, mime: seed.mime, kind: seed.kind),
      );
    }
  });

  test('adopts a blob whose file was renamed before the row was rewritten',
      () async {
    final bytes = [4, 4, 4];
    final id = sha256Hex(bytes);
    final target =
        relPathForBlob(id: id, mime: 'audio/mp4', kind: MediaKind.audio);
    await writeAt(target, bytes);
    await insertRow(
      bytes: bytes,
      mime: 'audio/mp4',
      kind: MediaKind.audio,
      relPath: relPathForId(id),
    );

    final result = await backfill.run();

    expect(result.adopted, 1);
    expect(result.renamed, 0);
    expect(result.failed, 0);
    expect(await storedRelPath(id), target);
    expect(sha256Hex(await File(p.join(root.path, target)).readAsBytes()), id);
  });

  test('ignores a row that was already rewritten', () async {
    final bytes = [5, 5, 5];
    final id = sha256Hex(bytes);
    final target =
        relPathForBlob(id: id, mime: 'image/jpeg', kind: MediaKind.photo);
    await writeAt(target, bytes);
    await insertRow(
      bytes: bytes,
      mime: 'image/jpeg',
      kind: MediaKind.photo,
      relPath: target,
    );

    final result = await backfill.run();

    expect(result.scanned, 0);
    expect(result.renamed, 0);
    expect(result.adopted, 0);
    expect(await storedRelPath(id), target);
    expect(File(p.join(root.path, target)).existsSync(), isTrue);
  });

  test('leaves a row untouched when its file is missing', () async {
    final bytes = [6, 6, 6];
    final id = sha256Hex(bytes);
    final legacy = relPathForId(id);
    await insertRow(
      bytes: bytes,
      mime: 'video/quicktime',
      kind: MediaKind.video,
      relPath: legacy,
    );

    final result = await backfill.run();

    expect(result.missing, 1);
    expect(result.renamed, 0);
    expect(result.failed, 0);
    expect(await storedRelPath(id), legacy);
    expect(
      File(p.join(
        root.path,
        relPathForBlob(
          id: id,
          mime: 'video/quicktime',
          kind: MediaKind.video,
        ),
      )).existsSync(),
      isFalse,
    );
  });

  test('reclaims the legacy copy when both paths hold the same blob', () async {
    final bytes = [7, 7, 7, 7];
    final id = sha256Hex(bytes);
    final legacy = relPathForId(id);
    final target =
        relPathForBlob(id: id, mime: 'video/quicktime', kind: MediaKind.video);
    await writeAt(legacy, bytes);
    await writeAt(target, bytes);
    await insertRow(
      bytes: bytes,
      mime: 'video/quicktime',
      kind: MediaKind.video,
      relPath: legacy,
    );

    final result = await backfill.run();

    expect(result.adopted, 1);
    expect(result.failed, 0);
    expect(await storedRelPath(id), target);
    expect(File(p.join(root.path, legacy)).existsSync(), isFalse);
    final kept = File(p.join(root.path, target));
    expect(sha256Hex(await kept.readAsBytes()), id);
  });

  test('keeps both copies when the legacy size contradicts the row', () async {
    final bytes = [8, 8, 8, 8];
    final id = sha256Hex(bytes);
    final legacy = relPathForId(id);
    final target =
        relPathForBlob(id: id, mime: 'audio/mp4', kind: MediaKind.audio);
    await writeAt(legacy, <int>[8]);
    await writeAt(target, bytes);
    await insertRow(
      bytes: bytes,
      mime: 'audio/mp4',
      kind: MediaKind.audio,
      relPath: legacy,
    );

    final result = await backfill.run();

    expect(result.adopted, 1);
    expect(await storedRelPath(id), target);
    expect(File(p.join(root.path, legacy)).existsSync(), isTrue);
    expect(File(p.join(root.path, target)).existsSync(), isTrue);
  });

  test('fails a row whose kind cannot be parsed and leaves the file alone',
      () async {
    final bytes = [9, 9, 9];
    final id = sha256Hex(bytes);
    final legacy = relPathForId(id);
    await writeAt(legacy, bytes);
    await db.into(db.mediaBlobs).insert(
          MediaBlobsCompanion.insert(
            id: id,
            relPath: legacy,
            mime: 'video/quicktime',
            kind: 'hologram',
            bytes: bytes.length,
            createdAt: 0,
          ),
        );

    final result = await backfill.run();

    expect(result.failed, 1);
    expect(result.renamed, 0);
    expect(result.adopted, 0);
    expect(await storedRelPath(id), legacy);
    final untouched = File(p.join(root.path, legacy));
    expect(untouched.existsSync(), isTrue);
    expect(sha256Hex(await untouched.readAsBytes()), id);
  });

  test('refuses a row whose rel_path escapes the media root', () async {
    final outside = await Directory.systemTemp.createTemp('fn_outside');
    addTearDown(() => outside.delete(recursive: true));
    final bytes = [10, 10, 10];
    final id = sha256Hex(bytes);
    final intruder = File(p.join(outside.path, 'secret'));
    await intruder.writeAsBytes(bytes, flush: true);
    expect(
      intruder.path,
      isNot(contains('.')),
      reason: 'the containment guard must be reached past the pending filter',
    );

    await insertRow(
      bytes: bytes,
      mime: 'video/quicktime',
      kind: MediaKind.video,
      relPath: intruder.path,
    );

    final result = await backfill.run();

    expect(result.failed, 1);
    expect(result.renamed, 0);
    expect(result.adopted, 0);
    expect(await storedRelPath(id), intruder.path);
    expect(intruder.existsSync(), isTrue);
    expect(
      File(p.join(
        root.path,
        relPathForBlob(
          id: id,
          mime: 'video/quicktime',
          kind: MediaKind.video,
        ),
      )).existsSync(),
      isFalse,
    );
  });

  test('converges when two runs race over the same rows', () async {
    final seeds = <List<int>>[
      [20, 20, 20],
      [21, 21, 21],
      [22, 22, 22],
    ];
    final ids = <String>[];
    for (final bytes in seeds) {
      final id = sha256Hex(bytes);
      await writeAt(relPathForId(id), bytes);
      ids.add(await insertRow(
        bytes: bytes,
        mime: 'audio/mp4',
        kind: MediaKind.audio,
        relPath: relPathForId(id),
      ));
    }

    await Future.wait<BlobExtensionBackfillResult>(
      <Future<BlobExtensionBackfillResult>>[backfill.run(), backfill.run()],
    );

    for (final id in ids) {
      final target =
          relPathForBlob(id: id, mime: 'audio/mp4', kind: MediaKind.audio);
      expect(await storedRelPath(id), target);
      expect(File(p.join(root.path, relPathForId(id))).existsSync(), isFalse);
      final migrated = File(p.join(root.path, target));
      expect(migrated.existsSync(), isTrue);
      expect(sha256Hex(await migrated.readAsBytes()), id);
    }

    final settled = await backfill.run();
    expect(settled.scanned, 0);
  });
}
