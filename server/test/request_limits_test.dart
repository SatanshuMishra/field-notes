import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relay_server/relay_server.dart';
import 'package:relay_server/src/accounts.dart';
import 'package:relay_server/src/body_slots.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

const int smallLimit = 64 * 1024;
const int largeLimit = 1024 * 1024;
const int pushLimit = 8 * 1024 * 1024;
const int openerLimit = 4096;
const int changeLimit = 500;
const int largeBody = 100 * 1024;

int openersIn(List<int> body) =>
    body.where((int byte) => byte == 0x7b || byte == 0x5b).length;

Future<void> until(bool Function() condition) async {
  while (!condition()) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late RelayHarness harness;

  setUp(() async {
    harness = await RelayHarness.start();
  });

  tearDown(() async {
    await harness.dispose();
  });

  List<int> padded(SyncMessage message, int totalBytes) {
    String encode(int padding) => jsonEncode(<String, Object?>{
      ...message.toJson(),
      'padding': 'x' * padding,
    });
    final int bare = utf8.encode(encode(0)).length;
    final List<int> body = utf8.encode(encode(totalBytes - bare));
    expect(body, hasLength(totalBytes));
    return body;
  }

  Future<http.Response> sendBody(
    SyncRoute route,
    List<int> body, {
    Map<String, Object> parameters = const <String, Object>{},
    AuthCredential? credential,
  }) => harness.send(
    route,
    parameters: parameters,
    credential: credential,
    bytes: body,
    headers: const <String, String>{'content-type': 'application/json'},
  );

  Future<http.Response> sendStreamed(SyncRoute route, List<int> body) async {
    final http.StreamedRequest request =
        http.StreamedRequest(route.method, harness.uri(route))
          ..headers.addAll(<String, String>{
            SyncHeaders.protocol: '$syncProtocolVersion',
            'content-type': 'application/json',
          });
    request.sink
      ..add(body)
      ..close();
    return http.Response.fromStream(await harness.client.send(request));
  }

  void expectTooLarge(http.Response response, String route) {
    expect(response.statusCode, HttpStatus.badRequest, reason: route);
    expect(errorOf(response).code, SyncErrorCode.badRequest, reason: route);
  }

  int count(String sql, [List<Object?> parameters = const <Object?>[]]) =>
      harness.database.count(sql, parameters);

  test('routes open without a session take bodies up to 64 KiB', () async {
    final TestAccount account = await harness.enrol();
    final TestDevice mac = account.firstDevice;

    final CreatedInvite invite = harness.createInvite('Second journal');
    final TestKeys certifying = harness.signKeys();
    final InviteRedeemRequest redeem = harness.redeemRequest(
      invite.code,
      certifyingKeys: certifying,
      device: harness.newDevice(certifying),
      recoverySignKeys: harness.signKeys(),
      recoveryBoxPublicKey: harness.sodium.crypto.box.keyPair().publicKey,
      recoveryEpochOneCopy: harness.randomOpaque(72),
    );
    expectTooLarge(
      await sendBody(SyncRoutes.redeemInvite, padded(redeem, smallLimit + 1)),
      'redeem',
    );
    expect(count('SELECT count(*) FROM accounts'), 1);
    expect(
      (await sendBody(
        SyncRoutes.redeemInvite,
        padded(redeem, smallLimit),
      )).statusCode,
      HttpStatus.ok,
    );
    expect(count('SELECT count(*) FROM accounts'), 2);

    final ChallengeRequest challengeRequest = ChallengeRequest(
      deviceId: mac.deviceId,
    );
    expectTooLarge(
      await sendBody(
        SyncRoutes.sessionChallenge,
        padded(challengeRequest, smallLimit + 1),
      ),
      'session challenge',
    );
    final http.Response challenged = await sendBody(
      SyncRoutes.sessionChallenge,
      padded(challengeRequest, smallLimit),
    );
    expect(challenged.statusCode, HttpStatus.ok);
    final SessionRequest sessionRequest = harness.sessionRequest(
      mac,
      ChallengeResponse.fromJson(decodeJsonObject(challenged.body)),
    );
    expectTooLarge(
      await sendBody(
        SyncRoutes.session,
        padded(sessionRequest, smallLimit + 1),
      ),
      'session',
    );
    expect(
      (await sendBody(
        SyncRoutes.session,
        padded(sessionRequest, smallLimit),
      )).statusCode,
      HttpStatus.ok,
    );

    final RestoreChallengeRequest restoreChallengeRequest =
        RestoreChallengeRequest(
          recoverySignPublicKey: account.recoverySignKeys.publicKey,
        );
    expectTooLarge(
      await sendBody(
        SyncRoutes.restoreChallenge,
        padded(restoreChallengeRequest, smallLimit + 1),
      ),
      'restore challenge',
    );
    final http.Response restoreChallenged = await sendBody(
      SyncRoutes.restoreChallenge,
      padded(restoreChallengeRequest, smallLimit),
    );
    expect(restoreChallenged.statusCode, HttpStatus.ok);
    final ChallengeResponse recovery = ChallengeResponse.fromJson(
      decodeJsonObject(restoreChallenged.body),
    );
    final RestoreRequest restoreRequest = RestoreRequest(
      challengeId: recovery.challengeId,
      signature: harness.sign(
        account.recoverySignKeys,
        restoreChallengeBytes(
          challengeId: recovery.challengeId,
          nonce: recovery.nonce,
          recoverySignPublicKey: account.recoverySignKeys.publicKey,
        ),
      ),
    );
    expectTooLarge(
      await sendBody(
        SyncRoutes.restore,
        padded(restoreRequest, smallLimit + 1),
      ),
      'restore',
    );
    final http.Response restored = await sendBody(
      SyncRoutes.restore,
      padded(restoreRequest, smallLimit),
    );
    expect(restored.statusCode, HttpStatus.ok);
    final TestDevice restoredDevice = harness.newDevice(account.certifyingKeys);
    final RestoreRegisterRequest register = RestoreRegisterRequest(
      restoreToken: RestoreResponse.fromJson(decodeJsonObject(restored.body))
          .restoreToken,
      device: restoredDevice.registration,
    );
    expectTooLarge(
      await sendBody(
        SyncRoutes.registerRestoredDevice,
        padded(register, smallLimit + 1),
      ),
      'restore register',
    );
    expect(
      count('SELECT count(*) FROM devices WHERE id = ?', <Object?>[
        restoredDevice.deviceId,
      ]),
      0,
    );
    expect(
      (await sendBody(
        SyncRoutes.registerRestoredDevice,
        padded(register, smallLimit),
      )).statusCode,
      HttpStatus.noContent,
    );
  });

  test(
    'pairing mailboxes and device removal take bodies up to 64 KiB',
    () async {
      final TestAccount account = await harness.enrol();
      final TestDevice mac = account.firstDevice;
      final TestDevice phone = harness.addDevice(account);
      final SignedIn macIn = await harness.signIn(mac);
      final String mailboxId = newSyncId();
      final String token = encodeBase64Url(harness.randomOpaque(16));
      final Map<String, Object> mailbox = <String, Object>{
        SyncRoutes.mailboxIdParameter: mailboxId,
      };

      final PairingOpenRequest open = PairingOpenRequest(
        mailboxId: mailboxId,
        tokenHash: mailboxTokenHash(token),
      );
      expectTooLarge(
        await sendBody(
          SyncRoutes.openPairing,
          padded(open, smallLimit + 1),
          credential: macIn.session,
        ),
        'open pairing',
      );
      expect(count('SELECT count(*) FROM mailboxes'), 0);
      expect(
        (await sendBody(
          SyncRoutes.openPairing,
          padded(open, smallLimit),
          credential: macIn.session,
        )).statusCode,
        HttpStatus.ok,
      );

      final AuthCredential mailboxCredential = AuthCredential(
        AuthScheme.mailbox,
        token,
      );
      final PairingJoinRequest join = PairingJoinRequest(
        device: harness.newDevice(account.certifyingKeys).registration,
        authenticator: harness.randomOpaque(32),
      );
      expectTooLarge(
        await sendBody(
          SyncRoutes.joinPairing,
          padded(join, smallLimit + 1),
          parameters: mailbox,
          credential: mailboxCredential,
        ),
        'join pairing',
      );
      expect(
        (await sendBody(
          SyncRoutes.joinPairing,
          padded(join, smallLimit),
          parameters: mailbox,
          credential: mailboxCredential,
        )).statusCode,
        HttpStatus.ok,
      );

      final DeviceRemoveRequest removal = DeviceRemoveRequest(
        rotation: harness.rotation(
          signer: mac,
          epoch: 2,
          recipients: <String>[
            mac.recipient,
            EpochKeyDelivery.recoveryRecipient,
          ],
        ),
      );
      final Map<String, Object> target = <String, Object>{
        SyncRoutes.deviceIdParameter: phone.deviceId,
      };
      expectTooLarge(
        await sendBody(
          SyncRoutes.removeDevice,
          padded(removal, smallLimit + 1),
          parameters: target,
          credential: macIn.session,
        ),
        'remove device',
      );
      expect(
        count(
          'SELECT count(*) FROM devices WHERE id = ? AND status = ?',
          <Object?>[phone.deviceId, 'active'],
        ),
        1,
      );
      expect(
        (await sendBody(
          SyncRoutes.removeDevice,
          padded(removal, smallLimit),
          parameters: target,
          credential: macIn.session,
        )).statusCode,
        HttpStatus.noContent,
      );
    },
  );

  test(
    'a streamed body over 64 KiB is refused without a declared length',
    () async {
      final TestAccount account = await harness.enrol();
      final ChallengeRequest request = ChallengeRequest(
        deviceId: account.firstDevice.deviceId,
      );
      final int before = count('SELECT count(*) FROM challenges');

      expectTooLarge(
        await sendStreamed(
          SyncRoutes.sessionChallenge,
          padded(request, smallLimit + 1),
        ),
        'streamed challenge',
      );
      expect(count('SELECT count(*) FROM challenges'), before);

      final http.Response accepted = await sendStreamed(
        SyncRoutes.sessionChallenge,
        padded(request, smallLimit),
      );
      expect(accepted.statusCode, HttpStatus.ok);
      expect(count('SELECT count(*) FROM challenges'), before + 1);
    },
  );

  test('pairing completion and blob reports take bodies up to 1 MiB', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn macIn = await harness.signIn(account.firstDevice);
    final String mailboxId = newSyncId();
    final String token = encodeBase64Url(harness.randomOpaque(16));
    final Map<String, Object> mailbox = <String, Object>{
      SyncRoutes.mailboxIdParameter: mailboxId,
    };
    final TestDevice newcomer = harness.newDevice(account.certifyingKeys);
    expect(
      (await harness.send(
        SyncRoutes.openPairing,
        credential: macIn.session,
        body: PairingOpenRequest(
          mailboxId: mailboxId,
          tokenHash: mailboxTokenHash(token),
        ),
      )).statusCode,
      HttpStatus.ok,
    );
    expect(
      (await harness.send(
        SyncRoutes.joinPairing,
        parameters: mailbox,
        credential: AuthCredential(AuthScheme.mailbox, token),
        body: PairingJoinRequest(
          device: newcomer.registration,
          authenticator: harness.randomOpaque(32),
        ),
      )).statusCode,
      HttpStatus.ok,
    );
    final PairingCompleteRequest completion = PairingCompleteRequest(
      device: newcomer.registration,
      keyBundle: harness.randomOpaque(64),
    );

    expectTooLarge(
      await sendBody(
        SyncRoutes.completePairing,
        padded(completion, largeLimit + 1),
        parameters: mailbox,
        credential: macIn.session,
      ),
      'complete pairing',
    );
    expect(
      count('SELECT count(*) FROM devices WHERE id = ?', <Object?>[
        newcomer.deviceId,
      ]),
      0,
    );
    expect(
      (await sendBody(
        SyncRoutes.completePairing,
        padded(completion, largeLimit),
        parameters: mailbox,
        credential: macIn.session,
      )).statusCode,
      HttpStatus.ok,
    );
    expect(
      count('SELECT count(*) FROM devices WHERE id = ?', <Object?>[
        newcomer.deviceId,
      ]),
      1,
    );

    final String name = harness.blobName();
    await harness.uploadBlob(macIn.session, name, harness.randomOpaque(1500));
    Object? unusedSince() => harness.database.selectOne(
      'SELECT unused_since FROM blobs WHERE name = ?',
      <Object?>[name],
    )!['unused_since'];
    final BlobNamesRequest names = BlobNamesRequest(names: <String>[name]);

    expectTooLarge(
      await sendBody(
        SyncRoutes.reportUnusedBlobs,
        padded(names, largeLimit + 1),
        credential: macIn.session,
      ),
      'unused report',
    );
    expect(unusedSince(), isNull);
    expect(
      (await sendBody(
        SyncRoutes.reportUnusedBlobs,
        padded(names, largeLimit),
        credential: macIn.session,
      )).statusCode,
      HttpStatus.noContent,
    );
    expect(unusedSince(), isNotNull);

    expectTooLarge(
      await sendBody(
        SyncRoutes.reportReferencedBlobs,
        padded(names, largeLimit + 1),
        credential: macIn.session,
      ),
      'referenced report',
    );
    expect(unusedSince(), isNotNull);
    expect(
      (await sendBody(
        SyncRoutes.reportReferencedBlobs,
        padded(names, largeLimit),
        credential: macIn.session,
      )).statusCode,
      HttpStatus.ok,
    );
    expect(unusedSince(), isNull);
  });

  test('a push takes a body up to 8 MiB', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn macIn = await harness.signIn(account.firstDevice);
    final PushRequest push = PushRequest(
      changes: <RecordPush>[harness.record('note-1')],
    );

    expectTooLarge(
      await sendBody(
        SyncRoutes.pushRecords,
        padded(push, pushLimit + 1),
        credential: macIn.session,
      ),
      'push',
    );
    expect(count('SELECT count(*) FROM records'), 0);

    final http.Response accepted = await sendBody(
      SyncRoutes.pushRecords,
      padded(push, pushLimit),
      credential: macIn.session,
    );
    expect(accepted.statusCode, HttpStatus.ok);
    expect(
      PushResponse.fromJson(decodeJsonObject(accepted.body))
          .results
          .single
          .status,
      PushStatus.accepted,
    );
    expect(count('SELECT count(*) FROM records'), 1);
  });

  test(
    'the pairing join checks the mailbox token before reading the body',
    () async {
      final TestAccount account = await harness.enrol();
      final SignedIn macIn = await harness.signIn(account.firstDevice);
      final String mailboxId = newSyncId();
      final String token = encodeBase64Url(harness.randomOpaque(16));
      final Map<String, Object> mailbox = <String, Object>{
        SyncRoutes.mailboxIdParameter: mailboxId,
      };
      expect(
        (await harness.send(
          SyncRoutes.openPairing,
          credential: macIn.session,
          body: PairingOpenRequest(
            mailboxId: mailboxId,
            tokenHash: mailboxTokenHash(token),
          ),
        )).statusCode,
        HttpStatus.ok,
      );
      final List<int> garbage = utf8.encode('{' * (smallLimit + 1));

      final http.Response wrongToken = await sendBody(
        SyncRoutes.joinPairing,
        garbage,
        parameters: mailbox,
        credential: AuthCredential(
          AuthScheme.mailbox,
          encodeBase64Url(harness.randomOpaque(16)),
        ),
      );
      final http.Response rightToken = await sendBody(
        SyncRoutes.joinPairing,
        garbage,
        parameters: mailbox,
        credential: AuthCredential(AuthScheme.mailbox, token),
      );

      expect(wrongToken.statusCode, HttpStatus.unauthorized);
      expect(errorOf(wrongToken).code, SyncErrorCode.unauthorized);
      expectTooLarge(rightToken, 'join with the right token');
      expect(
        harness.database.selectOne(
          'SELECT status FROM mailboxes WHERE id = ?',
          <Object?>[mailboxId],
        )!['status'],
        PairingStatus.open.wireName,
      );
    },
  );

  List<int> withOpeners(SyncMessage message, int openers) {
    List<int> encode(int objects) => utf8.encode(
      jsonEncode(<String, Object?>{
        ...message.toJson(),
        'padding': <Object>[
          for (int index = 0; index < objects; index++) <String, Object>{},
        ],
      }),
    );
    final List<int> body = encode(openers - openersIn(encode(0)));
    expect(openersIn(body), openers);
    return body;
  }

  ({http.StreamedRequest request, Future<http.StreamedResponse> response})
  openPush(RelayHarness relay, SignedIn who, List<int> body) {
    final http.StreamedRequest request =
        http.StreamedRequest(
            SyncRoutes.pushRecords.method,
            relay.uri(SyncRoutes.pushRecords),
          )
          ..contentLength = body.length
          ..headers.addAll(<String, String>{
            SyncHeaders.protocol: '$syncProtocolVersion',
            SyncHeaders.authorization: who.session.authorization,
            'content-type': 'application/json',
          });
    return (request: request, response: relay.client.send(request));
  }

  Future<http.Response> pushBody(
    RelayHarness relay,
    SignedIn who,
    List<int> body,
  ) => relay.send(
    SyncRoutes.pushRecords,
    credential: who.session,
    bytes: body,
    headers: const <String, String>{'content-type': 'application/json'},
  );

  test(
    'a JSON body with too many objects is refused before decoding',
    () async {
      final TestAccount account = await harness.enrol();
      final ChallengeRequest request = ChallengeRequest(
        deviceId: account.firstDevice.deviceId,
      );
      final int before = count('SELECT count(*) FROM challenges');

      expectTooLarge(
        await sendBody(
          SyncRoutes.sessionChallenge,
          withOpeners(request, openerLimit + 1),
        ),
        'too many objects',
      );
      expect(count('SELECT count(*) FROM challenges'), before);

      final http.Response accepted = await sendBody(
        SyncRoutes.sessionChallenge,
        withOpeners(request, openerLimit),
      );
      expect(accepted.statusCode, HttpStatus.ok);
      expect(count('SELECT count(*) FROM challenges'), before + 1);
    },
  );

  test('a push over the change limit is refused', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn macIn = await harness.signIn(account.firstDevice);
    List<RecordPush> changes(int total) => <RecordPush>[
      for (int index = 0; index < total; index++) harness.record('note-$index'),
    ];

    expectTooLarge(
      await harness.send(
        SyncRoutes.pushRecords,
        credential: macIn.session,
        body: PushRequest(changes: changes(changeLimit + 1)),
      ),
      'a push of 501 changes',
    );
    expect(count('SELECT count(*) FROM records'), 0);

    final PushResponse accepted = await harness.push(
      macIn.session,
      changes(changeLimit),
    );
    expect(accepted.results, hasLength(changeLimit));
    expect(count('SELECT count(*) FROM records'), changeLimit);
  });

  test("large bodies beyond the relay's slots wait for one", () async {
    final RelayHarness tight = await RelayHarness.start(largeBodySlots: 1);
    addTearDown(tight.dispose);
    final TestAccount account = await tight.enrol();
    final SignedIn macIn = await tight.signIn(account.firstDevice);
    final List<int> first = padded(
      PushRequest(changes: <RecordPush>[tight.record('first')]),
      largeBody,
    );
    final List<int> second = padded(
      PushRequest(changes: <RecordPush>[tight.record('second')]),
      largeBody,
    );
    final (
      :http.StreamedRequest request,
      :Future<http.StreamedResponse> response,
    ) = openPush(
      tight,
      macIn,
      first,
    );
    request.sink.add(first.sublist(0, largeBody ~/ 2));
    await until(() => tight.app.largeBodies.active == 1);

    bool secondAnswered = false;
    final Future<http.Response> waiting = pushBody(
      tight,
      macIn,
      second,
    ).whenComplete(() => secondAnswered = true);
    await until(() => tight.app.largeBodies.waiting == 1);

    expect(secondAnswered, isFalse);
    expect(tight.database.count('SELECT count(*) FROM records'), 0);

    request.sink
      ..add(first.sublist(largeBody ~/ 2))
      ..close();
    final http.Response firstAnswer = await http.Response.fromStream(
      await response,
    );
    final http.Response secondAnswer = await waiting;

    expect(firstAnswer.statusCode, HttpStatus.ok);
    expect(secondAnswer.statusCode, HttpStatus.ok);
    expect(tight.database.count('SELECT count(*) FROM records'), 2);
    expect(tight.app.largeBodies.active, 0);
    expect(tight.app.largeBodies.waiting, 0);
  });

  test('a large body that waits too long for a slot gets 429', () async {
    final RelayHarness tight = await RelayHarness.start(
      largeBodySlots: 1,
      largeBodyWait: const Duration(milliseconds: 200),
    );
    addTearDown(tight.dispose);
    final TestAccount account = await tight.enrol();
    final SignedIn macIn = await tight.signIn(account.firstDevice);
    final List<int> first = padded(
      PushRequest(changes: <RecordPush>[tight.record('first')]),
      largeBody,
    );
    final (
      :http.StreamedRequest request,
      :Future<http.StreamedResponse> response,
    ) = openPush(
      tight,
      macIn,
      first,
    );
    request.sink.add(first.sublist(0, largeBody ~/ 2));
    await until(() => tight.app.largeBodies.active == 1);

    final http.Response refused = await pushBody(
      tight,
      macIn,
      padded(
        PushRequest(changes: <RecordPush>[tight.record('second')]),
        largeBody,
      ),
    );

    expect(refused.statusCode, HttpStatus.tooManyRequests);
    expect(errorOf(refused).code, SyncErrorCode.tooManyRequests);
    expect(refused.headers['retry-after'], '1');
    expect(tight.app.largeBodies.waiting, 0);
    request.sink
      ..add(first.sublist(largeBody ~/ 2))
      ..close();
    expect(
      (await http.Response.fromStream(await response)).statusCode,
      HttpStatus.ok,
    );
    expect(tight.database.count('SELECT count(*) FROM records'), 1);
  });

  test('one account holds at most its share of the large body slots', () async {
    final LargeBodySlots slots = LargeBodySlots(total: 3, perAccount: 2);
    expect(await slots.acquire('a'), isTrue);
    expect(await slots.acquire('a'), isTrue);
    final Future<bool> third = slots.acquire('a');
    expect(slots.waiting, 1);

    expect(await slots.acquire('b'), isTrue);
    expect(slots.active, 3);
    slots.release('b');
    expect(slots.waiting, 1);
    expect(slots.active, 2);

    slots.release('a');
    expect(await third, isTrue);
    expect(slots.waiting, 0);
    expect(slots.active, 2);
  });

  test('the large body slots come from the environment', () {
    final RelayConfig defaults = RelayConfig.fromEnvironment(
      const <String, String>{},
    );
    expect(defaults.largeBodySlots, 8);
    expect(defaults.largeBodySlotsPerAccount, 4);

    final RelayConfig set = RelayConfig.fromEnvironment(const <String, String>{
      'RELAY_LARGE_BODY_SLOTS': '2',
      'RELAY_LARGE_BODY_SLOTS_PER_ACCOUNT': '1',
    });
    expect(set.largeBodySlots, 2);
    expect(set.largeBodySlotsPerAccount, 1);

    for (final String variable in <String>[
      'RELAY_LARGE_BODY_SLOTS',
      'RELAY_LARGE_BODY_SLOTS_PER_ACCOUNT',
    ]) {
      for (final String invalid in <String>['0', '-1', 'many', '1.5']) {
        expect(
          () =>
              RelayConfig.fromEnvironment(<String, String>{variable: invalid}),
          throwsA(isA<ConfigException>()),
          reason: '$variable=$invalid',
        );
      }
    }
  });
}
