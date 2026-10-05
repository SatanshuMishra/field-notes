import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/keyed_names.dart';
import 'package:field_notes/data/crypto/record_cipher.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/engine/server_address.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/hlc.dart';
import 'package:field_notes/data/sync/merge/record_state.dart' as local;
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sync_protocol/sync_protocol.dart' as protocol show RecordState;
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;

import '../../../support/sync_overrides.dart';
import '../../../sync/support/relay_fixture.dart';

Future<String?> _relayAddress(SyncTestDevice device) async =>
    (await (device.database.select(
      device.database.journalSettings,
    )..where((t) => t.key.equals(relayAddressKey))).getSingleOrNull())?.value;

Future<List<String?>> _texts(SyncTestDevice device) async => <String?>[
  for (final Entry entry
      in await device.database.select(device.database.entries).get())
    entry.textContent,
];

Future<domain.Entry> _note(SyncTestDevice device, String text) async {
  final domain.Day day = await device.journal.ensureDayForDate('2026-10-21');
  return device.journal.createEntry(
    dayId: day.id,
    type: domain.EntryType.text,
    textContent: text,
  );
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

Future<SyncEngine> _running(SyncTestDevice device) async {
  final SyncEngine engine = device.engine();
  await engine.start();
  await engine.syncNow();
  return engine;
}

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

http.StreamedResponse _refused() => jsonAnswer(
  HttpStatus.forbidden,
  const ErrorResponse(
    code: SyncErrorCode.forbidden,
    message: 'Not this relay',
  ).toJson(),
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late RelayFixture relayA;
  RelayFixture? relayB;
  late List<SyncTestDevice> devices;

  setUp(() async {
    relayA = await RelayFixture.start(rateBurst: 1000);
    relayB = null;
    devices = <SyncTestDevice>[];
  });

  tearDown(() async {
    for (final SyncTestDevice device in devices) {
      await device.dispose();
    }
    await relayA.dispose();
    await relayB?.dispose();
  });

  SyncTestDevice device(String name) {
    final SyncTestDevice created = SyncTestDevice(name);
    devices.add(created);
    return created;
  }

  Future<RelayFixture> copyAToB() async {
    for (final SyncTestDevice each in devices) {
      await each.disposeEngines();
    }
    await relayA.stop();
    final Directory copy = await copyStoppedRelay(relayA);
    await relayA.boot();
    final RelayFixture copied = await startRelayOnCopy(copy);
    relayB = copied;
    for (final SyncTestDevice each in devices) {
      await pointAt(each, relayA);
    }
    return copied;
  }

  Future<(SyncTestDevice, SyncTestDevice)> pairOnA() async {
    final SyncTestDevice mac = await enrolDevice(relayA, device('Mac'));
    final SyncTestDevice phone = await pairDevice(relayA, mac, device('Phone'));
    await _note(mac, 'written before the move');
    await _running(mac);
    await _running(phone);
    return (mac, phone);
  }

  test('a new server address is adopted only after signing in there', () async {
    final (SyncTestDevice mac, SyncTestDevice phone) = await pairOnA();
    final RelayFixture b = await copyAToB();
    final SyncEngine macEngine = await _running(mac);
    bool? savedBeforeSignIn;
    mac.http.intercept = (http.BaseRequest request) async {
      if (request.url.port == b.port && request.url.path == '/v1/session') {
        savedBeforeSignIn ??= await _relayAddress(mac) != null;
      }
      return null;
    };

    final String? failure = await _address(
      mac,
      macEngine,
    ).changeServerAddress(b.baseUrl);

    expect(failure, isNull);
    expect(savedBeforeSignIn, isFalse);
    expect(await _relayAddress(mac), '${b.baseUrl}');
    await _switched(mac, macEngine, b);

    final SyncEngine phoneEngine = await _running(phone);
    await _switched(phone, phoneEngine, b);
    expect(
      phone.http.sent.where(
        (SentRequest request) =>
            request.url.port == b.port && request.path == '/v1/session',
      ),
      isNotEmpty,
    );
    expect(await _relayAddress(phone), '${b.baseUrl}');

    await _note(mac, 'written after the move');
    await macEngine.syncNow();
    await phoneEngine.syncNow();
    expect(await _texts(phone), contains('written after the move'));
  });

  test(
    'a failed sign-in keeps the old address and asks for attention',
    () async {
      final (SyncTestDevice mac, SyncTestDevice phone) = await pairOnA();
      final RelayFixture b = await copyAToB();
      final SyncEngine macEngine = await _running(mac);
      mac.http.intercept = (http.BaseRequest request) async =>
          request.url.port == b.port ? _refused() : null;

      final String? refused = await _address(
        mac,
        macEngine,
      ).changeServerAddress(b.baseUrl);

      expect(refused, isNotNull);
      expect(await _relayAddress(mac), isNull);
      expect(await mac.syncState(SyncStateKeys.relayUrl), '${relayA.baseUrl}');

      mac.http.intercept = null;
      expect(
        await _address(mac, macEngine).changeServerAddress(b.baseUrl),
        isNull,
      );
      await _switched(mac, macEngine, b);

      phone.http.intercept = (http.BaseRequest request) async =>
          request.url.port == b.port ? _refused() : null;
      final SyncEngine phoneEngine = await _running(phone);

      expect(await _relayAddress(phone), '${b.baseUrl}');
      expect(
        await phone.syncState(SyncStateKeys.relayUrl),
        '${relayA.baseUrl}',
      );
      final SyncStatus status = (await phoneEngine.status())!;
      expect(
        status.label(DateTime.now().toUtc()),
        "Needs attention · can't reach your new server",
      );

      phone.http.intercept = null;
      await phoneEngine.syncNow();
      await _switched(phone, phoneEngine, b);
      expect(await phoneEngine.status(), isNot(isA<AttentionStatus>()));
    },
  );

  test(
    'a change the old relay accepted after the copy reaches the other device',
    () async {
      final (SyncTestDevice mac, SyncTestDevice phone) = await pairOnA();
      final RelayFixture b = await copyAToB();
      final SyncEngine phoneEngine = await _running(phone);
      final domain.Entry late = await _note(phone, 'saved to A after the copy');
      await phoneEngine.syncNow();
      final String recordKey = KeyedNames(await phone.journalKeys())
          .recordKey(SyncedTables.entries, late.id);
      final RelayClient bClient = RelayClient(
        baseUrl: b.baseUrl,
        device: await mac.deviceKeys(),
      );
      addTearDown(bClient.close);
      expect(
        (await bClient.pull()).states.map(
          (protocol.RecordState state) => state.recordKey,
        ),
        isNot(contains(recordKey)),
      );

      final SyncEngine macEngine = await _running(mac);
      expect(
        await _address(mac, macEngine).changeServerAddress(b.baseUrl),
        isNull,
      );
      await _switched(mac, macEngine, b);
      await phoneEngine.syncNow();
      await _switched(phone, phoneEngine, b);
      await macEngine.syncNow();

      expect(
        (await bClient.pull()).states.map(
          (protocol.RecordState state) => state.recordKey,
        ),
        contains(recordKey),
      );
      expect(await _texts(mac), contains('saved to A after the copy'));
    },
  );

  test('an address the relay sends is ignored', () async {
    final SyncTestDevice mac = await enrolDevice(relayA, device('Mac'));
    final SyncEngine engine = await _running(mac);
    final JournalKeys keys = await mac.journalKeys();
    final String recordKey = KeyedNames(keys)
        .recordKey(SyncedTables.journalSettings, relayAddressKey);
    final String clock = Hlc(
      millis: DateTime.now().millisecondsSinceEpoch,
      counter: 0,
      nodeId: 'relay',
    ).encode();
    final local.RecordState forged = local.RecordState(
      table: SyncedTables.journalSettings,
      rowId: relayAddressKey,
      fields: <String, Object?>{
        'key': relayAddressKey,
        'value': 'https://elsewhere.example',
      },
      clocks: <String, String>{'key': clock, 'value': clock},
    );
    final String accountId = relayA.accountOf(await mac.deviceId());
    final int seq =
        (relayA.app.database.selectOne(
                  'SELECT last_seq FROM account_seqs WHERE account_id = ?',
                  <Object?>[accountId],
                )?['last_seq']
                as int? ??
            0) +
        1;
    relayA.app.database.execute(
      'INSERT INTO records (account_id, record_key, seq, epoch, envelope, '
      'change_id, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        accountId,
        recordKey,
        seq,
        1,
        RecordCipher(JournalKeys.generate())
            .seal(utf8.encode(jsonEncode(forged.toJson())), recordKey, 1),
        newSyncId(),
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
    relayA.app.database.execute(
      'INSERT INTO account_seqs (account_id, last_seq) VALUES (?, ?) '
      'ON CONFLICT (account_id) DO UPDATE SET last_seq = excluded.last_seq',
      <Object?>[accountId, seq],
    );

    await engine.syncNow();

    expect(await _relayAddress(mac), isNull);
    expect(await mac.syncState(SyncStateKeys.relayUrl), '${relayA.baseUrl}');
    expect(engine.relayTag.counter, 0);
    expect(await engine.status(), isA<SyncedStatus>());
  });

  test('the address switches only after the old relay accepts it', () async {
    final SyncTestDevice mac = await enrolDevice(relayA, device('Mac'));
    final RelayFixture b = await copyAToB();
    final SyncEngine engine = await _running(mac);
    bool refuse = true;
    int refusals = 0;
    mac.http.intercept = (http.BaseRequest request) async {
      if (refuse &&
          request.url.port == relayA.port &&
          request.method == 'POST' &&
          request.url.path == '/v1/records/push') {
        refusals += 1;
        return http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode('unavailable')),
          HttpStatus.serviceUnavailable,
        );
      }
      return null;
    };

    expect(await _address(mac, engine).changeServerAddress(b.baseUrl), isNull);
    expect(await _relayAddress(mac), '${b.baseUrl}');
    expect(refusals, greaterThanOrEqualTo(1));
    expect(await mac.syncState(SyncStateKeys.relayUrl), '${relayA.baseUrl}');

    await mac.clock.advance(const Duration(seconds: 3));
    await eventually(() async => refusals >= 2);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(await mac.syncState(SyncStateKeys.relayUrl), '${relayA.baseUrl}');
    final String recordKey = KeyedNames(await mac.journalKeys())
        .recordKey(SyncedTables.journalSettings, relayAddressKey);
    int heldByA() => relayA.app.database.count(
      'SELECT count(*) FROM records WHERE record_key = ?',
      <Object?>[recordKey],
    );
    expect(heldByA(), 0);

    refuse = false;
    await mac.clock.advance(const Duration(minutes: 1));
    await _switched(mac, engine, b);

    expect(heldByA(), 1);
  });
}
