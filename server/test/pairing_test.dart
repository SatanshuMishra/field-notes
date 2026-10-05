import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:relay_server/src/pairing.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

void main() {
  late RelayHarness harness;

  setUp(() async {
    harness = await RelayHarness.start();
  });

  tearDown(() async {
    await harness.dispose();
  });

  String newToken() => encodeBase64Url(harness.randomOpaque(16));

  Map<String, Object> mailbox(String mailboxId) => <String, Object>{
    SyncRoutes.mailboxIdParameter: mailboxId,
  };

  Future<http.Response> openMailbox(
    SignedIn owner,
    String mailboxId,
    String token,
  ) => harness.send(
    SyncRoutes.openPairing,
    credential: owner.session,
    body: PairingOpenRequest(
      mailboxId: mailboxId,
      tokenHash: mailboxTokenHash(token),
    ),
  );

  Future<http.Response> join(
    String mailboxId,
    String token,
    TestDevice device,
  ) => harness.send(
    SyncRoutes.joinPairing,
    parameters: mailbox(mailboxId),
    credential: AuthCredential(AuthScheme.mailbox, token),
    body: PairingJoinRequest(
      device: device.registration,
      authenticator: harness.randomOpaque(32),
    ),
  );

  Future<http.Response> statusByToken(String mailboxId, String token) =>
      harness.send(
        SyncRoutes.pairingStatus,
        parameters: mailbox(mailboxId),
        credential: AuthCredential(AuthScheme.mailbox, token),
      );

  Future<http.Response> statusBySession(SignedIn owner, String mailboxId) =>
      harness.send(
        SyncRoutes.pairingStatus,
        parameters: mailbox(mailboxId),
        credential: owner.session,
      );

  Future<http.Response> complete(
    SignedIn owner,
    String mailboxId,
    TestDevice device,
    Uint8List bundle,
  ) => harness.send(
    SyncRoutes.completePairing,
    parameters: mailbox(mailboxId),
    credential: owner.session,
    body: PairingCompleteRequest(
      device: device.registration,
      keyBundle: bundle,
    ),
  );

  PairingStatusResponse pairingOf(http.Response response) =>
      PairingStatusResponse.fromJson(decodeJsonObject(response.body));

  EpochKeysResponse keysOf(http.Response response) =>
      EpochKeysResponse.fromJson(decodeJsonObject(response.body));

  test('a mailbox older than ten minutes is refused', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn owner = await harness.signIn(account.firstDevice);
    final String freshId = newSyncId();
    final String freshToken = newToken();
    final String staleId = newSyncId();
    final String staleToken = newToken();
    expect(
      (await openMailbox(owner, staleId, staleToken)).statusCode,
      HttpStatus.ok,
    );
    harness.advance(const Duration(minutes: 1));
    expect(
      pairingOf(await openMailbox(owner, freshId, freshToken)).status,
      PairingStatus.open,
    );
    final TestDevice newcomer = harness.newDevice(account.certifyingKeys);
    final Uint8List bundle = harness.randomOpaque(120);

    harness.advance(const Duration(minutes: 8));
    final http.Response wrongToken = await join(freshId, newToken(), newcomer);
    expect(wrongToken.statusCode, HttpStatus.unauthorized);
    expect(
      pairingOf(await join(freshId, freshToken, newcomer)).status,
      PairingStatus.joined,
    );
    final PairingStatusResponse seen = pairingOf(
      await statusBySession(owner, freshId),
    );
    expect(seen.status, PairingStatus.joined);
    expect(seen.join!.device, newcomer.registration);
    expect(
      pairingOf(await complete(owner, freshId, newcomer, bundle)).status,
      PairingStatus.complete,
    );
    final PairingStatusResponse finished = pairingOf(
      await statusByToken(freshId, freshToken),
    );
    expect(finished.status, PairingStatus.complete);
    expect(finished.accountId, account.accountId);
    expect(finished.keyBundle, bundle);
    expect(
      harness.database.count(
        'SELECT count(*) FROM devices WHERE id = ? AND account_id = ?',
        <Object?>[newcomer.deviceId, account.accountId],
      ),
      1,
    );

    harness.advance(const Duration(minutes: 1));
    expect(harness.now, harnessStart.add(mailboxLifetime));
    final TestDevice late = harness.newDevice(account.certifyingKeys);

    final List<http.Response> refused = <http.Response>[
      await join(staleId, staleToken, late),
      await statusByToken(staleId, staleToken),
      await statusBySession(owner, staleId),
      await complete(owner, staleId, late, bundle),
    ];

    for (final http.Response response in refused) {
      expect(response.statusCode, SyncErrorCode.pairingExpired.httpStatus);
      expect(errorOf(response).code, SyncErrorCode.pairingExpired);
    }
    expect(
      harness.database.count(
        'SELECT count(*) FROM devices WHERE id = ?',
        <Object?>[late.deviceId],
      ),
      0,
    );

    harness.advance(const Duration(minutes: 1));
    expect(
      errorOf(await statusByToken(freshId, freshToken)).code,
      SyncErrorCode.pairingExpired,
    );
  });

  test('each device receives only the epoch keys sealed to it', () async {
    final TestAccount account = await harness.enrol();
    final TestDevice mac = account.firstDevice;
    final TestDevice phone = harness.addDevice(account);
    final TestDevice tablet = harness.addDevice(account);
    final SignedIn macIn = await harness.signIn(mac);
    final SignedIn phoneIn = await harness.signIn(phone);
    final EpochRotation rotation = harness.rotation(
      signer: mac,
      epoch: 2,
      recipients: <String>[
        mac.recipient,
        phone.recipient,
        EpochKeyDelivery.recoveryRecipient,
      ],
    );
    expect(
      (await harness.removeDevice(macIn, tablet.deviceId, rotation)).statusCode,
      HttpStatus.noContent,
    );

    final http.Response macResponse = await harness.send(
      SyncRoutes.keys,
      credential: macIn.session,
    );
    final http.Response phoneResponse = await harness.send(
      SyncRoutes.keys,
      credential: phoneIn.session,
    );

    final EpochKeysResponse macKeys = keysOf(macResponse);
    final EpochKeysResponse phoneKeys = keysOf(phoneResponse);
    expect(macKeys.currentEpoch, 2);
    expect(macKeys.rotations.single.epoch, 2);
    expect(macKeys.rotations.single.signerDeviceId, mac.deviceId);
    expect(macKeys.rotations.single.deliveries, <EpochKeyDelivery>[
      rotation.deliveries[0],
    ]);
    expect(phoneKeys.rotations.single.deliveries, <EpochKeyDelivery>[
      rotation.deliveries[1],
    ]);
    expect(macKeys.recoveryBoxPublicKey, account.recoveryBoxPublicKey);
    expect(macKeys.recoveryBoxCertificate, account.recoveryBoxCertificate);
    expect(
      macKeys.devices.map((DeviceInfo device) => device.deviceId),
      unorderedEquals(<String>[mac.deviceId, phone.deviceId]),
    );
    for (final http.Response response in <http.Response>[
      macResponse,
      phoneResponse,
    ]) {
      expect(
        response.body,
        isNot(contains(encodeBase64Url(rotation.deliveries[2].sealed))),
      );
      expect(response.body, isNot(contains(tablet.recipient)));
    }
    expect(
      phoneResponse.body,
      isNot(contains(encodeBase64Url(rotation.deliveries[0].sealed))),
    );
  });

  test(
    'recovery-sealed keys are returned only to a verified restore',
    () async {
      final TestAccount account = await harness.enrol();
      final TestDevice mac = account.firstDevice;
      final TestDevice phone = harness.addDevice(account);
      final SignedIn macIn = await harness.signIn(mac);
      final EpochRotation rotation = harness.rotation(
        signer: mac,
        epoch: 2,
        recipients: <String>[mac.recipient, EpochKeyDelivery.recoveryRecipient],
      );
      expect(
        (await harness.removeDevice(
          macIn,
          phone.deviceId,
          rotation,
        )).statusCode,
        HttpStatus.noContent,
      );
      final EpochKeyDelivery recovery = rotation.deliveries.last;
      final List<String> material = <String>[
        encodeBase64Url(recovery.sealed),
        encodeBase64Url(account.recoveryEpochOneCopy),
      ];
      for (final SyncRoute route in <SyncRoute>[
        SyncRoutes.keys,
        SyncRoutes.devices,
        SyncRoutes.pullRecords,
      ]) {
        final http.Response ordinary = await harness.send(
          route,
          credential: macIn.session,
        );
        expect(ordinary.statusCode, HttpStatus.ok);
        for (final String secret in material) {
          expect(ordinary.body, isNot(contains(secret)));
        }
      }

      Future<ChallengeResponse> restoreChallenge() async {
        final http.Response response = await harness.send(
          SyncRoutes.restoreChallenge,
          body: RestoreChallengeRequest(
            recoverySignPublicKey: account.recoverySignKeys.publicKey,
          ),
        );
        expect(response.statusCode, HttpStatus.ok);
        return ChallengeResponse.fromJson(decodeJsonObject(response.body));
      }

      RestoreRequest restoreRequest(
        ChallengeResponse challenge,
        TestKeys keys,
      ) => RestoreRequest(
        challengeId: challenge.challengeId,
        signature: harness.sign(
          keys,
          restoreChallengeBytes(
            challengeId: challenge.challengeId,
            nonce: challenge.nonce,
            recoverySignPublicKey: account.recoverySignKeys.publicKey,
          ),
        ),
      );

      final http.Response unknown = await harness.send(
        SyncRoutes.restoreChallenge,
        body: RestoreChallengeRequest(
          recoverySignPublicKey: harness.signKeys().publicKey,
        ),
      );
      expect(unknown.statusCode, HttpStatus.notFound);

      final http.Response forged = await harness.send(
        SyncRoutes.restore,
        body: restoreRequest(await restoreChallenge(), harness.signKeys()),
      );
      expect(forged.statusCode, HttpStatus.unauthorized);
      for (final String secret in material) {
        expect(forged.body, isNot(contains(secret)));
      }

      final RestoreRequest valid = restoreRequest(
        await restoreChallenge(),
        account.recoverySignKeys,
      );
      final http.Response restored = await harness.send(
        SyncRoutes.restore,
        body: valid,
      );
      expect(restored.statusCode, HttpStatus.ok);
      final RestoreResponse restore = RestoreResponse.fromJson(
        decodeJsonObject(restored.body),
      );
      expect(restore.accountId, account.accountId);
      expect(restore.currentEpoch, 2);
      expect(restore.recoveryEpochOneCopy, account.recoveryEpochOneCopy);
      expect(restore.rotations.single.deliveries, <EpochKeyDelivery>[recovery]);
      expect(
        restore.devices.map((DeviceInfo device) => device.deviceId),
        <String>[mac.deviceId],
      );
      final http.Response replayed = await harness.send(
        SyncRoutes.restore,
        body: valid,
      );
      expect(replayed.statusCode, HttpStatus.unauthorized);
      expect(replayed.body, isNot(contains(material.first)));

      final TestDevice newcomer = harness.newDevice(account.certifyingKeys);
      final http.Response registered = await harness.send(
        SyncRoutes.registerRestoredDevice,
        body: RestoreRegisterRequest(
          restoreToken: restore.restoreToken,
          device: newcomer.registration,
        ),
      );
      final http.Response reused = await harness.send(
        SyncRoutes.registerRestoredDevice,
        body: RestoreRegisterRequest(
          restoreToken: restore.restoreToken,
          device: harness.newDevice(account.certifyingKeys).registration,
        ),
      );
      expect(registered.statusCode, HttpStatus.noContent);
      expect(reused.statusCode, HttpStatus.unauthorized);
      final SignedIn newcomerIn = await harness.signIn(newcomer);
      final EpochKeysResponse newcomerKeys = keysOf(
        await harness.send(SyncRoutes.keys, credential: newcomerIn.session),
      );
      expect(newcomerKeys.rotations.single.deliveries, isEmpty);
    },
  );
}
