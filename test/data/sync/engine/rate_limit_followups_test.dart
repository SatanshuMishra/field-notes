import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/keyed_names.dart';
import 'package:field_notes/data/sync/engine/server_address.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../support/sync_overrides.dart';
import '../../../sync/support/relay_fixture.dart';

http.StreamedResponse _tooMany() => jsonAnswer(
  HttpStatus.tooManyRequests,
  const ErrorResponse(
    code: SyncErrorCode.tooManyRequests,
    message: 'Too many requests',
  ).toJson(),
  headers: <String, String>{'retry-after': '1'},
);

List<int> _bytes(int length, int seed) =>
    List<int>.generate(length, (int index) => (index * 19 + seed) % 251);

Future<SyncEngine> _running(SyncTestDevice device) async {
  final SyncEngine engine = device.engine();
  await engine.start();
  await engine.syncNow();
  return engine;
}

ServerAddress _address(SyncTestDevice device, SyncEngine engine) =>
    ServerAddress(
      database: device.database,
      keyStore: device.keyStore,
      settings: device.journalSettings,
      syncNow: engine.syncNow,
      clientFor: (Uri baseUrl, DeviceKeys? keys) =>
          RelayClient(baseUrl: baseUrl, device: keys, client: device.http),
    );

Future<void> _switched(
  SyncTestDevice device,
  SyncEngine engine,
  RelayFixture relay,
) async {
  await eventually(
    () async =>
        await device.syncState(SyncStateKeys.relayUrl) == '${relay.baseUrl}' &&
        !engine.isRebasing,
  );
  await engine.syncNow();
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

  test(
    'a rate-limited live connection waits its turn without counting a failure',
    () async {
      final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
      final List<DateTime> attempts = <DateTime>[];
      Future<WebSocketChannel> connect(
        Uri uri,
        Map<String, String> headers,
      ) async {
        attempts.add(mac.clock.now());
        if (attempts.length <= 3) {
          throw WebSocketChannelException.from(
            WebSocketException(
              "Connection to '$uri' was not upgraded to websocket",
              HttpStatus.tooManyRequests,
            ),
          );
        }
        return connectWebSocket(uri, headers);
      }

      final SyncEngine engine = SyncEngine(
        database: mac.database,
        keyStore: mac.keyStore,
        recorder: mac.recorder,
        network: mac.network,
        lifecycle: mac.lifecycle,
        deviceName: () async => mac.name,
        clock: mac.clock,
        clientFor:
            (
              Uri baseUrl,
              DeviceKeys keys,
              void Function(SessionResponse session) onSession,
            ) => RelayClient(
              baseUrl: baseUrl,
              device: keys,
              onSession: onSession,
              client: mac.http,
              connectSocket: connect,
            ),
      );
      addTearDown(engine.dispose);
      final DateTime start = mac.clock.now();

      await engine.start();
      await engine.syncNow();

      for (int refused = 1; refused <= 3; refused++) {
        await eventually(
          () async => attempts.length == refused && mac.clock.pendingTimers > 0,
        );
        expect(engine.isLive, isFalse);
        expect(engine.consecutiveFailures, 0);
        expect(await engine.status(), isNot(isA<AttentionStatus>()));
        await mac.clock.advance(const Duration(milliseconds: 999));
        expect(attempts, hasLength(refused));
        await mac.clock.advance(const Duration(milliseconds: 1));
        await eventually(() async => attempts.length == refused + 1);
        expect(attempts.last, start.add(Duration(seconds: refused)));
      }
      await eventually(() async => engine.isLive);

      expect(attempts, hasLength(4));
      expect(engine.consecutiveFailures, 0);
      expect(await engine.status(), isA<SyncedStatus>());
    },
  );

  test('a rate-limited new server is not reported unreachable', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final SyncTestDevice phone = await pairDevice(relay, mac, device('Phone'));
    await _running(mac);
    await _running(phone);
    for (final SyncTestDevice each in devices) {
      await each.disposeEngines();
    }
    await relay.stop();
    final Directory copy = await copyStoppedRelay(relay);
    await relay.boot();
    final RelayFixture moved = await startRelayOnCopy(copy);
    addTearDown(moved.dispose);
    for (final SyncTestDevice each in devices) {
      await pointAt(each, relay);
    }
    final SyncEngine macEngine = await _running(mac);
    expect(
      await _address(mac, macEngine).changeServerAddress(moved.baseUrl),
      isNull,
    );
    await _switched(mac, macEngine, moved);
    int refusals = 0;
    DateTime? firstRefusal;
    phone.http.intercept = (http.BaseRequest request) async {
      if (request.url.port != moved.port ||
          request.url.path != '/v1/session/challenge') {
        return null;
      }
      final DateTime now = phone.clock.now();
      final DateTime first = firstRefusal ??= now;
      if (now.isBefore(first.add(const Duration(seconds: 1)))) {
        refusals += 1;
        return _tooMany();
      }
      return null;
    };

    final SyncEngine phoneEngine = await _running(phone);

    expect(refusals, 1);
    expect(await phoneEngine.status(), isNot(isA<AttentionStatus>()));
    expect(await phone.syncState(SyncStateKeys.relayUrl), '${relay.baseUrl}');
    await phone.clock.advance(const Duration(seconds: 1));
    await _switched(phone, phoneEngine, moved);
    expect(await phoneEngine.status(), isNot(isA<AttentionStatus>()));
    expect(phoneEngine.consecutiveFailures, 0);
  });

  test('rate-limited media is fetched after the wait', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final SyncTestDevice phone = await pairDevice(relay, mac, device('Phone'));
    final SyncTestMedia macMedia = await SyncTestMedia.create(mac);
    final SyncTestMedia phoneMedia = await SyncTestMedia.create(phone);
    final List<int> footage = _bytes(5000, 4);
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
    expect(await phoneMedia.downloads.hasFile(video.id), isFalse);
    final String path =
        '/v1/blobs/${KeyedNames(await phone.journalKeys()).blobName(video.id)}';
    int refusals = 0;
    phone.http.intercept = (http.BaseRequest request) async {
      if (refusals == 0 &&
          request.method == 'GET' &&
          request.url.path == path) {
        refusals += 1;
        return _tooMany();
      }
      return null;
    };
    final int timers = phone.clock.pendingTimers;
    bool? fetched;

    final Future<void> fetching = phoneEngine
        .fetchMedia(video.id)
        .then((bool value) => fetched = value);
    await eventually(
      () async => refusals == 1 && phone.clock.pendingTimers >= timers + 2,
    );
    await phone.clock.advance(const Duration(milliseconds: 999));
    expect(fetched, isNull);
    await phone.clock.advance(const Duration(milliseconds: 1));
    await fetching;

    expect(fetched, isTrue);
    expect(await phoneMedia.downloads.hasFile(video.id), isTrue);
    expect(phoneEngine.consecutiveFailures, 0);
  });
}
