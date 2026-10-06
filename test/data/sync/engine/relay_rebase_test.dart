import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/keyed_names.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/pull_cycle.dart';
import 'package:field_notes/data/sync/engine/push_cycle.dart';
import 'package:field_notes/data/sync/engine/relay_rebase.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/media/unused_blobs.dart';
import 'package:field_notes/data/sync/media/upload_queue.dart';
import 'package:field_notes/data/sync/merge/state_applier.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:relay_server/relay_server.dart' show markRestored;
import 'package:sync_protocol/sync_protocol.dart' as protocol show RecordState;
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;

import '../../../support/sync_overrides.dart';
import '../../../sync/support/relay_fixture.dart';

const String _push = '/v1/records/push';
const String _pull = '/v1/records';

Future<domain.Entry> _note(SyncTestDevice device, String text) async {
  final domain.Day day = await device.journal.ensureDayForDate('2026-10-22');
  return device.journal.createEntry(
    dayId: day.id,
    type: domain.EntryType.text,
    textContent: text,
  );
}

Future<List<String?>> _texts(SyncTestDevice device) async => <String?>[
  for (final Entry entry
      in await device.database.select(device.database.entries).get())
    entry.textContent,
];

Future<Set<String>> _localRecordKeys(SyncTestDevice device) async {
  final KeyedNames names = KeyedNames(await device.journalKeys());
  final AppDatabase database = device.database;
  return <String>{
    for (final Day row in await database.select(database.days).get())
      names.recordKey(SyncedTables.days, row.id),
    for (final Entry row in await database.select(database.entries).get())
      names.recordKey(SyncedTables.entries, row.id),
    for (final EntryPhoto row
        in await database.select(database.entryPhotos).get())
      names.recordKey(SyncedTables.entryPhotos, row.id),
    for (final MediaBlob row
        in await database.select(database.mediaBlobs).get())
      names.recordKey(SyncedTables.mediaBlobs, row.id),
    for (final JournalSetting row
        in await database.select(database.journalSettings).get())
      names.recordKey(SyncedTables.journalSettings, row.key),
  };
}

Set<String> _pushedKeys(Iterable<SentRequest> requests) => <String>{
  for (final SentRequest request in requests)
    if (request.method == 'POST' && request.path == _push)
      for (final RecordPush change in PushRequest.fromJson(
        decodeJsonObject(request.body),
      ).changes)
        change.recordKey,
};

Future<SyncEngine> _rebased(SyncTestDevice device, SyncEngine engine) async {
  await engine.start();
  await eventually(
    () async => engine.relayTag.counter == 1 && !engine.isRebasing,
  );
  await engine.syncNow();
  return engine;
}

