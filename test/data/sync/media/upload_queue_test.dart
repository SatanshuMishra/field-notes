import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/crypto/keyed_names.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/engine/pull_cycle.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/media/network_policy.dart';
import 'package:field_notes/data/sync/media/unused_blobs.dart';
import 'package:field_notes/data/sync/media/upload_queue.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:field_notes/domain/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;

import '../../../support/sync_overrides.dart';
import '../../../sync/support/relay_fixture.dart';

final class _Interrupted implements Exception {
  const _Interrupted();
}

final class _RecordingSender implements UploadSender {
  _RecordingSender(this._inner, {this.stopAfter});

  final UploadSender _inner;
  final int? stopAfter;
  final List<int> sent = <int>[];

  @override
  Future<void> sendParts(
    PendingUpload upload,
    List<int> indexes,
    UploadAnswer onAnswer,
  ) async {
    for (final int index in indexes) {
      final int? limit = stopAfter;
      if (limit != null && sent.length >= limit) {
        throw const _Interrupted();
      }
      sent.add(index);
      await _inner.sendParts(upload, <int>[index], onAnswer);
    }
  }
}

final class _UnassembledSender implements UploadSender {
  _UnassembledSender(this._inner);

  final UploadSender _inner;

  @override
  Future<void> sendParts(
    PendingUpload upload,
    List<int> indexes,
    UploadAnswer onAnswer,
  ) => _inner.sendParts(
    upload,
    indexes,
    (UploadStatusResponse answer) => onAnswer(
      UploadStatusResponse(
        receivedParts: answer.receivedParts,
        assembled: false,
      ),
    ),
  );
}

List<int> _bytes(int length, int seed) =>
    List<int>.generate(length, (int index) => (index * 7 + seed) % 251);

Future<bool> _uploaded(SyncTestDevice device, String blobId) async =>
    (await (device.database.select(
      device.database.syncMediaCache,
    )..where((t) => t.blobId.equals(blobId))).getSingleOrNull())?.uploaded ??
    false;

Future<List<SyncUpload>> _uploads(SyncTestDevice device) =>
    device.database.select(device.database.syncUploads).get();

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

