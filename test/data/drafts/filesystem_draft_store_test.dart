import 'dart:io';

import 'package:field_notes/data/drafts/draft_paths.dart';
import 'package:field_notes/data/drafts/filesystem_draft_store.dart';
import 'package:field_notes/domain/services/draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const String _key = '01arz3ndektsv4rrffq69g5fav';

void main() {
  late Directory root;
  late FilesystemDraftStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('fn_drafts');
    store = FilesystemDraftStore(root: root);
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('write then read round-trips the raw source at <root>/<key>.md',
      () async {
    await store.write(_key, '# heading\n\nbody with émoji 🌿');

    expect(await store.read(_key), '# heading\n\nbody with émoji 🌿');
    final File file = File(p.join(root.path, draftFileName(_key)));
    expect(file.existsSync(), isTrue);
    expect(await file.readAsString(), '# heading\n\nbody with émoji 🌿');
  });

  test('a missing draft reads as null', () async {
    expect(await store.read(_key), isNull);
  });

  test('delete removes the file and is a no-op when it is already gone',
      () async {
    await store.write(_key, 'x');
    await store.delete(_key);
    expect(await store.read(_key), isNull);
    await store.delete(_key);
  });

  test('a rewrite replaces the previous draft in place', () async {
    await store.write(_key, 'first');
    await store.write(_key, 'second');

    expect(await store.read(_key), 'second');
    final List<FileSystemEntity> tmp =
        Directory(p.join(root.path, '.tmp')).listSync();
    expect(tmp, isEmpty);
  });

  test('a failed write leaves the previous draft intact', () async {
    await store.write(_key, 'keep me');
    final Directory scratch = Directory(p.join(root.path, '.tmp'));
    await scratch.delete(recursive: true);
    await File(scratch.path).writeAsString('blocks the scratch directory');

    await expectLater(
      store.write(_key, 'lost'),
      throwsA(isA<DraftWriteException>()),
    );

    expect(await store.read(_key), 'keep me');
  });

  test('keys that could escape the drafts directory are rejected', () async {
    await expectLater(
      store.write('../escape', 'x'),
      throwsArgumentError,
    );
    await expectLater(store.read('..'), throwsArgumentError);
    await expectLater(store.delete('a/b'), throwsArgumentError);
    expect(root.listSync(), isEmpty);
  });
}
