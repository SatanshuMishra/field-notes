import 'dart:convert';
import 'dart:typed_data';

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
        ? joiner.pairing().join(
            hosted.code.qrPayload,
            confirmJournal: joinAnyJournal,
          )
        : joiner.pairing().join(
            hosted.code.phrase,
            relayUrl: relay.baseUrl,
            confirmJournal: joinAnyJournal,
          );
    final PairingCandidate candidate = await hosted.waitForJoin();
    expect(candidate.deviceName, name);
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
        confirmJournal: joinAnyJournal,
      ),
      "That code didn't work. Make a new one on your other device.",
    );
    await expectRetryMessage(
      phone.pairing().join(
        (<String>[...hosted.code.words]..[0] = 'notaword').join(' '),
        relayUrl: relay.baseUrl,
        confirmJournal: joinAnyJournal,
      ),
      "That code didn't work. Make a new one on your other device.",
    );

    relay.advance(const Duration(minutes: 10, seconds: 1));

    await expectRetryMessage(
      phone.pairing().join(
        hosted.code.phrase,
        relayUrl: relay.baseUrl,
        confirmJournal: joinAnyJournal,
      ),
      "That code didn't work. Make a new one on your other device.",
    );
    await expectRetryMessage(
      phone.pairing().join(
        hosted.code.qrPayload,
        confirmJournal: joinAnyJournal,
      ),
      "That code didn't work. Make a new one on your other device.",
    );
    expect(await phone.keyStore.readJournalKeys(), isNull);
    expect(
      await readSyncState(phone.database, SyncStateKeys.syncEnabled),
      isNull,
    );
    expect(relay.activeDevices((await mac.keyStore.readAccountId())!), 1);
  });

  test('a code naming a plain HTTP server says how to fix it', () async {
    final _Device phone = device('Pocket phone');
    final String plain = PairingCode(
      secret: List<int>.filled(pairingSecretBytes, 3),
      relayUrl: Uri.parse('https://192.168.1.20:8080'),
    ).qrPayload.replaceFirst('https://', 'http://');

    await expectRetryMessage(
      phone.pairing().join(plain, confirmJournal: joinAnyJournal),
      plainHttpPairingMessage,
    );
    expect(await phone.keyStore.readJournalKeys(), isNull);
  });

  test('a join cancelled while waiting stores nothing after Add', () async {
    final _Device mac = await enrolled('Mac');
    final _Device phone = device('Phone');
    final HostedPairing hosted = await mac.pairing().open();
    addTearDown(hosted.close);
    bool cancelled = false;

    final Future<void> joining = phone.pairing().join(
      hosted.code.qrPayload,
      cancelled: () => cancelled,
      confirmJournal: joinAnyJournal,
    );
    final Future<void> refused = expectLater(
      joining,
      throwsA(isA<PairingCancelled>()),
    );
    final PairingCandidate candidate = await hosted.waitForJoin();
    cancelled = true;
    await hosted.confirm(candidate);

    await refused;
    expect(await phone.keyStore.readJournalKeys(), isNull);
    expect(await phone.keyStore.readDeviceKeys(), isNull);
    expect(await readSyncState(phone.database, SyncStateKeys.relayUrl), isNull);
  });

  test(
    'joining names the journal and posts nothing until it is confirmed',
    () async {
      final _Device mac = await enrolled('Studio Mac');
      final _Device phone = device('Pocket phone');
      final HostedPairing hosted = await mac.pairing().open();
      addTearDown(hosted.close);
      final RelayClient watcher = RelayClient(baseUrl: relay.baseUrl);
      addTearDown(watcher.close);
      final List<String?> named = <String?>[];
      final List<PairingStatus> seen = <PairingStatus>[];
      final List<String> shown = <String>[];

      final Future<void> joining = phone.pairing().join(
        hosted.code.phrase,
        relayUrl: relay.baseUrl,
        confirmJournal: (String? label) async {
          named.add(label);
          seen.add(
            (await watcher.mailboxStatus(
              hosted.code.mailboxId,
              hosted.code.mailboxToken,
            )).status,
          );
          return true;
        },
        onComparison: shown.add,
      );
      final PairingCandidate candidate = await hosted.waitForJoin();
      await hosted.confirm(candidate);
      await joining;

      expect(named, <String?>['Studio Mac']);
      expect(seen, <PairingStatus>[PairingStatus.open]);
      expect(candidate.comparison, matches(RegExp(r'^[0-9]{3} [0-9]{3}$')));
      expect(shown, <String>[candidate.comparison]);
      expect(await phone.keyStore.readJournalKeys(), isNotNull);
    },
  );

  test('declining the journal posts and stores nothing', () async {
    final _Device mac = await enrolled('Alex');
    final _Device phone = device('Pocket phone');
    final HostedPairing hosted = await mac.pairing().open();
    addTearDown(hosted.close);
    final RelayClient watcher = RelayClient(baseUrl: relay.baseUrl);
    addTearDown(watcher.close);

    await expectLater(
      phone.pairing().join(
        hosted.code.qrPayload,
        confirmJournal: (String? label) async => false,
      ),
      throwsA(isA<PairingDeclined>()),
    );

    expect(
      (await watcher.mailboxStatus(
        hosted.code.mailboxId,
        hosted.code.mailboxToken,
      )).status,
      PairingStatus.open,
    );
    expect(await phone.keyStore.readJournalKeys(), isNull);
    expect(await phone.keyStore.readDeviceKeys(), isNull);
    expect(await readSyncState(phone.database, SyncStateKeys.relayUrl), isNull);
    expect(relay.activeDevices((await mac.keyStore.readAccountId())!), 1);
  });

  test(
    'a code another device used first is reported, before or after asking',
    () async {
      final _Device mac = await enrolled('Studio Mac');
      final _Device phone = device('Pocket phone');
      final RelayClient racer = RelayClient(baseUrl: relay.baseUrl);
      addTearDown(racer.close);
      Future<void> raceFor(HostedPairing hosted) async {
        final DeviceKeys keys = DeviceKeys.generate();
        final DeviceRegistration registration = keys.registration(
          certificate: keys.sign(
            deviceCertificateBytes(
              deviceId: keys.deviceId,
              signPublicKey: keys.signKeyPair.publicKey,
              boxPublicKey: keys.boxKeyPair.publicKey,
            ),
          ),
          encryptedName: sealNameUnder(
            'Racer',
            keys.deviceId,
            hosted.code.pairingKey,
          ),
        );
        await racer.joinPairing(
          hosted.code.mailboxId,
          hosted.code.mailboxToken,
          PairingJoinRequest(
            device: registration,
            authenticator: hosted.code.authenticatorFor(registration),
          ),
        );
      }

      final HostedPairing first = await mac.pairing().open();
      addTearDown(first.close);
      await raceFor(first);
      final List<String?> asked = <String?>[];
      await expectLater(
        phone.pairing().join(
          first.code.qrPayload,
          confirmJournal: (String? label) async {
            asked.add(label);
            return true;
          },
        ),
        throwsA(
          isA<PairingTaken>().having(
            (PairingTaken error) => error.message,
            'message',
            pairingTakenMessage,
          ),
        ),
      );
      expect(asked, isEmpty);

      final HostedPairing second = await mac.pairing().open();
      addTearDown(second.close);
      final List<String> shown = <String>[];
      await expectLater(
        phone.pairing().join(
          second.code.qrPayload,
          confirmJournal: (String? label) async {
            await raceFor(second);
            return true;
          },
          onComparison: shown.add,
        ),
        throwsA(isA<PairingTaken>()),
      );
      expect(shown, isEmpty);
      expect((await second.waitForJoin()).deviceName, 'Racer');
      expect(await phone.keyStore.readJournalKeys(), isNull);
    },
  );

  Future<void> joinAs(
    RelayClient client,
    HostedPairing hosted,
    DeviceKeys keys,
    String name,
  ) async {
    final DeviceRegistration registration = keys.registration(
      certificate: keys.sign(
        deviceCertificateBytes(
          deviceId: keys.deviceId,
          signPublicKey: keys.signKeyPair.publicKey,
          boxPublicKey: keys.boxKeyPair.publicKey,
        ),
      ),
      encryptedName: sealNameUnder(name, keys.deviceId, hosted.code.pairingKey),
    );
    await client.joinPairing(
      hosted.code.mailboxId,
      hosted.code.mailboxToken,
      PairingJoinRequest(
        device: registration,
        authenticator: hosted.code.authenticatorFor(registration),
      ),
    );
  }

  test('only the joining device can open the keys the Mac leaves', () async {
    final _Device mac = await enrolled('Studio Mac');
    final HostedPairing hosted = await mac.pairing().open();
    addTearDown(hosted.close);
    final RelayClient joiner = RelayClient(baseUrl: relay.baseUrl);
    addTearDown(joiner.close);
    final DeviceKeys phone = DeviceKeys.generate();
    await joinAs(joiner, hosted, phone, 'Pocket phone');
    await hosted.confirm(await hosted.waitForJoin());

    final RelayClient onlooker = RelayClient(baseUrl: relay.baseUrl);
    addTearDown(onlooker.close);
    final Uint8List bundle = (await onlooker.mailboxStatus(
      hosted.code.mailboxId,
      hosted.code.mailboxToken,
    )).keyBundle!;

    expect(
      () => openPairingBundle(bundle, hosted.code.pairingKey),
      throwsA(isA<CryptoException>()),
    );
    expect(
      () => openPairingBundleFor(
        bundle,
        hosted.code.pairingKey,
        DeviceKeys.generate().boxKeyPair,
      ),
      throwsA(isA<CryptoException>()),
    );
    expect(
      openPairingBundleFor(
        bundle,
        hosted.code.pairingKey,
        phone.boxKeyPair,
      ).epochKeys,
      (await mac.journal()).epochKeys,
    );
  });

  test('the Mac shows a short, plain name for the joining device', () async {
    final _Device mac = await enrolled('Studio Mac');
    final RelayClient joiner = RelayClient(baseUrl: relay.baseUrl);
    addTearDown(joiner.close);
    final HostedPairing hosted = await mac.pairing().open();
    addTearDown(hosted.close);

    await joinAs(
      joiner,
      hosted,
      DeviceKeys.generate(),
      'Pixel 8?\n\n\n\u202eevil\u202c  Tap Add ${'x' * 200}',
    );
    final PairingCandidate candidate = await hosted.waitForJoin();

    expect(candidate.deviceName, startsWith('Pixel 8? evil Tap Add x'));
    expect(candidate.deviceName.runes.length, shownDeviceNameLength);
    expect(candidate.deviceName, endsWith('\u2026'));
    expect(candidate.deviceName, isNot(contains('\n')));
    expect(candidate.deviceName, isNot(contains('\u202e')));
    expect(shownDeviceName(' \u200f\t '), unnamedDeviceName);
    expect(shownDeviceName('Studio Mac'), 'Studio Mac');
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
      hosted.confirm(
        PairingCandidate(
          deviceName: 'Intruder',
          join: forged,
          comparison: '000 000',
        ),
      ),
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
    http.Response waiting() => http.Response(
      jsonEncode(PairingStatusResponse(status: PairingStatus.open).toJson()),
      200,
    );
    bool refuseJoin = true;
    bool posted = false;
    final MockClient relayDouble = MockClient((http.Request request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/join')) {
        joins.add(now);
        if (refuseJoin) {
          return limited();
        }
        posted = true;
        return joined();
      }
      if (!posted) {
        return waiting();
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
      service().join(code.qrPayload, confirmJournal: joinAnyJournal),
      'Too many tries. Wait a minute and try again.',
    );
    expect(polls, isEmpty);

    refuseJoin = false;
    await expectRetryMessage(
      service().join(
        code.phrase,
        relayUrl: relayUrl,
        confirmJournal: joinAnyJournal,
      ),
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
