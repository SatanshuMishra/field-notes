import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

const String clientAddress = '203.0.113.77';
const String otherAddress = '198.51.100.23';
const String addressHeader = 'CF-Connecting-IP';
const int burst = 60;
const int relayBurst = 600;

void main() {
  late RelayHarness harness;

  setUp(() async {
    harness = await RelayHarness.start();
  });

  tearDown(() async {
    await harness.dispose();
  });

  Future<http.Response> challengeFrom(String address, String deviceId) =>
      harness.send(
        SyncRoutes.sessionChallenge,
        body: ChallengeRequest(deviceId: deviceId),
        headers: <String, String>{addressHeader: address},
      );

  Future<void> exhaust(String address, String deviceId) async {
    for (int request = 1; request <= burst; request++) {
      final http.Response answered = await challengeFrom(address, deviceId);
      expect(answered.statusCode, HttpStatus.ok, reason: 'request $request');
    }
    final http.Response limited = await challengeFrom(address, deviceId);
    expect(limited.statusCode, HttpStatus.tooManyRequests);
    expect(errorOf(limited).code, SyncErrorCode.tooManyRequests);
  }

  test(
    'too many open requests from one address get 429 with Retry-After',
    () async {
      final TestAccount account = await harness.enrol();
      final String deviceId = account.firstDevice.deviceId;
      for (int request = 1; request <= burst; request++) {
        final http.Response answered = await challengeFrom(
          clientAddress,
          deviceId,
        );
        expect(answered.statusCode, HttpStatus.ok, reason: 'request $request');
      }

      final http.Response limited = await challengeFrom(
        clientAddress,
        deviceId,
      );

      expect(limited.statusCode, HttpStatus.tooManyRequests);
      expect(errorOf(limited).code, SyncErrorCode.tooManyRequests);
      expect(limited.headers['retry-after'], '1');

      harness.advance(const Duration(seconds: 1));
      final http.Response later = await challengeFrom(clientAddress, deviceId);

      expect(later.statusCode, HttpStatus.ok);
      expect(
        ChallengeResponse.fromJson(decodeJsonObject(later.body)).challengeId,
        isNotEmpty,
      );
      final http.Response again = await challengeFrom(clientAddress, deviceId);
      expect(again.statusCode, HttpStatus.tooManyRequests);
      expect(again.headers['retry-after'], '1');
    },
  );

  test('each address has its own limit', () async {
    final TestAccount account = await harness.enrol();
    final String deviceId = account.firstDevice.deviceId;
    await exhaust(clientAddress, deviceId);

    final http.Response other = await challengeFrom(otherAddress, deviceId);

    expect(other.statusCode, HttpStatus.ok);
    expect(
      (await challengeFrom(clientAddress, deviceId)).statusCode,
      HttpStatus.tooManyRequests,
    );
    expect(
      (await harness.challenge(account.firstDevice)).challengeId,
      isNotEmpty,
    );
  });

  test('signed-in routes are not rate limited', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn me = await harness.signIn(account.firstDevice);
    await exhaust(clientAddress, account.firstDevice.deviceId);

    for (int request = 1; request <= 200; request++) {
      final http.Response pulled = await harness.send(
        SyncRoutes.pullRecords,
        credential: me.session,
        query: const <String, String>{SyncRoutes.afterQuery: '0'},
        headers: const <String, String>{addressHeader: clientAddress},
      );
      expect(pulled.statusCode, HttpStatus.ok, reason: 'pull $request');
    }
    for (int request = 1; request <= burst + 10; request++) {
      final http.Response pushed = await harness.send(
        SyncRoutes.pushRecords,
        credential: me.pass,
        body: PushRequest(
          changes: <RecordPush>[harness.record('note-$request')],
        ),
        headers: const <String, String>{addressHeader: clientAddress},
      );
      expect(pushed.statusCode, HttpStatus.ok, reason: 'push $request');
    }
    expect(
      (await challengeFrom(
        clientAddress,
        account.firstDevice.deviceId,
      )).statusCode,
      HttpStatus.tooManyRequests,
    );
  });

  test('the client address never reaches the logs', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn me = await harness.signIn(account.firstDevice);
    harness.logLines.clear();

    await exhaust(clientAddress, account.firstDevice.deviceId);
    final http.Response pulled = await harness.send(
      SyncRoutes.pullRecords,
      credential: me.session,
      query: const <String, String>{SyncRoutes.afterQuery: '0'},
      headers: const <String, String>{addressHeader: clientAddress},
    );
    expect(pulled.statusCode, HttpStatus.ok);

    final List<Map<String, Object?>> lines = <Map<String, Object?>>[
      for (final String line in harness.logLines)
        jsonDecode(line) as Map<String, Object?>,
    ];
    expect(lines, hasLength(burst + 2));
    final List<Map<String, Object?>> limited = <Map<String, Object?>>[
      for (final Map<String, Object?> line in lines)
        if (line['status'] == HttpStatus.tooManyRequests) line,
    ];
    expect(limited, hasLength(1));
    expect(limited.single['route'], SyncRoutes.sessionChallenge.pattern);
    for (final String line in harness.logLines) {
      expect(line, isNot(contains(clientAddress)));
    }
    for (final FileSystemEntity entity in harness.root.listSync(
      recursive: true,
    )) {
      if (entity is File) {
        expect(
          latin1.decode(entity.readAsBytesSync()),
          isNot(contains(clientAddress)),
          reason: entity.path,
        );
      }
    }
  });

  test('addresses in one IPv6 /64 share a limit', () async {
    final TestAccount account = await harness.enrol();
    final String deviceId = account.firstDevice.deviceId;

    await exhaust('2001:db8:1:2::1', deviceId);

    expect(
      (await challengeFrom(
        '2001:db8:1:2:ffff:ffff:ffff:fffe',
        deviceId,
      )).statusCode,
      HttpStatus.tooManyRequests,
    );
    expect(
      (await challengeFrom('2001:db8:1:3::1', deviceId)).statusCode,
      HttpStatus.ok,
    );

    await exhaust('203.0.113.9', deviceId);

    expect(
      (await challengeFrom('::ffff:203.0.113.9', deviceId)).statusCode,
      HttpStatus.tooManyRequests,
    );
    expect(
      (await challengeFrom('203.0.113.10', deviceId)).statusCode,
      HttpStatus.ok,
    );
  });

  test('the relay-wide limit caps open requests from many addresses', () async {
    final String deviceId = newSyncId();
    for (int request = 1; request <= relayBurst; request++) {
      final http.Response answered = await challengeFrom(
        '10.${(request >> 16) & 0xff}.${(request >> 8) & 0xff}.${request & 0xff}',
        deviceId,
      );
      expect(answered.statusCode, HttpStatus.ok, reason: 'request $request');
    }

    final http.Response limited = await challengeFrom('192.0.2.1', deviceId);

    expect(limited.statusCode, HttpStatus.tooManyRequests);
    expect(errorOf(limited).code, SyncErrorCode.tooManyRequests);
    expect(limited.headers['retry-after'], '1');

    harness.advance(const Duration(seconds: 1));
    expect(
      (await challengeFrom('192.0.2.2', deviceId)).statusCode,
      HttpStatus.ok,
    );
  });

  test('signed-in pairing status polls are not rate limited', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn me = await harness.signIn(account.firstDevice);
    final String mailboxId = newSyncId();
    final String token = encodeBase64Url(harness.randomOpaque(16));
    expect(
      (await harness.send(
        SyncRoutes.openPairing,
        credential: me.session,
        body: PairingOpenRequest(
          mailboxId: mailboxId,
          tokenHash: mailboxTokenHash(token),
        ),
      )).statusCode,
      HttpStatus.ok,
    );
    Future<http.Response> poll(AuthCredential credential) => harness.send(
      SyncRoutes.pairingStatus,
      parameters: <String, Object>{SyncRoutes.mailboxIdParameter: mailboxId},
      credential: credential,
      headers: const <String, String>{addressHeader: clientAddress},
    );

    for (int request = 1; request <= burst + 10; request++) {
      expect(
        (await poll(me.session)).statusCode,
        HttpStatus.ok,
        reason: 'signed-in poll $request',
      );
    }

    final AuthCredential mailbox = AuthCredential(AuthScheme.mailbox, token);
    for (int request = 1; request <= burst; request++) {
      expect(
        (await poll(mailbox)).statusCode,
        HttpStatus.ok,
        reason: 'mailbox poll $request',
      );
    }
    final http.Response limited = await poll(mailbox);
    expect(limited.statusCode, HttpStatus.tooManyRequests);
    expect(errorOf(limited).code, SyncErrorCode.tooManyRequests);
  });
}
