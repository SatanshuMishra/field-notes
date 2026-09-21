import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/domain/models/media_blob.dart';
import 'package:field_notes/domain/models/media_kind.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';

import '../support/entry_cards_harness.dart';

const String _digest =
    '7f3ac91b2d4e5a6b7c8d9e0f1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d';

class _CountingMediaStore implements MediaStore {
  _CountingMediaStore(this._inner);

  final MediaStore _inner;
  int byIdCalls = 0;
  int byPrefixCalls = 0;

  @override
  Future<MediaBlob?> blobById(String id) {
    byIdCalls++;
    return _inner.blobById(id);
  }

  @override
  Future<MediaBlob?> blobByPrefix(String prefix) {
    byPrefixCalls++;
    return _inner.blobByPrefix(prefix);
  }

  @override
  String absolutePath(MediaBlob blob) => _inner.absolutePath(blob);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

    Future<File> writeBlobFile(String relPath) async {
      final File file = File('${root.path}/$relPath');
      await file.create(recursive: true);
      await file.writeAsBytes(<int>[1, 2, 3]);
      return file;
    }

    test('resolves a 12-hex prefix to exactly one blob', () async {
      await writeBlobFile('blobs/7f/rest');
      final FakeMediaStore store = FakeMediaStore(root)
        ..register(
          MediaBlob(
            id: _digest,
            relPath: 'blobs/7f/rest',
            mime: 'image/png',
            kind: MediaKind.photo,
            bytes: 3,
            createdAt: 0,
          ),
        );
      final MediaStoreResolver resolver = MediaStoreResolver(store);

      final ResolvedMedia result = await resolver.resolve('7f3ac91b2d4e');

      expect(result.isAvailable, isTrue);
      expect(result.blob!.id, _digest);
    });

    test('an ambiguous prefix resolves to nothing', () async {
      await writeBlobFile('blobs/7f/rest');
      final FakeMediaStore store = FakeMediaStore(root)
        ..register(blobOf(id: '7f3ac91b2d4e0000', relPath: 'blobs/7f/rest'))
        ..register(blobOf(id: '7f3ac91b2d4e1111', relPath: 'blobs/7f/rest'));
      final MediaStoreResolver resolver = MediaStoreResolver(store);

      expect((await resolver.resolve('7f3ac91b2d4e')).isAvailable, isFalse);
    });

    test('a second resolve issues no further store call and is synchronous',
        () async {
      await writeBlobFile('blobs/aa/rest');
      final _CountingMediaStore store = _CountingMediaStore(
        FakeMediaStore(root)..register(blobOf(id: 'a', relPath: 'blobs/aa/rest')),
      );
      final MediaStoreResolver resolver = MediaStoreResolver(store);

      expect(resolver.resolved('a'), isNull);

      final ResolvedMedia first = await resolver.resolve('a');
      final ResolvedMedia second = await resolver.resolve('a');

      expect(store.byIdCalls, 1);
      expect(identical(first, second), isTrue);
      expect(resolver.resolved('a')!.isAvailable, isTrue);
    });

    test('concurrent resolves for one id share a single store call', () async {
      await writeBlobFile('blobs/aa/rest');
      final _CountingMediaStore store = _CountingMediaStore(
        FakeMediaStore(root)..register(blobOf(id: 'a', relPath: 'blobs/aa/rest')),
      );
      final MediaStoreResolver resolver = MediaStoreResolver(store);

      await Future.wait<ResolvedMedia>(<Future<ResolvedMedia>>[
        resolver.resolve('a'),
        resolver.resolve('a'),
        resolver.resolve('a'),
      ]);

      expect(store.byIdCalls, 1);
    });

    test('a full digest goes to the exact-id lookup, not the prefix scan',
        () async {
      await writeBlobFile('blobs/7f/rest');
      final _CountingMediaStore store = _CountingMediaStore(
        FakeMediaStore(root)..register(blobOf(id: _digest, relPath: 'blobs/7f/rest')),
      );
      final MediaStoreResolver resolver = MediaStoreResolver(store);

      await resolver.resolve(_digest);

      expect(store.byIdCalls, 1);
      expect(store.byPrefixCalls, 0);
    });

    test('a null id is resolved synchronously as missing', () {
      final MediaStoreResolver resolver =
          MediaStoreResolver(FakeMediaStore(root));

      expect(resolver.resolved(null)!.isAvailable, isFalse);
      expect(resolver.resolved('')!.isAvailable, isFalse);
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
