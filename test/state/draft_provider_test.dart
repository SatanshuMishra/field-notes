import 'dart:io';

import 'package:field_notes/data/drafts/draft_paths.dart';
import 'package:field_notes/domain/services/draft_store.dart';
import 'package:field_notes/state/draft_provider.dart';
import 'package:field_notes/state/media_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'state_test_support.dart';

class _FakeDocuments extends PathProviderPlatform {
  _FakeDocuments(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

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

    test('the drafts folder the media side wipes is the one drafts are written to',
        () async {
      final documents = await Directory.systemTemp.createTemp('fn_state_docs');
      addTearDown(() => documents.delete(recursive: true));
      final previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakeDocuments(documents.path);
      addTearDown(() => PathProviderPlatform.instance = previous);
      final db = newTestDatabase();
      addTearDown(db.close);

      final container = newTestContainer(db);
      final written = await container.read(draftRootProvider.future);
      final wiped = await container.read(mediaDraftsRootProvider.future);

      expect(wiped.path, written.path);
      expect(p.isWithin(documents.path, written.path), isTrue);
    });
  });
}