Future<void> _settled(SyncTestDevice device, {SyncMediaSource? media}) async {
  final SyncEngine engine = device.engine(media: media);
  await engine.start();
  await engine.syncNow();
  await engine.syncNow();
  await device.disposeEngines();
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

  Future<void> restart({Directory? from, bool mark = false}) async {
    for (final SyncTestDevice each in devices) {
      await each.disposeEngines();
    }
    await relay.stop();
    if (from != null) {
      await restoreStoppedRelay(relay, from);
    }
    if (mark) {
      markRestored(relay.config);
    }
    await relay.boot();
    for (final SyncTestDevice each in devices) {
      if (await each.keyStore.readDeviceKeys() != null) {
        await pointAt(each, relay);
      }
    }
  }

  Future<Directory> snapshot() async {
    for (final SyncTestDevice each in devices) {
      await each.disposeEngines();
    }
    await relay.stop();
    final Directory copy = await copyStoppedRelay(relay);
    await relay.boot();
    for (final SyncTestDevice each in devices) {
      await pointAt(each, relay);
    }
    return copy;
  }

  test('a new relay generation makes the device rebase', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final SyncTestMedia media = await SyncTestMedia.create(mac);
    final domain.MediaBlob voice = await media.store.putBytes(
      bytes: List<int>.generate(900, (int index) => index % 251),
      mime: 'audio/mp4',
      kind: domain.MediaKind.audio,
    );
    final domain.Day day = await mac.journal.ensureDayForDate('2026-10-22');
    await mac.journal.createEntry(
      dayId: day.id,
      type: domain.EntryType.voice,
      mediaId: voice.id,
    );
    await _note(mac, 'before the restore');
    await _settled(mac, media: media.source());
    expect(await readPullCursor(mac.database), greaterThan(0));
    final String before = (await mac.syncState(relayGenerationKey))!;

    await restart(mark: true);
    final String generation = relay.app.database.generation();
    expect(generation, isNot(before));
    final int sentBefore = mac.http.sent.length;
    await _rebased(mac, mac.engine(media: media.source()));

    expect(await mac.syncState(relayGenerationKey), generation);
    expect(await mac.syncState(rebaseCounterKey), '1');
    final List<SentRequest> after = mac.http.sent.skip(sentBefore).toList();
    expect(
      after.where(
        (SentRequest request) =>
            request.path == _pull &&
            request.url.queryParameters[SyncRoutes.afterQuery] == '0',
      ),
      isNotEmpty,
    );
    expect(_pushedKeys(after), containsAll(await _localRecordKeys(mac)));
    final String voiceName = KeyedNames(await mac.journalKeys())
        .blobName(voice.id);
    expect(
      after.where(
        (SentRequest request) =>
            request.path == '/v1/blobs/referenced' &&
            request.body.contains(voiceName),
      ),
      isNotEmpty,
    );
    expect(await mac.database.select(mac.database.syncOutbox).get(), isEmpty);
    expect(
      (await mac.database.select(mac.database.syncRecordSeqs).get()).length,
      (await _localRecordKeys(mac)).length,
    );
  });

  test('a pull below the cursor makes the device rebase', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    await _note(mac, 'counted');
    await _settled(mac);
    final int cursor = await readPullCursor(mac.database);
    final String generation = (await mac.syncState(relayGenerationKey))!;
    await writeSyncState(mac.database, pullCursorKey, '${cursor + 100}');
    final int sentBefore = mac.http.sent.length;

    await _rebased(mac, mac.engine());

    expect(await mac.syncState(relayGenerationKey), generation);
    expect(await mac.syncState(rebaseCounterKey), '1');
    final List<SentRequest> after = mac.http.sent.skip(sentBefore).toList();
    expect(
      after.where(
        (SentRequest request) =>
            request.path == _pull &&
            request.url.queryParameters[SyncRoutes.afterQuery] == '0',
      ),
      isNotEmpty,
    );
    expect(_pushedKeys(after), containsAll(await _localRecordKeys(mac)));
    expect(await readPullCursor(mac.database), lessThanOrEqualTo(cursor + 10));
    expect(await mac.database.select(mac.database.syncOutbox).get(), isEmpty);
  });

  test(
    'a change a restored relay lost comes back from the device that made it',
    () async {
      final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
      final SyncTestDevice phone = await pairDevice(
        relay,
        mac,
        device('Phone'),
      );
      await _note(mac, 'before the snapshot');
      await _settled(mac);
      await _settled(phone);
      final Directory saved = await snapshot();
      final domain.Entry lost = await _note(phone, 'saved after the snapshot');
      await _settled(phone);
      final String lostKey = KeyedNames(await phone.journalKeys())
          .recordKey(SyncedTables.entries, lost.id);

      await restart(from: saved, mark: true);
      final RelayClient check = RelayClient(
        baseUrl: relay.baseUrl,
        device: await mac.deviceKeys(),
      );
      addTearDown(check.close);
      expect(
        (await check.pull()).states.map(
          (protocol.RecordState state) => state.recordKey,
        ),
        isNot(contains(lostKey)),
      );

      await _rebased(phone, phone.engine());
      expect(
        (await check.pull()).states.map(
          (protocol.RecordState state) => state.recordKey,
        ),
        contains(lostKey),
      );
      await _rebased(mac, mac.engine());

      expect(await _texts(mac), contains('saved after the snapshot'));
      expect(await _texts(phone), contains('before the snapshot'));
    },
  );

  test('a rebase that fails waits before it is tried again', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    await _note(mac, 'before the restore');
    await _settled(mac);
    await restart(mark: true);
    int sessions = 0;
    mac.http.intercept = (http.BaseRequest request) async {
      if (request.url.path == SyncRoutes.session.pattern) {
        sessions += 1;
        if (sessions > 1) {
          return jsonAnswer(
            HttpStatus.internalServerError,
            const ErrorResponse(
              code: SyncErrorCode.badRequest,
              message: 'The relay is restarting',
            ).toJson(),
          );
        }
      }
      return null;
    };
    final SyncEngine engine = mac.engine();
    await engine.start();
    await engine.syncNow();

    await Future<void>.delayed(const Duration(seconds: 2));

    expect(sessions, lessThan(5));
    expect(engine.consecutiveFailures, greaterThan(0));
  });

  test('results from before a rebase are ignored', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    await _note(mac, 'already on the relay');
    await _settled(mac);
    final SyncTestDevice phone = await pairDevice(relay, mac, device('Phone'));
    final SyncTestMedia media = await SyncTestMedia.create(phone);
    final RelayClient client = phone.relayClient(
      relay.baseUrl,
      await phone.deviceKeys(),
      (_) {},
    );
    final StateApplier applier = StateApplier(
      database: phone.database,
      recorder: phone.recorder,
      localDeviceName: phone.name,
    );
    bool current = true;
    bool fence() => current;
    void rebaseDuring(String method, String path) {
      phone.http.intercept = (http.BaseRequest request) async {
        if (request.method == method && request.url.path == path) {
          current = false;
        }
        return null;
      };
    }

    rebaseDuring('GET', _pull);
    final PullResult page = await PullCycle(
      database: phone.database,
      applier: applier,
      keys: journalKeysFrom(phone.keyStore),
      refreshKeys: journalKeysFrom(phone.keyStore),
    ).run(client, isCurrent: fence);
    expect(page.dropped, isTrue);
    expect(await readPullCursor(phone.database), 0);
    expect(
      await phone.database.select(phone.database.syncRecordSeqs).get(),
      isEmpty,
    );
    expect(await _texts(phone), isEmpty);

    current = true;
    final domain.Day own = await phone.journal.ensureDayForDate('2026-10-24');
    await phone.journal.createEntry(
      dayId: own.id,
      type: domain.EntryType.text,
      textContent: 'pushed before the rebase',
    );
    final PushCycle push = PushCycle(
      database: phone.database,
      applier: applier,
      keys: journalKeysFrom(phone.keyStore),
      refreshKeys: journalKeysFrom(phone.keyStore),
    );
    final PushBatch batch = (await push.buildBatch())!;
    rebaseDuring('POST', _push);
    final PushResponse answer = await client.push(batch.request);
    expect(
      answer.results.map((RecordPushResult result) => result.status),
      everyElement(PushStatus.accepted),
    );
    await push.applyResponse(batch.request, answer, isCurrent: fence);
    expect(
      await phone.database.select(phone.database.syncOutbox).get(),
      hasLength(batch.request.changes.length),
    );
    expect(
      await phone.database.select(phone.database.syncRecordSeqs).get(),
      isEmpty,
    );

    current = true;
    final domain.MediaBlob blob = await media.store.putBytes(
      bytes: List<int>.generate(600, (int index) => (index * 3) % 251),
      mime: 'audio/mp4',
      kind: domain.MediaKind.audio,
    );
    final PendingUpload upload = (await media.uploads.prepare(blob.id))!;
    expect(upload.partCount, 1);
    rebaseDuring(
      'PUT',
      '/v1/blobs/${upload.blobName}/uploads/${upload.uploadId}/parts/0',
    );
    await media.uploads.sendOne(
      client,
      RelayUploadSender(client),
      upload,
      isCurrent: fence,
    );
    expect(await client.blobExists(upload.blobName), isTrue);
    expect(
      (await phone.database.select(phone.database.syncUploads).getSingle())
          .ackedParts,
      '[]',
    );
    expect(
      await phone.database.select(phone.database.syncMediaCache).get(),
      isEmpty,
    );

    current = true;
    rebaseDuring('HEAD', '/v1/blobs/${upload.blobName}');
    await media.uploads.sendOne(
      client,
      RelayUploadSender(client),
      upload,
      isCurrent: fence,
    );
    expect(
      await phone.database.select(phone.database.syncUploads).get(),
      hasLength(1),
    );
    expect(
      await phone.database.select(phone.database.syncMediaCache).get(),
      isEmpty,
    );

    current = true;
    final domain.Day day = await phone.journal.ensureDayForDate('2026-10-23');
    await phone.journal.createEntry(
      dayId: day.id,
      type: domain.EntryType.voice,
      mediaId: blob.id,
    );
    rebaseDuring('POST', '/v1/blobs/referenced');
    final List<String> lacking = await media.unusedBlobs.reportReferenced(
      client,
      isCurrent: fence,
    );
    expect(lacking, isEmpty);
    expect(
      await phone.database.select(phone.database.syncMediaCache).get(),
      isEmpty,
    );
    expect(await phone.syncState(referencedReportAtKey), isNull);
    expect(
      await phone.database.select(phone.database.syncUploads).get(),
      hasLength(1),
    );
  });

  test('a removal lost by a restore is sent again', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final SyncTestDevice phone = await pairDevice(relay, mac, device('Phone'));
    final SyncTestDevice tablet = await pairDevice(
      relay,
      mac,
      device('Tablet'),
    );
    await _note(mac, 'shared with three devices');
    await _settled(mac);
    await _settled(phone);
    final Directory saved = await snapshot();
    final String tabletId = await tablet.deviceId();
    final String accountId = relay.accountOf(await mac.deviceId());
    final int epoch = await DeviceService(
      database: mac.database,
      keyStore: mac.keyStore,
      client: await mac.plainClient(relay.baseUrl),
    ).remove(tabletId);
    expect(epoch, 2);
    await _settled(phone);
    expect((await phone.journalKeys()).currentEpoch, 2);

    await restart(from: saved, mark: true);
    expect(relay.isActiveDevice(tabletId), isTrue);
    expect(relay.currentEpoch(accountId), 1);

    await _rebased(mac, mac.engine());

    expect(relay.isActiveDevice(tabletId), isFalse);
    expect(relay.currentEpoch(accountId), 2);
    final JournalKeys macKeys = await mac.journalKeys();
    expect(macKeys.currentEpoch, 2);
    final RelayClient check = RelayClient(
      baseUrl: relay.baseUrl,
      device: await mac.deviceKeys(),
    );
    addTearDown(check.close);
    final List<protocol.RecordState> states = (await check.pull()).states;
    expect(states, isNotEmpty);
    expect(
      states.map((protocol.RecordState state) => state.epoch),
      everyElement(2),
    );
    final RelayClient tabletClient = RelayClient(
      baseUrl: relay.baseUrl,
      device: await tablet.deviceKeys(),
    );
    addTearDown(tabletClient.close);
    await expectLater(
      tabletClient.keys(),
      throwsA(
        isA<RelayRejected>().having(
          (RelayRejected error) => error.code,
          'code',
          SyncErrorCode.deviceRemoved,
        ),
      ),
    );

    final SyncEngine phoneEngine = await _rebased(phone, phone.engine());
    expect((await phone.journalKeys()).epochs, contains(2));
    expect(await phoneEngine.status(), isA<SyncedStatus>());
    expect(await _texts(phone), contains('shared with three devices'));
  });
}
