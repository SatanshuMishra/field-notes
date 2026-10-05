import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/media/content_hash.dart';
import 'package:field_notes/data/sync/hlc.dart';
import 'package:field_notes/data/sync/merge/record_state.dart';
import 'package:field_notes/data/sync/merge/state_applier.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/sync_overrides.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a file whose metadata arrived first is stored', () async {
    final SyncTestDevice mac = SyncTestDevice('Mac');
    addTearDown(mac.dispose);
    final SyncTestMedia media = await SyncTestMedia.create(mac);
    final List<int> bytes = List<int>.generate(900, (int i) => (i * 3) % 251);
    final String id = sha256Hex(bytes);
    final String clock = Hlc(
      millis: mac.wallMillis() - 1000,
      counter: 0,
      nodeId: 'phone',
    ).encode();
    final RecordState arrived = RecordState(
      table: SyncedTables.mediaBlobs,
      rowId: id,
      fields: <String, Object?>{
        'id': id,
        'mime': 'image/jpeg',
        'kind': domain.MediaKind.photo.id,
        'bytes': bytes.length,
        'width': 30,
        'height': 20,
        'durationMs': null,
        'createdAt': 0,
        'posterId': null,
      },
      clocks: <String, String>{
        for (final String field in SyncedTables.mediaBlobFields) field: clock,
      },
    );
    await StateApplier(
      database: mac.database,
      recorder: mac.recorder,
      localDeviceName: mac.name,
    ).apply(arrived);
    final domain.MediaBlob row = (await media.store.blobById(id))!;
    final File target = File(media.store.absolutePath(row));
    expect(await target.exists(), isFalse);
    final MediaStoreResolver resolver = MediaStoreResolver(media.store);
    expect((await resolver.resolve(id)).isAvailable, isFalse);

    final domain.MediaBlob stored = await media.store.putBytes(
      bytes: bytes,
      mime: 'image/jpeg',
      kind: domain.MediaKind.photo,
    );

    expect(stored, row);
    expect(await target.exists(), isTrue);
    expect(await target.readAsBytes(), bytes);
    final ResolvedMedia resolved = await resolver.resolve(id);
    expect(resolved.isAvailable, isTrue);
    expect(resolved.file!.path, target.path);
    expect(
      await mac.database.select(mac.database.mediaBlobs).get(),
      hasLength(1),
    );
  });
}
