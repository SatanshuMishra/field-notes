import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relay_server/relay_server.dart';
import 'package:relay_server/src/accounts.dart';
import 'package:relay_server/src/body_slots.dart';
import 'package:relay_server/src/request_body.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

const int smallLimit = 64 * 1024;
const int largeLimit = 1024 * 1024;
const int pushLimit = 8 * 1024 * 1024;
const int openerLimit = 4096;
const int changeLimit = 500;
const int largeBody = 100 * 1024;
const int waitersPerAccount = 8;
const Timeout pollingTimeout = Timeout(Duration(minutes: 2));
const Duration answerLimit = Duration(seconds: 10);
const Duration readLimit = Duration(seconds: 30);
const Duration paceWindow = Duration(seconds: 30);
const int paceFloor = 256 * 1024;
const Duration slotWait = Duration(seconds: 20);
const Duration closeLimit = Duration(seconds: 5);
const int inFlightLimit = 32;
const String addressHeader = 'CF-Connecting-IP';

int openersIn(List<int> body) =>
    body.where((int byte) => byte == 0x7b || byte == 0x5b).length;

Future<void> until(bool Function() condition) async {
  while (!condition()) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Future<bool> eventually(bool Function() condition) async {
  final Stopwatch watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > answerLimit) {
      return false;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return true;
}

typedef RawRequest = ({Socket socket, Future<String> answer});

void main() {
  late ManualTimers timers;
  late RelayHarness harness;

  setUp(() async {
    timers = ManualTimers();
    harness = await RelayHarness.start(startTimer: timers.start);
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
    final RelayHarness tight = await RelayHarness.start(
      largeBodySlots: 1,
      startTimer: ManualTimers().start,
    );
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
  }, timeout: pollingTimeout);

  test('a large body that waits too long for a slot gets 429', () async {
    final ManualTimers slotTimers = ManualTimers();
    final RelayHarness tight = await RelayHarness.start(
      largeBodySlots: 1,
      largeBodyWait: slotWait,
      startTimer: slotTimers.start,
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
    final Future<http.Response> waiting = pushBody(
      tight,
      macIn,
      padded(
        PushRequest(changes: <RecordPush>[tight.record('second')]),
        largeBody,
      ),
    );
    await until(() => tight.app.largeBodies.waiting == 1);
    final List<ManualTimer> waits = slotTimers.pending(slotWait);
    expect(waits, hasLength(1));

    waits.single.fire();
    final http.Response refused = await waiting.timeout(answerLimit);

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
  }, timeout: pollingTimeout);

  Future<RawRequest> openRaw(
    RelayHarness relay,
    SyncRoute route,
    List<int> body,
    int sent, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    final Uri target = relay.uri(route);
    final Socket socket = await Socket.connect(target.host, target.port);
    final List<int> answer = <int>[];
    final Completer<String> answered = Completer<String>();
    void finish() {
      if (!answered.isCompleted) {
        answered.complete(latin1.decode(answer));
      }
    }

    socket.done.ignore();
    socket.listen(
      answer.addAll,
      onDone: finish,
      onError: (Object _) => finish(),
      cancelOnError: true,
    );
    socket
      ..add(
        latin1.encode(
          '${route.method} ${target.path} HTTP/1.1\r\n'
          'Host: ${target.host}:${target.port}\r\n'
          'Connection: close\r\n'
          'Content-Length: ${body.length}\r\n'
          'content-type: application/json\r\n'
          '${SyncHeaders.protocol}: $syncProtocolVersion\r\n'
          '${<String>[for (final MapEntry<String, String> header in headers.entries) '${header.key}: ${header.value}\r\n'].join()}'
          '\r\n',
        ),
      )
      ..add(body.sublist(0, sent));
    await socket.flush();
    return (socket: socket, answer: answered.future);
  }

  Future<RawRequest> openRawPush(
    RelayHarness relay,
    SignedIn who,
    List<int> body,
    int sent,
  ) => openRaw(
    relay,
    SyncRoutes.pushRecords,
    body,
    sent,
    headers: <String, String>{
      SyncHeaders.authorization: who.session.authorization,
    },
  );

  test('a slow body loses its slot', () async {
    final ManualTimers slotTimers = ManualTimers();
    final RelayHarness tight = await RelayHarness.start(
      largeBodySlots: 1,
      largeBodyWait: slotWait,
      startTimer: slotTimers.start,
    );
    addTearDown(tight.dispose);
    final TestAccount account = await tight.enrol();
    final SignedIn macIn = await tight.signIn(account.firstDevice);
    final List<int> first = padded(
      PushRequest(changes: <RecordPush>[tight.record('first')]),
      largeBody,
    );
    final (:Socket socket, :Future<String> answer) = await openRawPush(
      tight,
      macIn,
      first,
      largeBody ~/ 2,
    );
    addTearDown(socket.destroy);
    await until(() => tight.app.largeBodies.active == 1);
    final Future<http.Response> waiting = pushBody(
      tight,
      macIn,
      padded(
        PushRequest(changes: <RecordPush>[tight.record('second')]),
        largeBody,
      ),
    );
    await until(() => tight.app.largeBodies.waiting == 1);
    final List<ManualTimer> deadlines = slotTimers.pending(paceWindow);
    expect(deadlines, hasLength(1));
    expect(deadlines.single.duration, const Duration(seconds: 30));

    deadlines.single.fire();

    final http.Response second = await waiting.timeout(answerLimit);
    expect(second.statusCode, HttpStatus.ok);
    final String slow = await answer.timeout(answerLimit);
    expect(slow, startsWith('HTTP/1.1 400'));
    expect(slow, contains(SyncErrorCode.badRequest.wireName));
    expect(
      tight.database
          .select('SELECT record_key FROM records')
          .map((Map<String, Object?> row) => row['record_key']),
      <String>['second'],
    );
    expect(tight.app.largeBodies.active, 0);
    expect(tight.app.largeBodies.waiting, 0);
  }, timeout: pollingTimeout);

  test('waiters beyond the per-account queue are refused at once', () async {
    final ManualTimers timers = ManualTimers();
    final RelayHarness tight = await RelayHarness.start(
      largeBodySlots: 1,
      startTimer: timers.start,
    );
    addTearDown(tight.dispose);
    final TestAccount account = await tight.enrol();
    final SignedIn macIn = await tight.signIn(account.firstDevice);
    List<int> body(String recordKey) => padded(
      PushRequest(changes: <RecordPush>[tight.record(recordKey)]),
      largeBody,
    );
    final List<int> first = body('holder');
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
    final List<Future<http.Response>> waiting = <Future<http.Response>>[];
    for (int waiter = 1; waiter <= waitersPerAccount; waiter++) {
      waiting.add(pushBody(tight, macIn, body('waiter-$waiter')));
      await until(() => tight.app.largeBodies.waiting == waiter);
    }

    final http.Response refused = await pushBody(
      tight,
      macIn,
      body('ninth'),
    ).timeout(answerLimit);

    expect(refused.statusCode, HttpStatus.tooManyRequests);
    expect(errorOf(refused).code, SyncErrorCode.tooManyRequests);
    expect(refused.headers['retry-after'], '1');
    expect(tight.app.largeBodies.waiting, waitersPerAccount);
    request.sink
      ..add(first.sublist(largeBody ~/ 2))
      ..close();
    expect(
      (await http.Response.fromStream(await response).timeout(answerLimit))
          .statusCode,
      HttpStatus.ok,
    );
    for (final Future<http.Response> waiter in waiting) {
      expect((await waiter.timeout(answerLimit)).statusCode, HttpStatus.ok);
    }
    expect(
      tight.database.count('SELECT count(*) FROM records'),
      waitersPerAccount + 1,
    );
    expect(
      tight.database.count(
        "SELECT count(*) FROM records WHERE record_key = 'ninth'",
      ),
      0,
    );
  }, timeout: pollingTimeout);

  test(
    'a large-route body without a declared length waits for a slot',
    () async {
      final ManualTimers timers = ManualTimers();
      final RelayHarness tight = await RelayHarness.start(
        largeBodySlots: 1,
        startTimer: timers.start,
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
      final http.StreamedRequest streamed =
          http.StreamedRequest(
              SyncRoutes.pushRecords.method,
              tight.uri(SyncRoutes.pushRecords),
            )
            ..headers.addAll(<String, String>{
              SyncHeaders.protocol: '$syncProtocolVersion',
              SyncHeaders.authorization: macIn.session.authorization,
              'content-type': 'application/json',
            });
      final Future<http.StreamedResponse> streamedResponse = tight.client.send(
        streamed,
      );
      streamed.sink
        ..add(
          utf8.encode(
            jsonEncode(
              PushRequest(changes: <RecordPush>[tight.record('streamed')])
                  .toJson(),
            ),
          ),
        )
        ..close();

      await until(() => tight.app.largeBodies.waiting == 1);
      expect(tight.database.count('SELECT count(*) FROM records'), 0);

      request.sink
        ..add(first.sublist(largeBody ~/ 2))
        ..close();
      expect(
        (await http.Response.fromStream(await response).timeout(answerLimit))
            .statusCode,
        HttpStatus.ok,
      );
      expect(
        (await http.Response.fromStream(await streamedResponse)
                .timeout(answerLimit))
            .statusCode,
        HttpStatus.ok,
      );
      expect(tight.database.count('SELECT count(*) FROM records'), 2);
    },
    timeout: pollingTimeout,
  );

  test('a freed slot goes to an account holding none', () async {
    final ManualTimers slotTimers = ManualTimers();
    final RelayHarness tight = await RelayHarness.start(
      largeBodySlots: 3,
      startTimer: slotTimers.start,
    );
    addTearDown(tight.dispose);
    final TestAccount firstAccount = await tight.enrol(note: 'First journal');
    final TestAccount secondAccount = await tight.enrol(note: 'Second journal');
    final TestAccount thirdAccount = await tight.enrol(note: 'Third journal');
    final SignedIn first = await tight.signIn(firstAccount.firstDevice);
    final SignedIn second = await tight.signIn(secondAccount.firstDevice);
    final SignedIn third = await tight.signIn(thirdAccount.firstDevice);
    List<int> body(String recordKey) => padded(
      PushRequest(changes: <RecordPush>[tight.record(recordKey)]),
      largeBody,
    );
    int stored(String recordKey) => tight.database.count(
      'SELECT count(*) FROM records WHERE record_key = ?',
      <Object?>[recordKey],
    );
    final List<({Socket socket, Future<String> answer, List<int> body})>
    holders = <({Socket socket, Future<String> answer, List<int> body})>[];
    for (final (SignedIn who, String recordKey) in <(SignedIn, String)>[
      (first, 'first-held'),
      (first, 'first-held-too'),
      (second, 'second-held'),
    ]) {
      final List<int> held = body(recordKey);
      final (:Socket socket, :Future<String> answer) = await openRawPush(
        tight,
        who,
        held,
        largeBody ~/ 2,
      );
      addTearDown(socket.destroy);
      holders.add((socket: socket, answer: answer, body: held));
      await until(() => tight.app.largeBodies.active == holders.length);
    }
    final List<Future<http.Response>> waiters = <Future<http.Response>>[];
    for (final (SignedIn who, String recordKey) in <(SignedIn, String)>[
      (first, 'first-waiting'),
      (second, 'second-waiting'),
    ]) {
      waiters.add(pushBody(tight, who, body(recordKey)));
      await until(() => tight.app.largeBodies.waiting == waiters.length);
    }
    final List<int> thirdBody = body('third-waiting');
    final (socket: Socket thirdSocket, answer: Future<String> thirdAnswer) =
        await openRawPush(tight, third, thirdBody, largeBody ~/ 2);
    addTearDown(thirdSocket.destroy);
    await until(() => tight.app.largeBodies.waiting == 3);

    holders.first.socket.add(holders.first.body.sublist(largeBody ~/ 2));
    expect(
      await holders.first.answer.timeout(answerLimit),
      startsWith('HTTP/1.1 200'),
    );

    expect(
      await eventually(
        () => tight.app.largeBodies.heldBy(thirdAccount.accountId) == 1,
      ),
      isTrue,
    );
    expect(tight.app.largeBodies.waiting, 2);
    expect(stored('first-waiting'), 0);
    expect(stored('second-waiting'), 0);

    thirdSocket.add(thirdBody.sublist(largeBody ~/ 2));
    expect(await thirdAnswer.timeout(answerLimit), startsWith('HTTP/1.1 200'));
    for (final ({Socket socket, Future<String> answer, List<int> body}) holder
        in holders.skip(1)) {
      holder.socket.add(holder.body.sublist(largeBody ~/ 2));
      expect(
        await holder.answer.timeout(answerLimit),
        startsWith('HTTP/1.1 200'),
      );
    }
    for (final Future<http.Response> waiter in waiters) {
      expect((await waiter.timeout(answerLimit)).statusCode, HttpStatus.ok);
    }
    expect(tight.database.count('SELECT count(*) FROM records'), 6);
    expect(tight.app.largeBodies.active, 0);
    expect(tight.app.largeBodies.waiting, 0);
  }, timeout: pollingTimeout);

  test('a small body that stalls is aborted', () async {
    final TestAccount account = await harness.enrol();
    final List<int> body = padded(
      ChallengeRequest(deviceId: account.firstDevice.deviceId),
      1000,
    );
    final int before = count('SELECT count(*) FROM challenges');
    final (:Socket socket, :Future<String> answer) = await openRaw(
      harness,
      SyncRoutes.sessionChallenge,
      body,
      10,
    );
    addTearDown(socket.destroy);
    expect(
      await eventually(() => timers.pending(readLimit).length == 1),
      isTrue,
    );

    timers.pending(readLimit).single.fire();

    final String aborted = await answer.timeout(answerLimit);
    expect(aborted, startsWith('HTTP/1.1 400'));
    expect(aborted, contains(SyncErrorCode.badRequest.wireName));
    expect(aborted.toLowerCase(), contains('connection: close'));
    expect(count('SELECT count(*) FROM challenges'), before);
    final List<ManualTimer> dropping = timers.pending(closeLimit);
    expect(dropping, hasLength(1));
    dropping.single.fire();
    expect(harness.app.addressesInFlight.count('127.0.0.1'), 0);
  }, timeout: pollingTimeout);

  test('a stalled drain is aborted', () async {
    final List<int> body = padded(
      PushRequest(changes: <RecordPush>[harness.record('refused')]),
      1000,
    );
    final (:Socket socket, :Future<String> answer) = await openRaw(
      harness,
      SyncRoutes.pushRecords,
      body,
      10,
      headers: <String, String>{
        SyncHeaders.authorization: const AuthCredential(
          AuthScheme.session,
          'junk',
        ).authorization,
      },
    );
    addTearDown(socket.destroy);
    expect(
      await eventually(() => timers.pending(readLimit).length == 1),
      isTrue,
    );

    timers.pending(readLimit).single.fire();

    final String aborted = await answer.timeout(answerLimit);
    expect(aborted, startsWith('HTTP/1.1 400'));
    expect(aborted, contains(SyncErrorCode.badRequest.wireName));
    expect(aborted.toLowerCase(), contains('connection: close'));
    expect(count('SELECT count(*) FROM records'), 0);
  }, timeout: pollingTimeout);

  test('requests in flight per device are capped', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn macIn = await harness.signIn(account.firstDevice);
    final String deviceId = account.firstDevice.deviceId;
    final List<({Socket socket, Future<String> answer, List<int> body})>
    stalled = <({Socket socket, Future<String> answer, List<int> body})>[];
    for (int index = 0; index < inFlightLimit; index++) {
      final List<int> body = padded(
        PushRequest(changes: <RecordPush>[harness.record('note-$index')]),
        1000,
      );
      final (:Socket socket, :Future<String> answer) = await openRawPush(
        harness,
        macIn,
        body,
        10,
      );
      addTearDown(socket.destroy);
      stalled.add((socket: socket, answer: answer, body: body));
    }
    expect(
      await eventually(
        () => harness.app.devicesInFlight.count(deviceId) == inFlightLimit,
      ),
      isTrue,
    );

    final http.Response refused = await harness.send(
      SyncRoutes.pullRecords,
      credential: macIn.session,
      query: const <String, String>{SyncRoutes.afterQuery: '0'},
    );

    expect(refused.statusCode, HttpStatus.tooManyRequests);
    expect(errorOf(refused).code, SyncErrorCode.tooManyRequests);
    expect(refused.headers['retry-after'], '1');
    expect(harness.app.devicesInFlight.count(deviceId), inFlightLimit);

    final ({Socket socket, Future<String> answer, List<int> body}) finished =
        stalled.first;
    finished.socket.add(finished.body.sublist(10));
    expect(
      await finished.answer.timeout(answerLimit),
      startsWith('HTTP/1.1 200'),
    );
    expect(
      await eventually(
        () => harness.app.devicesInFlight.count(deviceId) == inFlightLimit - 1,
      ),
      isTrue,
    );
    final PullResponse pulled = await harness.pull(macIn.session);
    expect(pulled.states.map((RecordState state) => state.recordKey), <String>[
      'note-0',
    ]);
  }, timeout: pollingTimeout);

  test('requests in flight per address are capped on open routes', () async {
    final TestAccount account = await harness.enrol();
    const String crowded = '203.0.113.50';
    final ChallengeRequest challenge = ChallengeRequest(
      deviceId: account.firstDevice.deviceId,
    );
    final List<int> body = padded(challenge, 1000);
    for (int index = 0; index < inFlightLimit; index++) {
      final (:Socket socket, answer: _) = await openRaw(
        harness,
        SyncRoutes.sessionChallenge,
        body,
        10,
        headers: const <String, String>{addressHeader: crowded},
      );
      addTearDown(socket.destroy);
    }
    expect(
      await eventually(
        () => harness.app.addressesInFlight.count(crowded) == inFlightLimit,
      ),
      isTrue,
    );

    final http.Response refused = await harness.send(
      SyncRoutes.sessionChallenge,
      body: challenge,
      headers: const <String, String>{addressHeader: crowded},
    );
    final http.Response elsewhere = await harness.send(
      SyncRoutes.sessionChallenge,
      body: challenge,
      headers: const <String, String>{addressHeader: '198.51.100.7'},
    );

    expect(refused.statusCode, HttpStatus.tooManyRequests);
    expect(errorOf(refused).code, SyncErrorCode.tooManyRequests);
    expect(refused.headers['retry-after'], '1');
    expect(elsewhere.statusCode, HttpStatus.ok);
  }, timeout: pollingTimeout);

  test('a body that keeps its pace is never aborted', () {
    DateTime at(int seconds) => harnessStart.add(Duration(seconds: seconds));
    final PaceWindow window = PaceWindow(harnessStart);
    expect(window.deadline, at(30));

    window.arrived(at(10), paceFloor ~/ 2);
    expect(window.deadline, at(30));
    window.arrived(at(29), paceFloor ~/ 2);
    expect(window.deadline, at(40));
    window.arrived(at(39), paceFloor);
    expect(window.deadline, at(69));

    int received = 2 * paceFloor;
    for (int second = 68; received < pushLimit; second += 29) {
      window.arrived(at(second), paceFloor);
      received += paceFloor;
      expect(window.deadline, at(second + 30), reason: 'at $second s');
    }
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
