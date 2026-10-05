import 'dart:convert';

import 'package:drift/native.dart';
import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/device_names.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/crypto/keyed_names.dart';
import 'package:field_notes/data/crypto/record_cipher.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/pairing/pairing_code.dart';
import 'package:field_notes/data/sync/pairing/pairing_service.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sync_protocol/sync_protocol.dart';

import '../../../sync/support/relay_fixture.dart';

Future<void> _quickly(Duration duration) =>
    Future<void>.delayed(const Duration(milliseconds: 10));

final class _Device {
  _Device(this.name)
    : database = AppDatabase(NativeDatabase.memory()),
      keyStore = KeyStore(MemorySecureValues());

  final String name;
  final AppDatabase database;
  final KeyStore keyStore;
  final List<RelayClient> _clients = <RelayClient>[];

  Future<JournalKeys> journal() async => (await keyStore.readJournalKeys())!;

  Future<DeviceKeys> device() async => (await keyStore.readDeviceKeys())!;

  Future<RelayClient> client(Uri relayUrl) async {
    final RelayClient client = RelayClient(
      baseUrl: relayUrl,
      device: await keyStore.readDeviceKeys(),
    );
    _clients.add(client);
    return client;
  }

  Future<DeviceService> devices(Uri relayUrl) async => DeviceService(
    database: database,
    keyStore: keyStore,
    client: await client(relayUrl),
  );

  PairingService pairing({RelayClientFactory? clientFor}) => PairingService(
    database: database,
    keyStore: keyStore,
    clientFor: clientFor ?? defaultRelayClient,
    deviceName: () async => name,
    wait: _quickly,
  );

  Future<void> dispose() async {
    for (final RelayClient client in _clients) {
      client.close();
    }
    await database.close();
  }
}