List<String> _firstSeen(Iterable<String> names) {
  final List<String> order = <String>[];
  for (final String name in names) {
    if (!order.contains(name)) {
      order.add(name);
    }
  }
  return order;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late RelayFixture relay;
  late List<SyncTestDevice> devices;

  setUp(() async {
    relay = await RelayFixture.start(rateBurst: 1000);
    devices = <SyncTestDevice>[];
  });

  tearDown(() async {
    for (final SyncTestDevice device in devices) {
      await device.dispose();
    }
    await relay.dispose();
  });

  SyncTestDevice device(String name) {
    final SyncTestDevice created = SyncTestDevice(name);
    devices.add(created);
    return created;
  }

  Future<RelayClient> clientOf(SyncTestDevice device) async =>
      device.relayClient(relay.baseUrl, await device.deviceKeys(), (_) {});

  test('an interrupted upload sends only the missing parts', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final SyncTestMedia media = await SyncTestMedia.create(mac);
    final domain.MediaBlob blob = await media.store.putBytes(
      bytes: _bytes(4000, 1),
      mime: 'video/mp4',
      kind: domain.MediaKind.video,
    );
    final PendingUpload prepared = (await media.uploads.prepare(blob.id))!;
    expect(prepared.partCount, 4);
    final RelayClient client = await clientOf(mac);
    final _RecordingSender interrupted = _RecordingSender(
      RelayUploadSender(client),
      stopAfter: 2,
    );

    await expectLater(
      media.uploads.send(client, interrupted),
      throwsA(isA<_Interrupted>()),
    );
    expect(interrupted.sent, <int>[0, 1]);
    expect(await _uploaded(mac, blob.id), isFalse);

    final UploadQueue restarted = UploadQueue(
      database: mac.database,
      store: media.store,
      keys: journalKeysFrom(mac.keyStore),
      workRoot: uploadWorkRoot(media.root),
      partBytes: media.partBytes,
    );
    final _RecordingSender resumed = _RecordingSender(
      RelayUploadSender(client),
    );
    await restarted.send(client, resumed);

    expect(resumed.sent, <int>[2, 3]);
    expect(await _uploaded(mac, blob.id), isTrue);
    expect(await _uploads(mac), isEmpty);
    expect(await Directory(prepared.partsDir).exists(), isFalse);
    expect(await client.blobExists(prepared.blobName), isTrue);
  });

  test('a file queued offline is prepared without the network', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final SyncTestMedia media = await SyncTestMedia.create(mac);
    mac.network.kind = NetworkKind.offline;
    final SyncEngine engine = mac.engine(media: media.source());
    await engine.start();

    final domain.MediaBlob blob = await media.store.putBytes(
      bytes: _bytes(3000, 2),
      mime: 'audio/mp4',
      kind: domain.MediaKind.audio,
    );
    await eventually(() async => (await _uploads(mac)).isNotEmpty);

    final SyncUpload upload = (await _uploads(mac)).single;
    expect(upload.blobId, blob.id);
    expect(isSyncId(upload.uploadId), isTrue);
    expect(upload.partCount, 3);
    expect(upload.ackedParts, '[]');
    int total = 0;
    for (int index = 0; index < upload.partCount; index++) {
      final File part = File(p.join(upload.partsDir!, '$index'));
      expect(await part.exists(), isTrue);
      total += await part.length();
    }
    expect(total, upload.totalBytes);
    expect(
      await File('${uploadWorkRoot(media.root).path}/${blob.id}.enc').exists(),
      isFalse,
    );
    await mac.clock.advance(const Duration(minutes: 10));
    expect(mac.http.sent, isEmpty);
    expect(mac.sockets, 0);
  });

  test('posters move before full files', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final SyncTestDevice phone = await pairDevice(relay, mac, device('Phone'));
    final SyncTestMedia macMedia = await SyncTestMedia.create(mac);
    final SyncTestMedia phoneMedia = await SyncTestMedia.create(
      phone,
      settings: AppSettings.defaults.copyWith(keepAllMediaOnDevice: true),
    );
    final domain.MediaBlob photo = await macMedia.store.putBytes(
      bytes: _bytes(2000, 3),
      mime: 'image/jpeg',
      kind: domain.MediaKind.photo,
    );
    final domain.MediaBlob poster = await macMedia.store.putBytes(
      bytes: _bytes(500, 4),
      mime: 'image/jpeg',
      kind: domain.MediaKind.photo,
    );
    final domain.MediaBlob video = await macMedia.store.putBytes(
      bytes: _bytes(2500, 5),
      mime: 'video/mp4',
      kind: domain.MediaKind.video,
    );
    final domain.MediaBlob thumbnail = await macMedia.store.putBytes(
      bytes: _bytes(400, 6),
      mime: 'image/jpeg',
      kind: domain.MediaKind.photo,
    );
    await _setPoster(mac, photo.id, poster.id);
    final domain.Day day = await mac.journal.ensureDayForDate('2026-10-09');
    await mac.journal.createEntry(
      dayId: day.id,
      type: domain.EntryType.video,
      mediaId: video.id,
      thumbnailMediaId: thumbnail.id,
    );
    final KeyedNames names = KeyedNames(await mac.journalKeys());
    final Map<String, String> idsByName = <String, String>{
      for (final domain.MediaBlob blob in <domain.MediaBlob>[
        photo,
        poster,
        video,
        thumbnail,
      ])
        names.blobName(blob.id): blob.id,
    };
    final Set<String> small = <String>{poster.id, thumbnail.id};
    final Set<String> full = <String>{photo.id, video.id};

    final SyncEngine macEngine = mac.engine(media: macMedia.source());
    await macEngine.start();
    await macEngine.syncNow();
    await eventually(() async => (await _uploads(mac)).isEmpty);

    final List<String> uploadOrder = _firstSeen(<String>[
      for (final SentRequest request in mac.http.sent)
        if (request.method == 'PUT') idsByName[request.path.split('/')[3]]!,
    ]);
    expect(uploadOrder, hasLength(4));
    expect(uploadOrder.take(2).toSet(), small);
    expect(uploadOrder.skip(2).toSet(), full);

    final SyncEngine phoneEngine = phone.engine(media: phoneMedia.source());
    await phoneEngine.start();
    await phoneEngine.syncNow();
    for (final String id in idsByName.values) {
      await eventually(() async => phoneMedia.downloads.hasFile(id));
    }
    final List<String> downloadOrder = _firstSeen(<String>[
      for (final SentRequest request in phone.http.sent)
        if (request.method == 'GET' && request.path.startsWith('/v1/blobs/'))
          idsByName[request.path.split('/')[3]]!,
    ]);
    expect(downloadOrder, hasLength(4));
    expect(downloadOrder.take(2).toSet(), small);
    expect(downloadOrder.skip(2).toSet(), full);
  });

  test('a blob counts as uploaded only once assembled', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final SyncTestMedia media = await SyncTestMedia.create(mac);
    final domain.MediaBlob blob = await media.store.putBytes(
      bytes: _bytes(3000, 7),
      mime: 'video/mp4',
      kind: domain.MediaKind.video,
    );
    final PendingUpload prepared = (await media.uploads.prepare(blob.id))!;
    final RelayClient client = await clientOf(mac);

    await media.uploads.send(
      client,
      _UnassembledSender(RelayUploadSender(client)),
    );

    expect(await _uploaded(mac, blob.id), isFalse);
    expect(await _uploads(mac), hasLength(1));
    expect(await Directory(prepared.partsDir).exists(), isTrue);
    expect(
      await client.blobExists(prepared.blobName),
      isTrue,
      reason: 'every part reached the relay',
    );

    final _RecordingSender again = _RecordingSender(RelayUploadSender(client));
    await media.uploads.send(client, again);

    expect(again.sent, isEmpty);
    expect(await _uploaded(mac, blob.id), isTrue);
    expect(await _uploads(mac), isEmpty);
    expect(await Directory(prepared.partsDir).exists(), isFalse);
  });

  test('a reachable blob missing on the relay is uploaded again', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final SyncTestMedia media = await SyncTestMedia.create(mac);
    final domain.MediaBlob held = await media.store.putBytes(
      bytes: _bytes(1500, 8),
      mime: 'audio/mp4',
      kind: domain.MediaKind.audio,
    );
    final domain.Day day = await mac.journal.ensureDayForDate('2026-10-10');
    await mac.journal.createEntry(
      dayId: day.id,
      type: domain.EntryType.voice,
      mediaId: held.id,
    );
    await markBlobUploaded(mac.database, held.id);
    await writeSyncState(mac.database, pullCompleteKey, pullCompleteValue);
    final RelayClient client = await clientOf(mac);
    final KeyedNames names = KeyedNames(await mac.journalKeys());
    expect(await client.blobExists(names.blobName(held.id)), isFalse);

    final BlobReport report = await media.unusedBlobs.report(client);

    expect(report.lacking, <String>[held.id]);
    expect(await _uploaded(mac, held.id), isFalse);
    final SyncUpload requeued = (await _uploads(mac)).single;
    expect(requeued.blobId, held.id);

    await media.uploads.send(client, RelayUploadSender(client));

    expect(await _uploaded(mac, held.id), isTrue);
    expect(await client.blobExists(names.blobName(held.id)), isTrue);
  });

  test(
    'a file still uploading is not started again when the relay lacks it',
    () async {
      final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
      final SyncTestMedia media = await SyncTestMedia.create(mac);
      final domain.MediaBlob video = await media.store.putBytes(
        bytes: _bytes(1500, 9),
        mime: 'video/mp4',
        kind: domain.MediaKind.video,
      );
      final domain.Day day = await mac.journal.ensureDayForDate('2026-10-11');
      await mac.journal.createEntry(
        dayId: day.id,
        type: domain.EntryType.video,
        mediaId: video.id,
      );
      final PendingUpload inFlight = (await media.uploads.prepare(video.id))!;
      final SyncUpload before = (await _uploads(mac)).single;
      await writeSyncState(mac.database, pullCompleteKey, pullCompleteValue);
      final RelayClient client = await clientOf(mac);

      final BlobReport report = await media.unusedBlobs.report(client);

      expect(report.lacking, <String>[video.id]);
      final SyncUpload after = (await _uploads(mac)).single;
      expect(after.uploadId, inFlight.uploadId);
      expect(after.partsDir, before.partsDir);
      expect(Directory(after.partsDir!).existsSync(), isTrue);
    },
  );
}
