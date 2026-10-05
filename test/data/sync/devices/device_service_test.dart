import 'dart:convert';

import 'package:drift/native.dart';
import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/crypto/keyed_names.dart';
import 'package:field_notes/data/crypto/record_cipher.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/enrolment/restore_service.dart';
import 'package:field_notes/data/sync/pairing/pairing_service.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:flutter_test/flutter_test.dart';
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
  List<String> words = const <String>[];

  Future<JournalKeys> journal() async => (await keyStore.readJournalKeys())!;

  Future<DeviceKeys> device() async => (await keyStore.readDeviceKeys())!;

  Future<String> deviceId() async => (await device()).deviceId;

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

  PairingService pairing() => PairingService(
    database: database,
    keyStore: keyStore,
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
    final PendingEnrolment pending = await EnrolmentService(
      database: owner.database,
      keyStore: owner.keyStore,
      deviceName: () async => name,
    ).start(relayUrl: relay.baseUrl, inviteCode: relay.createInvite(name));
    owner.words = pending.words;
    return owner;
  }

  Future<_Device> paired(_Device host, String name) async {
    final _Device joiner = device(name);
    final HostedPairing hosted = await host.pairing().open();
    addTearDown(hosted.close);
    final Future<void> joining = joiner.pairing().join(
      hosted.code.phrase,
      relayUrl: relay.baseUrl,
    );
    await hosted.confirm(await hosted.waitForJoin());
    await joining;
    return joiner;
  }

  Future<RecordState> pushNote(_Device author, String text) async {
    final JournalKeys keys = await author.journal();
    final String recordKey = KeyedNames(keys).recordKey('entries', text);
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
    final PullResponse pulled = await client.pull();
    return pulled.states.singleWhere(
      (RecordState state) => state.recordKey == recordKey,
    );
  }

  Matcher refusedWith(SyncErrorCode code) => throwsA(
    isA<RelayRejected>().having(
      (RelayRejected error) => error.code,
      'code',
      code,
    ),
  );

  test('a removed device cannot read data pushed afterwards', () async {
    final _Device mac = await enrolled('Studio Mac');
    final _Device phone = await paired(mac, 'Pocket phone');
    final _Device tablet = await paired(mac, 'Old tablet');
    final RelayClient tabletClient = await tablet.client(relay.baseUrl);
    expect((await tabletClient.keys()).currentEpoch, 1);

    final DeviceService macDevices = await mac.devices(relay.baseUrl);
    final int epoch = await macDevices.remove(await tablet.deviceId());

    expect(epoch, 2);
    await expectLater(
      tabletClient.keys(),
      refusedWith(SyncErrorCode.deviceRemoved),
    );
    final DeviceService phoneDevices = await phone.devices(relay.baseUrl);
    expect((await phoneDevices.refreshKeys()).epochs, <int>[1, 2]);
    expect(
      (await phone.journal()).epochKey(2),
      (await mac.journal()).epochKey(2),
    );

    final RecordState pushed = await pushNote(phone, 'After the removal');

    expect(pushed.epoch, 2);
    expect(
      utf8.decode(
        RecordCipher(await mac.journal())
            .open(pushed.envelope, pushed.recordKey, pushed.epoch),
      ),
      'After the removal',
    );
    final JournalKeys tabletKeys = await tablet.journal();
    expect(tabletKeys.epochs, <int>[1]);
    expect(
      () =>
          RecordCipher(tabletKeys)
              .open(pushed.envelope, pushed.recordKey, pushed.epoch),
      throwsA(isA<CryptoException>()),
    );
    expect(
      () =>
          RecordCipher(tabletKeys.withEpoch(2, tabletKeys.epochKey(1)))
              .open(pushed.envelope, pushed.recordKey, pushed.epoch),
      throwsA(isA<CryptoException>()),
    );
    final DeviceService tabletDevices = await tablet.devices(relay.baseUrl);
    await expectLater(
      tabletDevices.refreshKeys(),
      refusedWith(SyncErrorCode.deviceRemoved),
    );
    final List<OwnRotation> kept = await macDevices.ownRotationsAbove(1);
    expect(
      kept.single.rotation.deliveries.map(
        (EpochKeyDelivery delivery) => delivery.recipient,
      ),
      isNot(contains((await tablet.device()).recipient)),
    );
  });

  test('a rotation from a device that removed itself is adopted', () async {
    final _Device mac = await enrolled('Studio Mac');
    final _Device phone = await paired(mac, 'Pocket phone');
    final String phoneId = await phone.deviceId();
    final DeviceService phoneDevices = await phone.devices(relay.baseUrl);

    final int epoch = await phoneDevices.remove(phoneId);

    expect(epoch, 2);
    expect(relay.isActiveDevice(phoneId), isFalse);
    expect((await phone.journal()).epochs, <int>[1]);
    final RelayClient macClient = await mac.client(relay.baseUrl);
    final EpochKeysResponse keys = await macClient.keys();
    expect(
      keys.devices.map((DeviceInfo device) => device.deviceId),
      contains(phoneId),
    );
    expect(keys.rotations.single.signerDeviceId, phoneId);

    final DeviceService macDevices = await mac.devices(relay.baseUrl);
    final JournalKeys adopted = await macDevices.refreshKeys();

    expect(adopted.epochs, <int>[1, 2]);
    expect(adopted.currentEpoch, 2);
    expect((await mac.journal()).epochs, <int>[1, 2]);
    final RecordState pushed = await pushNote(mac, 'Still syncing');
    expect(pushed.epoch, 2);
    expect(
      (await macDevices.list()).map((JournalDevice device) => device.name),
      <String>['Studio Mac'],
    );

    final _Device restored = device('Fresh install');
    final RestoredJournal journal = await RestoreService(
      database: restored.database,
      keyStore: restored.keyStore,
      deviceName: () async => restored.name,
    ).restore(relayUrl: relay.baseUrl, phrase: mac.words.join(' '));
    expect(journal.epochs, <int>[1, 2]);
  });

  test('a device keeps the rotations it makes', () async {
    final _Device mac = await enrolled('Studio Mac');
    final _Device phone = await paired(mac, 'Pocket phone');
    final _Device tablet = await paired(mac, 'Old tablet');
    final DeviceService macDevices = await mac.devices(relay.baseUrl);
    final String tabletId = await tablet.deviceId();

    final int epoch = await macDevices.remove(tabletId);

    final DeviceService reopened = await mac.devices(relay.baseUrl);
    final List<OwnRotation> kept = await reopened.ownRotationsAbove(1);
    expect(kept, hasLength(1));
    final OwnRotation rotation = kept.single;
    expect(rotation.epoch, epoch);
    expect(rotation.removedDeviceId, tabletId);
    expect(rotation.rotation.signerDeviceId, await mac.deviceId());
    expect(
      rotation.rotation.deliveries.map(
        (EpochKeyDelivery delivery) => delivery.recipient,
      ),
      unorderedEquals(<String>[
        (await mac.device()).recipient,
        (await phone.device()).recipient,
        EpochKeyDelivery.recoveryRecipient,
      ]),
    );
    final EpochKeysResponse phoneKeys = await (await phone.client(
      relay.baseUrl,
    )).keys();
    final EpochKeyDelivery delivered =
        phoneKeys.rotations.single.deliveries.single;
    expect(
      rotation.rotation.deliveries.singleWhere(
        (EpochKeyDelivery delivery) =>
            delivery.recipient == delivered.recipient,
      ),
      delivered,
    );
    for (final EpochKeyDelivery delivery in rotation.rotation.deliveries) {
      expect(
        verifyDelivery(
          epoch: epoch,
          signerDeviceId: rotation.rotation.signerDeviceId,
          delivery: delivery,
          devices: phoneKeys.devices,
          certifyingPublicKey: (await mac.journal()).certifyingPublicKey,
        ),
        isTrue,
      );
    }
    expect(await reopened.ownRotationsAbove(epoch), isEmpty);
    expect(
      (await reopened.ownRotationsAbove(0)).single.toJson(),
      rotation.toJson(),
    );
  });

  test('the last device cannot be removed', () async {
    final _Device mac = await enrolled('Studio Mac');
    final DeviceService macDevices = await mac.devices(relay.baseUrl);

    await expectLater(
      macDevices.remove(await mac.deviceId()),
      throwsA(isA<LastDeviceException>()),
    );

    expect(relay.isActiveDevice(await mac.deviceId()), isTrue);
    expect(await macDevices.ownRotationsAbove(0), isEmpty);
    expect((await mac.journal()).epochs, <int>[1]);
  });

  test('the device list shows each certified device by name', () async {
    final _Device mac = await enrolled('Studio Mac');
    await paired(mac, 'Pocket phone');

    final List<JournalDevice> listed = await (await mac.devices(relay.baseUrl))
        .list();

    expect(listed.map((JournalDevice device) => device.name), <String>[
      'Studio Mac',
      'Pocket phone',
    ]);
    expect(listed.map((JournalDevice device) => device.isThisDevice), <bool>[
      true,
      false,
    ]);
  });
}
