import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/engine/pull_cycle.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:flutter_test/flutter_test.dart';

import '../../../support/sync_overrides.dart';

List<int> _bytes(int length, int seed) =>
    List<int>.generate(length, (int index) => (index * 13 + seed) % 251);

Future<void> _cache(
  SyncTestDevice device,
  String blobId, {
  required bool uploaded,
  int? downloadedAt,
}) => device.database
    .into(device.database.syncMediaCache)
    .insertOnConflictUpdate(
      SyncMediaCacheCompanion.insert(
        blobId: blobId,
        uploaded: Value(uploaded),
        downloadedAt: Value(downloadedAt),
      ),
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SyncTestDevice phone;
  late SyncTestMedia media;

  setUp(() async {
    phone = SyncTestDevice('Phone');
    media = await SyncTestMedia.create(phone);
  });

  tearDown(() => phone.dispose());

  Future<File> fileOf(domain.MediaBlob blob) async =>
      File(media.store.absolutePath(blob));

  test('trimming never deletes a file that is not uploaded', () async {
    final domain.MediaBlob downloaded = await media.store.putBytes(
      bytes: _bytes(800, 1),
      mime: 'video/mp4',
      kind: domain.MediaKind.video,
    );
    final domain.MediaBlob recorded = await media.store.putBytes(
      bytes: _bytes(800, 2),
      mime: 'video/mp4',
      kind: domain.MediaKind.video,
    );
    await _cache(
      phone,
      downloaded.id,
      uploaded: false,
      downloadedAt: phone.wallMillis(),
    );
    await phone.clock.advance(const Duration(days: 400));

    expect(await media.cache.trim(keepAll: false), 0);

    expect(await (await fileOf(downloaded)).exists(), isTrue);
    expect(await (await fileOf(recorded)).exists(), isTrue);
  });

  test('a downloaded file unopened for thirty days is trimmed', () async {
    final domain.MediaBlob unopened = await media.store.putBytes(
      bytes: _bytes(700, 3),
      mime: 'video/mp4',
      kind: domain.MediaKind.video,
    );
    final domain.MediaBlob opened = await media.store.putBytes(
      bytes: _bytes(700, 4),
      mime: 'audio/mp4',
      kind: domain.MediaKind.audio,
    );
    final domain.MediaBlob photo = await media.store.putBytes(
      bytes: _bytes(700, 5),
      mime: 'image/jpeg',
      kind: domain.MediaKind.photo,
    );
    final domain.MediaBlob poster = await media.store.putBytes(
      bytes: _bytes(300, 6),
      mime: 'image/jpeg',
      kind: domain.MediaKind.photo,
    );
    final domain.MediaBlob recorded = await media.store.putBytes(
      bytes: _bytes(700, 7),
      mime: 'video/mp4',
      kind: domain.MediaKind.video,
    );
    await (phone.database.update(phone.database.mediaBlobs)
          ..where((t) => t.id.equals(photo.id)))
        .write(MediaBlobsCompanion(posterId: Value(poster.id)));
    final int start = phone.wallMillis();
    for (final domain.MediaBlob blob in <domain.MediaBlob>[
      unopened,
      opened,
      poster,
    ]) {
      await _cache(phone, blob.id, uploaded: true, downloadedAt: start);
    }
    await _cache(phone, recorded.id, uploaded: true);

    await phone.clock.advance(const Duration(days: 20));
    await media.cache.recordOpen(opened.id);
    await phone.clock.advance(const Duration(days: 9));
    expect(await media.cache.trim(keepAll: false), 0);

    await phone.clock.advance(const Duration(days: 2));
    expect(await media.cache.trim(keepAll: true), 0);
    expect(await (await fileOf(unopened)).exists(), isTrue);
    expect(await media.cache.trim(keepAll: false), 1);
    expect(await (await fileOf(unopened)).exists(), isFalse);
    expect(await (await fileOf(opened)).exists(), isTrue);

    await phone.clock.advance(const Duration(days: 20));
    expect(await media.cache.trim(keepAll: false), 1);
    expect(await (await fileOf(opened)).exists(), isFalse);
    expect(await (await fileOf(poster)).exists(), isTrue);
    expect(await (await fileOf(recorded)).exists(), isTrue);
    expect(await (await fileOf(photo)).exists(), isTrue);
    expect(
      await phone.database.select(phone.database.mediaBlobs).get(),
      hasLength(5),
    );
  });

  test('reclaiming space with sync on keeps synced rows', () async {
    final domain.MediaBlob reachable = await media.store.putBytes(
      bytes: _bytes(600, 8),
      mime: 'audio/mp4',
      kind: domain.MediaKind.audio,
    );
    final domain.MediaBlob held = await media.store.putBytes(
      bytes: _bytes(600, 9),
      mime: 'audio/mp4',
      kind: domain.MediaKind.audio,
    );
    final domain.MediaBlob unsent = await media.store.putBytes(
      bytes: _bytes(600, 10),
      mime: 'audio/mp4',
      kind: domain.MediaKind.audio,
    );
    final domain.Day day = await phone.journal.ensureDayForDate('2026-10-11');
    await phone.journal.createEntry(
      dayId: day.id,
      type: domain.EntryType.voice,
      mediaId: reachable.id,
    );
    final domain.Entry gone = await phone.journal.createEntry(
      dayId: day.id,
      type: domain.EntryType.voice,
      mediaId: held.id,
    );
    await phone.journal.softDeleteEntry(gone.id);
    await _cache(phone, reachable.id, uploaded: true);
    await _cache(phone, held.id, uploaded: true);
    Future<List<Object>> synced() async => <Object>[
      ...await phone.database.select(phone.database.mediaBlobs).get(),
      ...await phone.database.select(phone.database.entries).get(),
      ...await phone.database.select(phone.database.entryPhotos).get(),
      ...await phone.database.select(phone.database.days).get(),
      ...await phone.database.select(phone.database.syncOutbox).get(),
    ];
    final List<Object> before = await synced();

    expect(await media.cache.reclaim(), 0);
    await writeSyncState(phone.database, pullCompleteKey, pullIncompleteValue);
    expect(await media.cache.reclaim(), 0);
    expect(await (await fileOf(held)).exists(), isTrue);

    await writeSyncState(phone.database, pullCompleteKey, pullCompleteValue);
    expect(await media.cache.reclaim(), 1);

    expect(await (await fileOf(held)).exists(), isFalse);
    expect(await (await fileOf(reachable)).exists(), isTrue);
    expect(await (await fileOf(unsent)).exists(), isTrue);
    expect(await synced(), before);
  });
}
