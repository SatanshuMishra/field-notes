import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/device_names.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/crypto/recovery_phrase.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/enrolment/restore_service.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sync_protocol/sync_protocol.dart';

import '../../../sync/support/relay_fixture.dart';

final class _Enrolled {
  const _Enrolled({
    required this.words,
    required this.accountId,
    required this.journal,
    required this.device,
    required this.recovery,
  });

  final List<String> words;
  final String accountId;
  final JournalKeys journal;
  final DeviceKeys device;
  final RecoveryPublicKeys recovery;
}

void main() {
  late RelayFixture relay;
  late AppDatabase enrolledDatabase;
  late AppDatabase freshDatabase;
  late KeyStore enrolledKeys;
  late KeyStore freshKeys;

  setUp(() async {
    relay = await RelayFixture.start();
    enrolledDatabase = AppDatabase(NativeDatabase.memory());
    freshDatabase = AppDatabase(NativeDatabase.memory());
    enrolledKeys = KeyStore(MemorySecureValues());
    freshKeys = KeyStore(MemorySecureValues());
  });

  tearDown(() async {
    await enrolledDatabase.close();
    await freshDatabase.close();
    await relay.dispose();
  });

  Future<_Enrolled> enrol() async {
    final PendingEnrolment pending = await EnrolmentService(
      database: enrolledDatabase,
      keyStore: enrolledKeys,
      deviceName: () async => 'Studio Mac',
    ).start(relayUrl: relay.baseUrl, inviteCode: relay.createInvite('Owner'));
    return _Enrolled(
      words: pending.words,
      accountId: (await enrolledKeys.readAccountId())!,
      journal: (await enrolledKeys.readJournalKeys())!,
      device: (await enrolledKeys.readDeviceKeys())!,
      recovery: (await enrolledKeys.readRecoveryPublicKeys())!,
    );
  }

  RestoreService restorer({RelayClientFactory? clientFor}) => RestoreService(
    database: freshDatabase,
    keyStore: freshKeys,
    clientFor: clientFor ?? defaultRelayClient,
    deviceName: () async => 'Pocket phone',
  );

  test('the recovery phrase opens every epoch key', () async {
    final _Enrolled enrolled = await enrol();
    final DeviceKeys departed = DeviceKeys.generate();
    relay.insertDevice(
      enrolled.accountId,
      departed.registration(
        certificate: departed.certifyWith(enrolled.journal),
        encryptedName: sealDeviceName(
          'Old tablet',
          departed.deviceId,
          enrolled.journal,
        ),
      ),
    );
    final RelayClient owner = RelayClient(
      baseUrl: relay.baseUrl,
      device: enrolled.device,
    );
    addTearDown(owner.close);
    final EpochKeysResponse before = await owner.keys();
    final Uint8List epochTwo = JournalKeys.newEpochKey();
    relay.insertRotation(
      enrolled.accountId,
      makeRotation(
        epoch: 2,
        epochKey: epochTwo,
        signer: enrolled.device,
        recipients: <RotationRecipient>[
          for (final DeviceInfo device in before.devices)
            if (device.deviceId != departed.deviceId)
              RotationRecipient.device(device),
          RotationRecipient.recovery(enrolled.recovery.boxPublicKey),
        ],
      ),
    );
    expect(relay.currentEpoch(enrolled.accountId), 2);

    final String typed = enrolled.words
        .map((String word) => word.toUpperCase())
        .join('  ');
    final RestoredJournal restored = await restorer().restore(
      relayUrl: relay.baseUrl,
      phrase: ' $typed ',
    );

    expect(restored.accountId, enrolled.accountId);
    expect(restored.epochs, <int>[1, 2]);
    final JournalKeys? journal = await freshKeys.readJournalKeys();
    expect(journal, isNotNull);
    expect(journal!.currentEpoch, 2);
    expect(journal.epochKey(1), enrolled.journal.epochKey(1));
    expect(journal.epochKey(2), epochTwo);
    expect(journal.certifyingPublicKey, enrolled.journal.certifyingPublicKey);
    expect(await freshKeys.readAccountId(), enrolled.accountId);
    final RecoveryPublicKeys? recovery = await freshKeys
        .readRecoveryPublicKeys();
    expect(recovery?.boxPublicKey, enrolled.recovery.boxPublicKey);
    expect(
      await readSyncState(freshDatabase, SyncStateKeys.relayUrl),
      '${relay.baseUrl}',
    );
    expect(
      await readSyncState(freshDatabase, SyncStateKeys.syncEnabled),
      'true',
    );

    final DeviceKeys? device = await freshKeys.readDeviceKeys();
    expect(device?.deviceId, restored.deviceId);
    expect(relay.isActiveDevice(restored.deviceId), isTrue);
    final RelayClient restoredClient = RelayClient(
      baseUrl: relay.baseUrl,
      device: device,
    );
    addTearDown(restoredClient.close);
    final EpochKeysResponse keys = await restoredClient.keys();
    final DeviceInfo registered = keys.devices.firstWhere(
      (DeviceInfo info) => info.deviceId == restored.deviceId,
    );
    expect(
      isCertifiedDevice(enrolled.journal.certifyingPublicKey, registered),
      isTrue,
    );
    expect(
      openDeviceName(
        registered.encryptedName,
        restored.deviceId,
        enrolled.journal,
      ),
      'Pocket phone',
    );
  });

  test(
    'a recovery delivery from an uncertified signer is not adopted',
    () async {
      final _Enrolled enrolled = await enrol();
      final JournalKeys stranger = JournalKeys.generate();
      final DeviceKeys forger = DeviceKeys.generate();
      relay.insertDevice(
        enrolled.accountId,
        forger.registration(
          certificate: forger.certifyWith(stranger),
          encryptedName: sealDeviceName('Forger', forger.deviceId, stranger),
        ),
      );
      relay.insertRotation(
        enrolled.accountId,
        makeRotation(
          epoch: 2,
          epochKey: JournalKeys.newEpochKey(),
          signer: forger,
          recipients: <RotationRecipient>[
            RotationRecipient.recovery(enrolled.recovery.boxPublicKey),
          ],
        ),
      );

      final RestoredJournal restored = await restorer().restore(
        relayUrl: relay.baseUrl,
        phrase: enrolled.words.join(' '),
      );

      expect(restored.epochs, <int>[1]);
      expect((await freshKeys.readJournalKeys())?.epochs, <int>[1]);
    },
  );

  test('a mistyped phrase is refused before any network call', () async {
    int calls = 0;
    final MockClient counting = MockClient((http.Request request) async {
      calls++;
      return http.Response('', 500);
    });
    final List<String> words = recoveryWords(newRecoverySeed());
    final RestoreService service = restorer(
      clientFor: (Uri url, DeviceKeys? device) =>
          RelayClient(baseUrl: url, device: device, client: counting),
    );

    await expectLater(
      service.restore(
        relayUrl: relay.baseUrl,
        phrase: (<String>[...words]..[4] = 'zebraa').join(' '),
      ),
      throwsA(
        isA<SyncSetupException>().having(
          (SyncSetupException error) => error.message,
          'message',
          '"zebraa" isn\'t one of the recovery words. Check your phrase.',
        ),
      ),
    );
    await expectLater(
      service.restore(
        relayUrl: relay.baseUrl,
        phrase: words.take(11).join(' '),
      ),
      throwsA(isA<SyncSetupException>()),
    );
    expect(calls, 0);
    expect(await freshKeys.readJournalKeys(), isNull);
  });

  test('a phrase for no journal on the relay says so', () async {
    await expectLater(
      restorer().restore(
        relayUrl: relay.baseUrl,
        phrase: encodeRecoveryPhrase(newRecoverySeed()),
      ),
      throwsA(
        isA<SyncSetupException>().having(
          (SyncSetupException error) => error.message,
          'message',
          'No journal on that server uses this recovery phrase.',
        ),
      ),
    );
    expect(
      await readSyncState(freshDatabase, SyncStateKeys.syncEnabled),
      isNull,
    );
  });
}
