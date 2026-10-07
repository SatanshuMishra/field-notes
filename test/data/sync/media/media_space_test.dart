import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/crypto/file_cipher.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/media/device_storage.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/media/media_exceptions.dart';
import 'package:field_notes/data/sync/media/unused_blobs.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/data/sync/media/download_service.dart';
import 'package:field_notes/data/sync/media/upload_queue.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:field_notes/domain/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../../support/sync_overrides.dart';
import '../../../sync/support/relay_fixture.dart';

final class _FullStore extends FilesystemMediaStore {
  _FullStore(SyncTestDevice device, Directory root)
    : super(
        database: device.database,
        recorder: device.recorder,
        root: root,
        clock: device.wallMillis,
      );

  int stores = 0;

  @override
  Future<void> restoreFile(domain.MediaBlob blob, File source) async {
    stores += 1;
    throw MediaWriteException(
      'failed to write media blob ${blob.id}',
      const FileSystemException(
        'No space left on device',
        '',
        OSError('No space left on device', noSpaceLeftErrorCode),
      ),
    );
  }
}

final class _Storage implements DeviceStorage {
  _Storage(this.free);

  int free;

  @override
  Future<int?> freeBytes(Directory near) async => free;
}

const String _date = '2026-10-06';

List<int> _bytes(int length, int seed) =>
    List<int>.generate(length, (int index) => (index * 13 + seed) % 251);

Future<domain.MediaBlob> _voiceNote(
  SyncTestDevice device,
  SyncTestMedia media,
  int length,
  int seed,
) async {
  final domain.MediaBlob blob = await media.store.putBytes(
    bytes: _bytes(length, seed),
    mime: 'audio/mp4',
    kind: domain.MediaKind.audio,
    durationMs: 1000,
  );
  final domain.Day day = await device.journal.ensureDayForDate(_date);
  await device.journal.createEntry(
    dayId: day.id,
    type: domain.EntryType.voice,
    mediaId: blob.id,
    durationMs: 1000,
  );
  return blob;
}