void main() {
  late RelayFixture relay;
  late List<_Device> devices;

  setUp(() async {
    relay = await RelayFixture.start(rateBurst: 1000);
    devices = <_Device>[];
  });

  tearDown(() async {
    for (final _Device device in devices) {
      await device.dispose();
    }
    await relay.dispose();
  });

  _Device device(String name) {
    final _Device created = _Device(name);
    devices.add(created);
    return created;
  }

  Future<_Device> enrolled(String name) async {
    final _Device owner = device(name);
    await EnrolmentService(
      database: owner.database,
      keyStore: owner.keyStore,
      deviceName: () async => name,
    ).start(relayUrl: relay.baseUrl, inviteCode: relay.createInvite(name));
    return owner;
  }

  Future<_Device> paired(_Device host, String name, {bool byQr = false}) async {
    final _Device joiner = device(name);
    final HostedPairing hosted = await host.pairing().open();
    addTearDown(hosted.close);
    final Future<void> joining = byQr
        ? joiner.pairing().join(hosted.code.qrPayload)
        : joiner.pairing().join(hosted.code.phrase, relayUrl: relay.baseUrl);
    final PairingCandidate candidate = await hosted.waitForJoin();
    expect(candidate.prompt, 'Add $name?');
    await hosted.confirm(candidate);
    await joining;
    return joiner;
  }

  Future<String> pushNote(_Device author, String rowId, String text) async {
    final JournalKeys keys = await author.journal();
    final String recordKey = KeyedNames(keys).recordKey('entries', rowId);
    final RelayClient client = await author.client(relay.baseUrl);
    final PushResponse response = await client.push(
      PushRequest(
        changes: <RecordPush>[
          RecordPush(
            recordKey: recordKey,
            baseSeq: 0,
            changeId: newSyncId(),
            epoch: keys.currentEpoch,
            envelope: RecordCipher(keys)
                .seal(utf8.encode(text), recordKey, keys.currentEpoch),
          ),
        ],
      ),
    );
    expect(response.results.single.status, PushStatus.accepted);
    return recordKey;
  }

  Future<void> expectRetryMessage(Future<void> attempt, String message) =>
      expectLater(
        attempt,
        throwsA(
          isA<SyncSetupException>().having(
            (SyncSetupException error) => error.message,
            'message',
            message,
          ),
        ),
      );

  test('a confirmed code gives the new device every epoch key', () async {
    final _Device mac = await enrolled('Studio Mac');
    final _Device tablet = await paired(mac, 'Old tablet');
    final DeviceService macDevices = await mac.devices(relay.baseUrl);
    final int epoch = await macDevices.remove((await tablet.device()).deviceId);
    expect(epoch, 2);

    final _Device phone = await paired(mac, 'Pocket phone');
    final _Device laptop = await paired(mac, 'Travel laptop', byQr: true);

    final JournalKeys macKeys = await mac.journal();
    for (final _Device joined in <_Device>[phone, laptop]) {
      final JournalKeys keys = await joined.journal();
      expect(keys.epochs, <int>[1, 2]);
      expect(keys.epochKeys, macKeys.epochKeys);
      expect(keys.currentEpoch, 2);
      expect(
        await joined.keyStore.readAccountId(),
        await mac.keyStore.readAccountId(),
      );
      expect(
        await readSyncState(joined.database, SyncStateKeys.relayUrl),
        '${relay.baseUrl}',
      );
      expect(
        await readSyncState(joined.database, SyncStateKeys.syncEnabled),
        'true',
      );
    }

    final String recordKey = await pushNote(mac, 'entry-1', 'Pulled across');
    final RelayClient phoneClient = await phone.client(relay.baseUrl);
    final PullResponse pulled = await phoneClient.pull();
    final RecordState state = pulled.states.singleWhere(
      (RecordState candidate) => candidate.recordKey == recordKey,
    );
    expect(state.epoch, 2);
    expect(
      utf8.decode(
        RecordCipher(await phone.journal())
            .open(state.envelope, recordKey, state.epoch),
      ),
      'Pulled across',
    );

    final List<JournalDevice> listed = await macDevices.list();
    expect(listed.map((JournalDevice device) => device.name), <String>[
      'Studio Mac',
      'Pocket phone',
      'Travel laptop',
    ]);
  });

  test('a wrong or expired code shows the retry message', () async {
    final _Device mac = await enrolled('Studio Mac');
    final _Device phone = device('Pocket phone');
    final HostedPairing hosted = await mac.pairing().open();
    addTearDown(hosted.close);

    await expectRetryMessage(
      phone.pairing().join(
        PairingCode.generate().phrase,
        relayUrl: relay.baseUrl,
      ),
      "That code didn't work. Make a new one on your other device.",
    );
    await expectRetryMessage(
      phone.pairing().join(
        (<String>[...hosted.code.words]..[0] = 'notaword').join(' '),
        relayUrl: relay.baseUrl,
      ),
      "That code didn't work. Make a new one on your other device.",
    );

    relay.advance(const Duration(minutes: 10, seconds: 1));

    await expectRetryMessage(
      phone.pairing().join(hosted.code.phrase, relayUrl: relay.baseUrl),
      "That code didn't work. Make a new one on your other device.",
    );
    await expectRetryMessage(
      phone.pairing().join(hosted.code.qrPayload),
      "That code didn't work. Make a new one on your other device.",
    );
    expect(await phone.keyStore.readJournalKeys(), isNull);
    expect(
      await readSyncState(phone.database, SyncStateKeys.syncEnabled),
      isNull,
    );
    expect(relay.activeDevices((await mac.keyStore.readAccountId())!), 1);
  });

  test('a join with a mismatched authenticator gets no keys', () async {
    final _Device mac = await enrolled('Studio Mac');
    final String accountId = (await mac.keyStore.readAccountId())!;
    final HostedPairing hosted = await mac.pairing().open();
    addTearDown(hosted.close);
    final DeviceKeys intruder = DeviceKeys.generate();
    final DeviceRegistration registration = intruder.registration(
      certificate: intruder.sign(
        deviceCertificateBytes(
          deviceId: intruder.deviceId,
          signPublicKey: intruder.signKeyPair.publicKey,
          boxPublicKey: intruder.boxKeyPair.publicKey,
        ),
      ),
      encryptedName: sealNameUnder(
        'Intruder',
        intruder.deviceId,
        hosted.code.pairingKey,
      ),
    );
    final PairingJoinRequest forged = PairingJoinRequest(
      device: registration,
      authenticator: PairingCode.generate().authenticatorFor(registration),
    );
    final RelayClient intruderClient = RelayClient(baseUrl: relay.baseUrl);
    addTearDown(intruderClient.close);
    await intruderClient.joinPairing(
      hosted.code.mailboxId,
      hosted.code.mailboxToken,
      forged,
    );

    await expectLater(hosted.waitForJoin(), throwsA(isA<PairingRefused>()));
    await expectLater(
      hosted.confirm(PairingCandidate(deviceName: 'Intruder', join: forged)),
      throwsA(isA<PairingRefused>()),
    );

    final PairingStatusResponse status = await intruderClient.mailboxStatus(
      hosted.code.mailboxId,
      hosted.code.mailboxToken,
    );
    expect(status.status, PairingStatus.joined);
    expect(status.keyBundle, isNull);
    expect(relay.activeDevices(accountId), 1);
    expect(relay.isActiveDevice(intruder.deviceId), isFalse);
  });

  test('a relay-forged epoch delivery is ignored', () async {
    final _Device mac = await enrolled('Studio Mac');
    final _Device phone = await paired(mac, 'Pocket phone');
    final String accountId = (await mac.keyStore.readAccountId())!;
    final DeviceKeys macKeys = await mac.device();
    final DeviceKeys phoneKeys = await phone.device();
    final DeviceKeys forger = DeviceKeys.generate();
    final JournalKeys relayJournal = JournalKeys.generate();
    relay.insertDevice(
      accountId,
      forger.registration(
        certificate: forger.certifyWith(relayJournal),
        encryptedName: sealDeviceName('Relay', forger.deviceId, relayJournal),
      ),
    );
    final List<RotationRecipient> victims = <RotationRecipient>[
      RotationRecipient(
        recipient: macKeys.recipient,
        boxPublicKey: macKeys.boxKeyPair.publicKey,
      ),
      RotationRecipient(
        recipient: phoneKeys.recipient,
        boxPublicKey: phoneKeys.boxKeyPair.publicKey,
      ),
    ];
    relay.insertRotation(
      accountId,
      makeRotation(
        epoch: 2,
        epochKey: JournalKeys.newEpochKey(),
        signer: forger,
        recipients: victims,
      ),
    );
    final DeviceKeys impostor = DeviceKeys(
      deviceId: macKeys.deviceId,
      signKeyPair: forger.signKeyPair,
      boxKeyPair: macKeys.boxKeyPair,
    );
    relay.insertRotation(
      accountId,
      makeRotation(
        epoch: 3,
        epochKey: JournalKeys.newEpochKey(),
        signer: impostor,
        recipients: victims,
      ),
    );

    final DeviceService macDevices = await mac.devices(relay.baseUrl);
    final DeviceService phoneDevices = await phone.devices(relay.baseUrl);
    expect((await macDevices.refreshKeys()).epochs, <int>[1]);
    expect((await phoneDevices.refreshKeys()).epochs, <int>[1]);
    expect((await mac.journal()).epochs, <int>[1]);

    final List<JournalDevice> listed = await macDevices.list();
    expect(listed.map((JournalDevice device) => device.deviceId), <String>[
      macKeys.deviceId,
      phoneKeys.deviceId,
    ]);

    final int epoch = await macDevices.remove(phoneKeys.deviceId);
    expect(epoch, 4);
    final List<OwnRotation> kept = await macDevices.ownRotationsAbove(0);
    expect(
      kept.single.rotation.deliveries.map(
        (EpochKeyDelivery delivery) => delivery.recipient,
      ),
      <String>[macKeys.recipient, EpochKeyDelivery.recoveryRecipient],
    );
    expect((await mac.journal()).epochs, <int>[1, 4]);
  });

  test('a rate-limited pairing asks the user to wait', () async {
    final Uri relayUrl = Uri.parse('https://sync.example.test');
    final PairingCode code = PairingCode.generate(relayUrl: relayUrl);
    final _Device phone = device('Pocket phone');
    DateTime now = DateTime.utc(2026, 10, 5, 9);
    final List<DateTime> joins = <DateTime>[];
    final List<DateTime> polls = <DateTime>[];
    http.Response limited() => http.Response(
      jsonEncode(
        const ErrorResponse(
          code: SyncErrorCode.tooManyRequests,
          message: 'too_many_requests',
        ).toJson(),
      ),
      429,
      headers: <String, String>{'retry-after': '1'},
    );
    http.Response joined() => http.Response(
      jsonEncode(PairingStatusResponse(status: PairingStatus.joined).toJson()),
      200,
    );
    bool refuseJoin = true;
    final MockClient relayDouble = MockClient((http.Request request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/join')) {
        joins.add(now);
        return refuseJoin ? limited() : joined();
      }
      polls.add(now);
      return polls.length > 3 ? limited() : joined();
    });
    PairingService service() => PairingService(
      database: phone.database,
      keyStore: phone.keyStore,
      clientFor: (Uri url, DeviceKeys? device) =>
          RelayClient(baseUrl: url, device: device, client: relayDouble),
      deviceName: () async => phone.name,
      wait: (Duration duration) async {
        now = now.add(duration);
      },
      clock: () => now,
    );

    await expectRetryMessage(
      service().join(code.qrPayload),
      'Too many tries. Wait a minute and try again.',
    );
    expect(polls, isEmpty);

    refuseJoin = false;
    await expectRetryMessage(
      service().join(code.phrase, relayUrl: relayUrl),
      'Too many tries. Wait a minute and try again.',
    );
    expect(polls, hasLength(4));
    final List<DateTime> times = <DateTime>[joins.last, ...polls];
    for (int index = 1; index < times.length; index++) {
      expect(
        times[index].difference(times[index - 1]),
        greaterThanOrEqualTo(const Duration(seconds: 2)),
      );
    }
    expect(await phone.keyStore.readJournalKeys(), isNull);

    final _Device mac = device('Studio Mac');
    await storeEnrolledDevice(
      database: mac.database,
      keyStore: mac.keyStore,
      relayUrl: relayUrl,
      accountId: newSyncId(),
      journalKeys: JournalKeys.generate(),
      deviceKeys: DeviceKeys.generate(),
    );
    final MockClient limitedRelay = MockClient(
      (http.Request request) async => http.Response(
        '<html><body>Error 1015: You are being rate limited</body></html>',
        429,
      ),
    );
    await expectRetryMessage(
      mac
          .pairing(
            clientFor: (Uri url, DeviceKeys? device) =>
                RelayClient(baseUrl: url, device: device, client: limitedRelay),
          )
          .open(),
      'Too many tries. Wait a minute and try again.',
    );
  });
}
