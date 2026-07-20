import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';

import '../support/entry_cards_harness.dart';

void main() {
  group('MediaStoreResolver', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('fn_entry_cards');
    });

    tearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    test('reports missing for a null or empty id', () async {
      final resolver = MediaStoreResolver(FakeMediaStore(root));
      expect((await resolver.resolve(null)).isAvailable, isFalse);
      expect((await resolver.resolve('')).isAvailable, isFalse);
    });

    test('reports missing when the blob row is absent', () async {
      final resolver = MediaStoreResolver(FakeMediaStore(root));
      final ResolvedMedia result = await resolver.resolve('nope');
      expect(result.availability, MediaAvailability.missing);
      expect(result.file, isNull);
    });

    test('reports missing when the blob row exists but the file is gone',
        () async {
      final store = FakeMediaStore(root)
        ..register(blobOf(id: 'a', relPath: 'blobs/aa/rest'));
      final resolver = MediaStoreResolver(store);
      expect((await resolver.resolve('a')).isAvailable, isFalse);
    });

    test('reports available with the on-disk file when present', () async {
      final File file = File('${root.path}/blobs/aa/rest');
      await file.create(recursive: true);
      await file.writeAsBytes(<int>[1, 2, 3]);
      final store = FakeMediaStore(root)
        ..register(blobOf(id: 'a', relPath: 'blobs/aa/rest'));
      final resolver = MediaStoreResolver(store);

      final ResolvedMedia result = await resolver.resolve('a');

      expect(result.availability, MediaAvailability.available);
      expect(result.blob!.id, 'a');
      expect(await result.file!.readAsBytes(), <int>[1, 2, 3]);
    });
  });
}
