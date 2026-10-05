import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relay_server/src/auth.dart';
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

  void expectRefused(http.Response response) {
    expect(response.statusCode, HttpStatus.unauthorized);
    expect(
      decodeJsonObject(response.body).keys,
      unorderedEquals(<String>[protocolVersionField, 'code', 'message']),
    );
    expect(errorOf(response).code, SyncErrorCode.unauthorized);
  }

  test('requests without a valid session are refused', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn signedIn = await harness.signIn(account.firstDevice);
    final PushResponse pushed = await harness.push(
      signedIn.session,
      <RecordPush>[harness.record('note-key-1')],
    );
    expect(pushed.results.single.status, PushStatus.accepted);
    const List<SyncRoute> reads = <SyncRoute>[
      SyncRoutes.pullRecords,
      SyncRoutes.keys,
      SyncRoutes.devices,
    ];

    for (final SyncRoute route in reads) {
      expectRefused(await harness.send(route));
      expectRefused(
        await harness.send(
          route,
          credential: const AuthCredential(AuthScheme.session, 'not-a-token'),
        ),
      );
      expectRefused(
        await harness.send(
          route,
          credential: AuthCredential(
            AuthScheme.session,
            '${account.firstDevice.deviceId}.forged',
          ),
        ),
      );
    }
    expectRefused(
      await harness.send(
        SyncRoutes.pushRecords,
        body: PushRequest(changes: <RecordPush>[harness.record('note-key-2')]),
      ),
    );

    harness.advance(sessionLifetime - const Duration(seconds: 1));
    expect(
      (await harness.send(
        SyncRoutes.pullRecords,
        credential: signedIn.session,
      )).statusCode,
      HttpStatus.ok,
    );
    harness.advance(const Duration(seconds: 1));

    for (final SyncRoute route in reads) {
      expectRefused(await harness.send(route, credential: signedIn.session));
    }
    await expectLater(
      harness.openLive(signedIn.token),
      throwsA(isA<WebSocketException>()),
    );
    expect(harness.database.count('SELECT count(*) FROM records'), 1);
  });

  test(
    'a signature over a stale or foreign challenge gets no session',
    () async {
      final TestAccount account = await harness.enrol();
      final TestDevice device = account.firstDevice;
      final TestDevice other = harness.addDevice(account);
      final TestAccount stranger = await harness.enrol();

      void expectNoSession(http.Response response) {
        expectRefused(response);
        expect(response.body, isNot(contains('token')));
      }

      final ChallengeResponse first = await harness.challenge(device);
      final SessionRequest signed = harness.sessionRequest(device, first);
      expect(
        (await harness.send(SyncRoutes.session, body: signed)).statusCode,
        HttpStatus.ok,
      );
      expectNoSession(await harness.send(SyncRoutes.session, body: signed));

      final ChallengeResponse stale = await harness.challenge(device);
      harness.advance(challengeLifetime);
      expectNoSession(
        await harness.send(
          SyncRoutes.session,
          body: harness.sessionRequest(device, stale),
        ),
      );

      final ChallengeResponse othersChallenge = await harness.challenge(other);
      expectNoSession(
        await harness.send(
          SyncRoutes.session,
          body: harness.sessionRequest(device, othersChallenge),
        ),
      );
      final ChallengeResponse strangersChallenge = await harness.challenge(
        stranger.firstDevice,
      );
      expectNoSession(
        await harness.send(
          SyncRoutes.session,
          body: harness.sessionRequest(device, strangersChallenge),
        ),
      );
      expectNoSession(
        await harness.send(
          SyncRoutes.session,
          body: harness.sessionRequest(
            other,
            othersChallenge,
            signer: device.signKeys,
          ),
        ),
      );

      final ChallengeResponse fresh = await harness.challenge(other);
      expect(
        (await harness.send(
          SyncRoutes.session,
          body: harness.sessionRequest(other, fresh),
        )).statusCode,
        HttpStatus.ok,
      );
      expect(
        harness.database.count(
          'SELECT count(*) FROM sessions WHERE kind = ?',
          <Object?>['session'],
        ),
        2,
      );
    },
  );

  test('a client on another protocol version is told to update', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn signedIn = await harness.signIn(account.firstDevice);

    final http.Response missing = await harness.send(
      SyncRoutes.pullRecords,
      credential: signedIn.session,
      protocol: false,
    );
    final http.Response newer = await harness.send(
      SyncRoutes.pullRecords,
      credential: signedIn.session,
      protocol: false,
      headers: <String, String>{
        SyncHeaders.protocol: '${syncProtocolVersion + 1}',
      },
    );
    final http.Response health = await harness.send(
      SyncRoutes.health,
      protocol: false,
    );

    for (final http.Response response in <http.Response>[missing, newer]) {
      expect(response.statusCode, SyncErrorCode.unsupportedProtocol.httpStatus);
      expect(errorOf(response).code, SyncErrorCode.unsupportedProtocol);
    }
    expect(health.statusCode, HttpStatus.ok);
  });
}
