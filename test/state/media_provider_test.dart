import 'dart:io';

import 'package:field_notes/data/media/blob_paths.dart';
import 'package:field_notes/data/media/content_hash.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:field_notes/state/media_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'state_test_support.dart';

void main() {
  group('mediaStoreProvider', () {
    test('yields a store rooted at the overridden media root', () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final root = await Directory.systemTemp.createTemp('fn_state_media');
      addTearDown(() => root.delete(recursive: true));

      final container = newTestContainer(
        db,
        overrides: [mediaRootProvider.overrideWith((ref) async => root)],
      );

      final store = await container.read(mediaStoreProvider.future);
      expect(store, isA<MediaStore>());

      final blob = await store.putBytes(
        bytes: const [1, 2, 3, 4],
        mime: 'image/png',
        kind: MediaKind.photo,
      );
      expect(blob.id.length, 64);
      expect(File(store.absolutePath(blob)).existsSync(), isTrue);
    });

    test('still yields a usable store when the backfill cannot run', () async {
      final db = newTestDatabase();
      final root = await Directory.systemTemp.createTemp('fn_state_media');
      addTearDown(() => root.delete(recursive: true));

      final container = newTestContainer(
        db,
        overrides: [mediaRootProvider.overrideWith((ref) async => root)],
      );
      await db.close();

      final store = await container.read(mediaStoreProvider.future);

      expect(store, isA<MediaStore>());
      final blob = MediaBlob(
        id: sha256Hex(const [1, 2, 3]),
        relPath: relPathForBlob(
          id: sha256Hex(const [1, 2, 3]),
          mime: 'audio/mp4',
          kind: MediaKind.audio,
        ),
        mime: 'audio/mp4',
        kind: MediaKind.audio,
        bytes: 3,
        createdAt: 0,
      );
      expect(store.absolutePath(blob), p.join(root.path, blob.relPath));
    });

    test('mediaRootProvider resolves under the configured subdirectory',
        () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final root = await Directory.systemTemp.createTemp('fn_state_media');
      addTearDown(() => root.delete(recursive: true));

      final container = newTestContainer(
        db,
        overrides: [mediaRootProvider.overrideWith((ref) async => root)],
      );

      expect(await container.read(mediaRootProvider.future), root);
      expect(mediaSubdir, 'media');
    });
  });
}
