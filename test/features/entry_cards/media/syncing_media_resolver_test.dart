import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/media/content_hash.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/media/network_policy.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/media/syncing_media_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/sync_overrides.dart';
import '../../../sync/support/relay_fixture.dart';

List<int> _bytes(int length, int seed) =>
    List<int>.generate(length, (int index) => (index * 17 + seed) % 251);

SyncingMediaResolver _resolver(SyncTestMedia media, SyncEngine engine) =>
    SyncingMediaResolver(
      inner: MediaStoreResolver(media.store),
      store: media.store,
      fetch: engine.fetchMedia,
      posterOf: (String blobId) async => (await (media.device.database.select(
        media.device.database.mediaBlobs,
      )..where((t) => t.id.equals(blobId))).getSingleOrNull())?.posterId,
      recordOpen: media.cache.recordOpen,
      progressOf: media.downloads.progress,
    );

Future<void> _setPoster(
  SyncTestDevice device,
  String blobId,
  String posterId,
) async {
  final MediaBlob row = await (device.database.select(
    device.database.mediaBlobs,
  )..where((t) => t.id.equals(blobId))).getSingle();
  final String clocks = await device.recorder.stamp(
    table: SyncedTables.mediaBlobs,
    rowId: blobId,
    fields: const <String>['posterId'],
    currentClocks: row.fieldClocks,
  );
  await (device.database.update(
    device.database.mediaBlobs,
  )..where((t) => t.id.equals(blobId))).write(
    MediaBlobsCompanion(posterId: Value(posterId), fieldClocks: Value(clocks)),
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late RelayFixture relay;
  late SyncTestDevice mac;
  late SyncTestDevice phone;
  late SyncTestMedia macMedia;
  late SyncTestMedia phoneMedia;

  setUp(() async {
    relay = await RelayFixture.start(rateBurst: 1000);
    mac = await enrolDevice(relay, SyncTestDevice('Mac'));
    phone = await pairDevice(relay, mac, SyncTestDevice('Phone'));
    macMedia = await SyncTestMedia.create(mac);
    phoneMedia = await SyncTestMedia.create(phone);
  });

  tearDown(() async {
    await mac.dispose();
    await phone.dispose();
    await relay.dispose();
  });

  test('an opened video downloads decrypts and plays', () async {
    final List<int> footage = _bytes(5000, 1);
    final domain.MediaBlob video = await macMedia.store.putBytes(
      bytes: footage,
      mime: 'video/mp4',
      kind: domain.MediaKind.video,
    );
    final domain.Day day = await mac.journal.ensureDayForDate('2026-10-13');
    await mac.journal.createEntry(
      dayId: day.id,
      type: domain.EntryType.video,
      mediaId: video.id,
      durationMs: 4000,
    );
    final SyncEngine macEngine = mac.engine(media: macMedia.source());
    await macEngine.start();
    await macEngine.syncNow();
    final SyncEngine phoneEngine = phone.engine(media: phoneMedia.source());
    await phoneEngine.start();
    await phoneEngine.syncNow();
    expect(phoneMedia.settings.keepAllMediaOnDevice, isFalse);
    expect(await phoneMedia.downloads.hasFile(video.id), isFalse);

    final ResolvedMedia opened = await _resolver(
      phoneMedia,
      phoneEngine,
    ).resolve(video.id);

    expect(opened.isAvailable, isTrue);
    expect(opened.blob!.kind, domain.MediaKind.video);
    expect(opened.file!.path, endsWith('.mp4'));
    expect(await opened.file!.readAsBytes(), footage);
    expect(sha256Hex(await opened.file!.readAsBytes()), video.id);
    final SyncMediaCacheData cached = await (phone.database.select(
      phone.database.syncMediaCache,
    )..where((t) => t.blobId.equals(video.id))).getSingle();
    expect(cached.uploaded, isTrue);
    expect(cached.downloadedAt, isNotNull);
  });

  test('a photo that cannot be fetched shows its poster', () async {
    final domain.MediaBlob photo = await macMedia.store.putBytes(
      bytes: _bytes(3000, 2),
      mime: 'image/jpeg',
      kind: domain.MediaKind.photo,
    );
    final List<int> posterBytes = _bytes(600, 3);
    final domain.MediaBlob poster = await macMedia.store.putBytes(
      bytes: posterBytes,
      mime: 'image/jpeg',
      kind: domain.MediaKind.photo,
    );
    await _setPoster(mac, photo.id, poster.id);
    mac.network.kind = NetworkKind.metered;
    final SyncEngine macEngine = mac.engine(media: macMedia.source());
    await macEngine.start();
    await macEngine.syncNow();
    final SyncEngine phoneEngine = phone.engine(media: phoneMedia.source());
    await phoneEngine.start();
    await phoneEngine.syncNow();
    await eventually(() async => phoneMedia.downloads.hasFile(poster.id));
    expect(await phoneMedia.downloads.hasFile(photo.id), isFalse);

    final ResolvedMedia shown = await _resolver(
      phoneMedia,
      phoneEngine,
    ).resolve(photo.id);

    expect(shown.isAvailable, isTrue);
    expect(shown.blob!.id, poster.id);
    expect(await shown.file!.readAsBytes(), posterBytes);
    expect(await phoneMedia.downloads.hasFile(photo.id), isFalse);
  });
}