Future<List<String>> _queued(SyncTestDevice device) async => <String>[
  for (final row
      in await device.database.select(device.database.syncUploads).get())
    row.blobId,
];

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

  Future<SyncTestDevice> enrolled(String name) async {
    final SyncTestDevice created = SyncTestDevice(name);
    devices.add(created);
    return enrolDevice(relay, created);
  }

  test(
    'media too large for the free space waits and leaves nothing behind',
    () async {
      final SyncTestDevice phone = await enrolled('Phone');
      final _Storage storage = _Storage(storageReserveBytes + 40000);
      final SyncTestMedia media = await SyncTestMedia.create(
        phone,
        storage: storage,
      );
      final domain.MediaBlob video = await _voiceNote(phone, media, 60000, 1);
      final domain.MediaBlob voice = await _voiceNote(phone, media, 2000, 2);

      expect(await media.uploads.prepareAll(), 1);

      expect(await _queued(phone), <String>[voice.id]);
      expect(media.uploads.waitingForSpace, isTrue);
      expect(
        await Directory(p.join(uploadWorkRoot(media.root).path, video.id))
            .exists(),
        isFalse,
      );

      storage.free = storageReserveBytes + 200000;
      expect(await media.uploads.prepareAll(), 1);

      expect((await _queued(phone)).toSet(), <String>{voice.id, video.id});
      expect(media.uploads.waitingForSpace, isFalse);
    },
  );

  test(
    'parts written while encrypting rebuild the encrypted file exactly',
    () async {
      final SyncTestDevice phone = await enrolled('Phone');
      final SyncTestMedia media = await SyncTestMedia.create(
        phone,
        partBytes: 1024 * 1024,
      );
      final int length = fileChunkBytes + 1500000;
      final domain.MediaBlob video = await _voiceNote(phone, media, length, 3);

      final PendingUpload upload = (await media.uploads.prepare(video.id))!;

      expect(upload.totalBytes, encryptedFileLength(length));
      expect(upload.partCount, (upload.totalBytes / (1024 * 1024)).ceil());
      final BytesBuilder joined = BytesBuilder(copy: false);
      for (int index = 0; index < upload.partCount; index++) {
        final Uint8List part = await upload.partFile(index).readAsBytes();
        expect(part.length, upload.sizeOfPart(index));
        joined.add(part);
      }
      final Directory scratch = await Directory.systemTemp.createTemp(
        'fn_parts',
      );
      addTearDown(() => scratch.delete(recursive: true));
      final File cipher = File(p.join(scratch.path, 'joined'))
        ..writeAsBytesSync(joined.takeBytes());
      final File plain = File(p.join(scratch.path, 'plain'));
      await FileCipher.decryptFile(cipher, plain, await phone.journalKeys());
      expect(await plain.readAsBytes(), _bytes(length, 3));
      expect(
        uploadWorkRoot(media.root)
            .listSync()
            .map((FileSystemEntity entry) => p.basename(entry.path)),
        <String>[video.id],
      );
    },
  );

  test('a preparation that fails waits before it is tried again', () async {
    final SyncTestDevice phone = await enrolled('Phone');
    final SyncTestMedia media = await SyncTestMedia.create(phone);
    final domain.MediaBlob voice = await _voiceNote(phone, media, 3000, 4);
    final File blocker = File(uploadWorkRoot(media.root).path);
    await blocker.parent.create(recursive: true);
    await blocker.writeAsString('in the way');

    expect(await media.uploads.prepareAll(), 0);
    await blocker.delete();

    expect(await media.uploads.prepareAll(), 0);
    await phone.clock.advance(firstPrepareRetry);
    expect(await media.uploads.prepareAll(), 1);
    expect(await _queued(phone), <String>[voice.id]);
  });

  test('a device low on space says so while its notes keep syncing', () async {
    final SyncTestDevice phone = await enrolled('Phone');
    final _Storage storage = _Storage(storageReserveBytes);
    final SyncTestMedia media = await SyncTestMedia.create(
      phone,
      storage: storage,
    );
    final SyncEngine engine = phone.engine(media: media.source());
    await engine.start();
    await _voiceNote(phone, media, 5000, 5);
    await phone.journal.saveNote(
      date: _date,
      source: 'written while the phone is full',
      photoMediaIds: const <String>[],
    );

    await engine.syncNow();

    await eventually(
      () async =>
          await engine.status() ==
          const AttentionStatus(AttentionReason.deviceFull),
    );
    expect(
      await phone.database.select(phone.database.syncOutbox).get(),
      isEmpty,
    );

    storage.free = storageReserveBytes + 1000000;
    await engine.syncNow();

    await eventually(() async => await engine.status() is SyncedStatus);
    expect(await _queued(phone), isEmpty);
  });

  test(
    'missing media is looked up in one request, not fetched one by one',
    () async {
      final SyncTestDevice mac = await enrolled('Mac');
      final SyncTestMedia media = await SyncTestMedia.create(
        mac,
        settings: AppSettings.defaults.copyWith(keepAllMediaOnDevice: true),
      );
      for (int seed = 0; seed < 5; seed++) {
        final domain.MediaBlob blob = await _voiceNote(mac, media, 900, seed);
        await File(media.store.absolutePath(blob)).delete();
      }
      final SyncEngine engine = mac.engine(media: media.source());
      await engine.start();
      await engine.syncNow();
      mac.http.sent.clear();

      for (int cycle = 0; cycle < 3; cycle++) {
        await engine.syncNow();
      }

      expect(
        mac.http.sent.where(
          (SentRequest request) =>
              request.method == 'GET' && request.path.startsWith('/v1/blobs/'),
        ),
        isEmpty,
      );
      expect(mac.http.countOf('POST', '/v1/blobs/referenced'), 3);
    },
  );

  test('a download that fails is retried only after a wait', () async {
    final SyncTestDevice mac = await enrolled('Mac');
    final SyncTestMedia media = await SyncTestMedia.create(
      mac,
      settings: AppSettings.defaults.copyWith(keepAllMediaOnDevice: true),
    );
    final domain.MediaBlob blob = await _voiceNote(mac, media, 1200, 9);
    final SyncEngine engine = mac.engine(media: media.source());
    await engine.start();
    await engine.syncNow();
    await eventually(() async => (await _queued(mac)).isEmpty);
    await File(media.store.absolutePath(blob)).delete();
    bool fetches(SentRequest request) =>
        request.method == 'GET' &&
        request.path.startsWith('/v1/blobs/') &&
        !request.path.endsWith('/referenced');
    mac.http.intercept = (http.BaseRequest request) async {
      if (request.method == 'GET' &&
          request.url.path.startsWith('/v1/blobs/')) {
        return http.StreamedResponse(
          Stream<List<int>>.value(_bytes(300, 1)),
          200,
          headers: <String, String>{'content-type': 'application/octet-stream'},
        );
      }
      return null;
    };
    mac.http.sent.clear();

    await engine.syncNow();
    await engine.syncNow();
    await engine.syncNow();
    expect(mac.http.sent.where(fetches), hasLength(1));

    await mac.clock.advance(firstDownloadRetry);
    await engine.syncNow();
    expect(mac.http.sent.where(fetches), hasLength(2));
  });

  test('a download that runs out of space while being stored waits instead of '
      'failing the cycle', () async {
    final SyncTestDevice mac = await enrolled('Mac');
    final SyncTestMedia media = await SyncTestMedia.create(
      mac,
      settings: AppSettings.defaults.copyWith(keepAllMediaOnDevice: true),
    );
    final domain.MediaBlob blob = await _voiceNote(mac, media, 1500, 11);
    final SyncEngine uploader = mac.engine(media: media.source());
    await uploader.start();
    await uploader.syncNow();
    await eventually(() async => (await _queued(mac)).isEmpty);
    await mac.disposeEngines();
    await File(media.store.absolutePath(blob)).delete();
    final _FullStore full = _FullStore(mac, media.root);
    final DownloadService downloads = DownloadService(
      database: mac.database,
      store: full,
      keyStore: mac.keyStore,
      workRoot: downloadWorkRoot(media.root),
      reachable: media.collector.reachableMediaIds,
      clock: mac.wallMillis,
    );
    final SyncEngine engine = mac.engine(
      media: () async => SyncMedia(
        uploads: media.uploads,
        downloads: downloads,
        posters: media.posters,
        cache: media.cache,
        unusedBlobs: media.unusedBlobs,
        settings: () async => media.settings,
      ),
    );
    await engine.start();

    await engine.syncNow();
    await engine.syncNow();

    expect(full.stores, 1);
    expect(downloads.waitingForSpace, isTrue);
    expect(engine.consecutiveFailures, 0);
    expect(
      await engine.status(),
      const AttentionStatus(AttentionReason.deviceFull),
    );
    expect(downloadWorkRoot(media.root).listSync(), isEmpty);

    await mac.clock.advance(firstDownloadRetry);
    await engine.syncNow();
    expect(full.stores, 2);
  });

  test(
    'media the relay holds is recorded even when its download fails',
    () async {
      final SyncTestDevice phone = await enrolled('Phone');
      final SyncTestDevice mac = SyncTestDevice('Mac');
      devices.add(mac);
      await pairDevice(relay, phone, mac);
      final SyncTestMedia phoneMedia = await SyncTestMedia.create(phone);
      final SyncTestMedia macMedia = await SyncTestMedia.create(
        mac,
        settings: AppSettings.defaults.copyWith(keepAllMediaOnDevice: true),
      );
      final domain.MediaBlob blob = await _voiceNote(
        phone,
        phoneMedia,
        800,
        12,
      );
      final SyncEngine phoneEngine = phone.engine(media: phoneMedia.source());
      await phoneEngine.start();
      await phoneEngine.syncNow();
      await eventually(() async => (await _queued(phone)).isEmpty);
      mac.http.intercept = (http.BaseRequest request) async =>
          request.method == 'GET' &&
              request.url.path.startsWith('/v1/blobs/') &&
              !request.url.path.endsWith('/referenced')
          ? http.StreamedResponse(const Stream<List<int>>.empty(), 503)
          : null;
      final SyncEngine macEngine = mac.engine(media: macMedia.source());
      await macEngine.start();
      await macEngine.syncNow();

      expect(await macMedia.downloads.hasFile(blob.id), isFalse);
      final SyncMediaCacheData? recorded = await (mac.database.select(
        mac.database.syncMediaCache,
      )..where((t) => t.blobId.equals(blob.id))).getSingleOrNull();
      expect(recorded?.uploaded, isTrue);
      expect(recorded?.reportedState, reportedReferenced);
    },
  );

  test(
    'two preparations of one file at once leave one readable upload',
    () async {
      final SyncTestDevice phone = await enrolled('Phone');
      final SyncTestMedia media = await SyncTestMedia.create(
        phone,
        partBytes: 1024 * 1024,
      );
      final domain.MediaBlob video = await _voiceNote(
        phone,
        media,
        9000000,
        13,
      );

      await Future.wait(<Future<Object?>>[
        media.uploads.prepareAll(),
        media.uploads.requeue(<String>[video.id]),
        media.uploads.prepare(video.id),
      ]);

      final List<PendingUpload> pending = await media.uploads.pendingUploads();
      expect(pending, hasLength(1));
      final BytesBuilder joined = BytesBuilder(copy: false);
      for (int index = 0; index < pending.single.partCount; index++) {
        joined.add(await pending.single.partFile(index).readAsBytes());
      }
      final Directory scratch = await Directory.systemTemp.createTemp(
        'fn_twice',
      );
      addTearDown(() => scratch.delete(recursive: true));
      final File cipher = File(p.join(scratch.path, 'joined'))
        ..writeAsBytesSync(joined.takeBytes());
      final File plain = File(p.join(scratch.path, 'plain'));
      await FileCipher.decryptFile(cipher, plain, await phone.journalKeys());
      expect(await plain.readAsBytes(), _bytes(9000000, 13));
    },
  );
}
