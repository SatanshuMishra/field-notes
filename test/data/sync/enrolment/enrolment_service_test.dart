import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:field_notes/data/crypto/bip39_english.dart';
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

const String _cloudflarePage =
    '<!DOCTYPE html><html><head><title>Access denied | Rate limited</title>'
    '</head><body><h1>Error 1015</h1><p>You are being rate limited</p>'
    '</body></html>';

Future<String> _testName() async => 'Test MacBook';

void main() {
  late RelayFixture relay;
  late AppDatabase database;
  late MemorySecureValues secrets;
  late KeyStore keyStore;

  setUp(() async {
    relay = await RelayFixture.start();
    database = AppDatabase(NativeDatabase.memory());
    secrets = MemorySecureValues();
    keyStore = KeyStore(secrets);
  });

  tearDown(() async {
    await database.close();
    await relay.dispose();
  });

  EnrolmentService service({RelayClientFactory? clientFor}) => EnrolmentService(
    database: database,
    keyStore: keyStore,
    clientFor: clientFor ?? defaultRelayClient,
    deviceName: _testName,
    random: Random(7),
  );

  Future<void> expectSetupMessage(Future<Object?> attempt, String message) =>
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

  test(
    'an invite enrols the first device and sync waits for the phrase check',
    () async {
      final String invite = relay.createInvite('Owner');

      final PendingEnrolment pending = await service().start(
        relayUrl: relay.baseUrl,
        inviteCode: invite,
      );

      expect(pending.words, hasLength(12));
      expect(pending.words.every(bip39English.contains), isTrue);
      expect(pending.positions, hasLength(2));
      expect(pending.positions.toSet(), hasLength(2));
      expect(pending.positions.every((int position) => position >= 1), isTrue);
      expect(pending.positions.every((int position) => position <= 12), isTrue);

      final JournalKeys? journal = await keyStore.readJournalKeys();
      final DeviceKeys? device = await keyStore.readDeviceKeys();
      final RecoveryPublicKeys? recoveryPublic = await keyStore
          .readRecoveryPublicKeys();
      final String? accountId = await keyStore.readAccountId();
      expect(journal, isNotNull);
      expect(journal!.epochs, <int>[1]);
      expect(device, isNotNull);
      expect(await keyStore.readDeviceId(), device!.deviceId);
      expect(accountId, isNotNull);
      expect(
        await readSyncState(database, SyncStateKeys.relayUrl),
        '${relay.baseUrl}',
      );
      expect(await readSyncState(database, SyncStateKeys.syncEnabled), isNull);

      expect(relay.accountOf(device.deviceId), accountId);
      expect(relay.activeDevices(accountId!), 1);
      expect(relay.currentEpoch(accountId), 1);

      final RecoveryKeys recovery = RecoveryKeys.fromSeed(
        decodeRecoveryPhrase(pending.words.join(' ')),
      );
      expect(recoveryPublic!.boxPublicKey, recovery.boxKeyPair.publicKey);
      expect(recoveryPublic.signPublicKey, recovery.signKeyPair.publicKey);

      final RelayClient client = RelayClient(
        baseUrl: relay.baseUrl,
        device: device,
      );
      addTearDown(client.close);
      final EpochKeysResponse keys = await client.keys();
      expect(keys.currentEpoch, 1);
      expect(keys.devices, hasLength(1));
      expect(
        isCertifiedDevice(journal.certifyingPublicKey, keys.devices.single),
        isTrue,
      );
      expect(
        openDeviceName(
          keys.devices.single.encryptedName,
          device.deviceId,
          journal,
        ),
        'Test MacBook',
      );
      expect(
        verifyRecoveryCertificate(
          journal.certifyingPublicKey,
          recoveryBoxPublicKey: keys.recoveryBoxPublicKey,
          certificate: keys.recoveryBoxCertificate,
        ),
        isTrue,
      );
      expect(keys.recoveryBoxPublicKey, recovery.boxKeyPair.publicKey);

      final String first = pending.words[pending.positions.first - 1];
      final String second = pending.words[pending.positions.last - 1];
      final String wrong = bip39English.firstWhere(
        (String word) => word != first,
      );
      await expectLater(
        pending.confirm(<String>[wrong, second]),
        throwsA(
          isA<WrongRecoveryWord>()
              .having(
                (WrongRecoveryWord error) => error.positions,
                'positions',
                <int>[pending.positions.first],
              )
              .having(
                (WrongRecoveryWord error) => error.message,
                'message',
                "That word doesn't match. Check your phrase.",
              ),
        ),
      );
      expect(await readSyncState(database, SyncStateKeys.syncEnabled), isNull);

      await pending.confirm(<String>[' ${first.toUpperCase()} ', second]);

      expect(await readSyncState(database, SyncStateKeys.syncEnabled), 'true');
    },
  );

  test('a used, expired or unknown invite says why', () async {
    final String invite = relay.createInvite('Owner');
    await service().start(relayUrl: relay.baseUrl, inviteCode: invite);

    await expectSetupMessage(
      service().start(relayUrl: relay.baseUrl, inviteCode: invite),
      'This invite has already been used.',
    );
    await expectSetupMessage(
      service().start(relayUrl: relay.baseUrl, inviteCode: 'AAAA-BBBB-CCCC'),
      "That invite code didn't work. Check it and try again.",
    );
    final String stale = relay.createInvite('Friend');
    relay.advance(const Duration(days: 8));
    await expectSetupMessage(
      service().start(relayUrl: relay.baseUrl, inviteCode: stale),
      'This invite has expired.',
    );
  });

  test('a rate-limited relay asks the user to wait', () async {
    int calls = 0;
    final MockClient limited = MockClient((http.Request request) async {
      calls++;
      return http.Response(
        jsonEncode(
          const ErrorResponse(
            code: SyncErrorCode.tooManyRequests,
            message: 'too_many_requests',
          ).toJson(),
        ),
        429,
        headers: <String, String>{
          'retry-after': '30',
          'content-type': 'application/json',
        },
      );
    });
    final MockClient cloudflare = MockClient(
      (http.Request request) async => http.Response(
        _cloudflarePage,
        429,
        headers: <String, String>{'content-type': 'text/html'},
      ),
    );
    final MockClient unreadable = MockClient(
      (http.Request request) async => http.Response(
        _cloudflarePage,
        429,
        headers: <String, String>{'retry-after': 'soon'},
      ),
    );
    final DeviceKeys device = DeviceKeys.generate();
    final JournalKeys journal = JournalKeys.generate();
    final RecoveryKeys recovery = RecoveryKeys.fromSeed(newRecoverySeed());
    final InviteRedeemRequest redeem = InviteRedeemRequest(
      inviteCode: 'AAAA-BBBB-CCCC-DDDD',
      device: device.registration(
        certificate: device.certifyWith(journal),
        encryptedName: sealDeviceName('Mac', device.deviceId, journal),
      ),
      recoverySignPublicKey: recovery.signKeyPair.publicKey,
      recoveryBoxPublicKey: recovery.boxKeyPair.publicKey,
      recoveryBoxCertificate: certifyRecoveryKey(
        journal,
        recovery.boxKeyPair.publicKey,
      ),
      recoveryEpochOneCopy: sealEpochOneCopy(
        journal.epochKey(1),
        recovery.secretKey,
      ),
    );
    final Uri relayUrl = Uri.parse('https://sync.example.test');

    await expectLater(
      RelayClient(baseUrl: relayUrl, client: limited).redeemInvite(redeem),
      throwsA(
        isA<RelayRateLimited>().having(
          (RelayRateLimited error) => error.retryAfter,
          'retryAfter',
          const Duration(seconds: 30),
        ),
      ),
    );
    expect(calls, 1);
    await expectLater(
      RelayClient(baseUrl: relayUrl, client: cloudflare).redeemInvite(redeem),
      throwsA(
        isA<RelayRateLimited>().having(
          (RelayRateLimited error) => error.retryAfter,
          'retryAfter',
          const Duration(seconds: 30),
        ),
      ),
    );
    await expectLater(
      RelayClient(baseUrl: relayUrl, client: unreadable).redeemInvite(redeem),
      throwsA(
        isA<RelayRateLimited>().having(
          (RelayRateLimited error) => error.retryAfter,
          'retryAfter',
          const Duration(seconds: 30),
        ),
      ),
    );

    RelayClient limitedClient(Uri url, DeviceKeys? device) =>
        RelayClient(baseUrl: url, device: device, client: limited);
    RelayClient cloudflareClient(Uri url, DeviceKeys? device) =>
        RelayClient(baseUrl: url, device: device, client: cloudflare);

    await expectSetupMessage(
      service(clientFor: limitedClient)
          .start(relayUrl: relayUrl, inviteCode: 'AAAA-BBBB-CCCC-DDDD'),
      'Too many tries. Wait a minute and try again.',
    );
    await expectSetupMessage(
      service(clientFor: cloudflareClient)
          .start(relayUrl: relayUrl, inviteCode: 'AAAA-BBBB-CCCC-DDDD'),
      'Too many tries. Wait a minute and try again.',
    );
    final String phrase = encodeRecoveryPhrase(newRecoverySeed());
    await expectSetupMessage(
      RestoreService(
        database: database,
        keyStore: keyStore,
        clientFor: limitedClient,
        deviceName: _testName,
      ).restore(relayUrl: relayUrl, phrase: phrase),
      'Too many tries. Wait a minute and try again.',
    );
    await expectSetupMessage(
      RestoreService(
        database: database,
        keyStore: keyStore,
        clientFor: cloudflareClient,
        deviceName: _testName,
      ).restore(relayUrl: relayUrl, phrase: phrase),
      'Too many tries. Wait a minute and try again.',
    );
    expect(secrets.snapshot, isEmpty);
    expect(await readSyncState(database, SyncStateKeys.relayUrl), isNull);
  });
}
