import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

void main() {
  test(
    'a challenge for an unknown device looks real and stores nothing',
    () async {
      final RelayHarness harness = await RelayHarness.start();
      addTearDown(harness.dispose);
      final TestAccount account = await harness.enrol();
      final TestDevice stranger = harness.newDevice(account.certifyingKeys);
      int stored() => harness.database.count('SELECT count(*) FROM challenges');
      final int before = stored();

      final http.Response decoyResponse = await harness.send(
        SyncRoutes.sessionChallenge,
        body: ChallengeRequest(deviceId: stranger.deviceId),
      );
      final http.Response realResponse = await harness.send(
        SyncRoutes.sessionChallenge,
        body: ChallengeRequest(deviceId: account.firstDevice.deviceId),
      );

      expect(decoyResponse.statusCode, HttpStatus.ok);
      expect(realResponse.statusCode, HttpStatus.ok);
      expect(
        decodeJsonObject(decoyResponse.body).keys,
        unorderedEquals(decodeJsonObject(realResponse.body).keys),
      );
      final ChallengeResponse decoy = ChallengeResponse.fromJson(
        decodeJsonObject(decoyResponse.body),
      );
      final ChallengeResponse real = ChallengeResponse.fromJson(
        decodeJsonObject(realResponse.body),
      );
      expect(isSyncId(decoy.challengeId), isTrue);
      expect(
        decodeBase64Url(decoy.nonce),
        hasLength(decodeBase64Url(real.nonce).length),
      );
      expect(decoy.expiresAt, real.expiresAt);
      expect(stored(), before + 1);
      final http.Response signedDecoy = await harness.send(
        SyncRoutes.session,
        body: harness.sessionRequest(stranger, decoy),
      );
      expect(signedDecoy.statusCode, HttpStatus.unauthorized);
      expect(errorOf(signedDecoy).code, SyncErrorCode.unauthorized);
    },
  );

  test('a removed device is still told it was removed', () async {
    final RelayHarness harness = await RelayHarness.start();
    addTearDown(harness.dispose);
    final TestAccount account = await harness.enrol();
    final TestDevice mac = account.firstDevice;
    final TestDevice phone = harness.addDevice(account);
    final SignedIn macIn = await harness.signIn(mac);
    expect(
      (await harness.removeDevice(
        macIn,
        phone.deviceId,
        harness.rotation(
          signer: mac,
          epoch: 2,
          recipients: <String>[
            mac.recipient,
            EpochKeyDelivery.recoveryRecipient,
          ],
        ),
      )).statusCode,
      HttpStatus.noContent,
    );

    final http.Response challenge = await harness.send(
      SyncRoutes.sessionChallenge,
      body: ChallengeRequest(deviceId: phone.deviceId),
    );

    expect(challenge.statusCode, SyncErrorCode.deviceRemoved.httpStatus);
    expect(errorOf(challenge).code, SyncErrorCode.deviceRemoved);
  });
}
