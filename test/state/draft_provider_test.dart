import 'dart:io';

import 'package:field_notes/data/drafts/draft_paths.dart';
import 'package:field_notes/domain/services/draft_store.dart';
import 'package:field_notes/state/draft_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'state_test_support.dart';

void main() {
  group('draftStoreProvider', () {
    test('yields a store writing under the overridden draft root', () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final root = await Directory.systemTemp.createTemp('fn_state_drafts');
      addTearDown(() => root.delete(recursive: true));

      final container = newTestContainer(
        db,
        overrides: [draftRootProvider.overrideWith((ref) async => root)],
      );

      final store = await container.read(draftStoreProvider.future);
      expect(store, isA<DraftStore>());

      const key = '01arz3ndektsv4rrffq69g5fav';
      await store.write(key, 'draft body');
      expect(File(p.join(root.path, draftFileName(key))).existsSync(), isTrue);
      expect(await store.read(key), 'draft body');
    });

    test('draftRootProvider resolves under the configured subdirectory',
        () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final root = await Directory.systemTemp.createTemp('fn_state_drafts');
      addTearDown(() => root.delete(recursive: true));

      final container = newTestContainer(
        db,
        overrides: [draftRootProvider.overrideWith((ref) async => root)],
      );

      expect(await container.read(draftRootProvider.future), root);
      expect(draftsSubdir, 'drafts');
    });
  });
}
