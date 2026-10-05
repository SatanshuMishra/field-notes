import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:relay_server/relay_server.dart';
import 'package:relay_server/src/auth.dart';
import 'package:relay_server/src/live.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

const int replacedCode = 4002;
const int tooBigCode = 1009;
const int frameLimit = 4 * 1024;

void main() {
  late RelayHarness harness;

  setUp(() async {
    harness = await RelayHarness.start();
  });

  tearDown(() async {
    await harness.dispose();
  });

  int admin(List<String> arguments) => runAdminCommand(
    arguments,
    config: harness.config,
    out: StringBuffer(),
    err: StringBuffer(),
    clock: harness.clock,
  );

  Future<void> expectOpen(LiveClient client) async {
    client.send(const LivePing());
    expect(await client.next(), const LivePong());
  }

  Future<void> expectClosed(LiveClient client, int code) async {
    await client.closed;
    expect(client.closeCode, code);
  }

  test('a sweep closes the sockets of an account another process suspended or deleted', () async {
    final TestAccount account = await harness.enrol();
    final TestAccount other = await harness.enrol(note: 'Other journal');
    final SignedIn mac = await harness.signIn(account.firstDevice);
    final SignedIn otherIn = await harness.signIn(other.firstDevice);
    final LiveClient macLive = await harness.openLive(mac.token);
    final LiveClient otherLive = await harness.openLive(otherIn.token);

    expect(admin(<String>['account', 'suspend', account.accountId]), exitOk);
    await harness.tick();

    await expectClosed(macLive, liveRevokedCode);
    await expectOpen(otherLive);

    expect(admin(<String>['account', 'delete', other.accountId]), exitOk);
    await harness.tick();

    await expectClosed(otherLive, liveRevokedCode);
    expect(harness.app.live.openCount, 0);
  });

  test('marking the relay restored closes every open socket', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn mac = await harness.signIn(account.firstDevice);
    final LiveClient live = await harness.openLive(mac.token);
    await expectOpen(live);

    expect(admin(<String>['mark-restored']), exitOk);
    await harness.tick();

    await expectClosed(live, liveRevokedCode);
  });

  test('a socket whose session expires is closed as revoked', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn mac = await harness.signIn(account.firstDevice);
    harness.advance(sessionLifetime - const Duration(seconds: 60));
    final LiveClient live = await harness.openLive(mac.token);
    await expectOpen(live);

    harness.advance(const Duration(seconds: 60));
    await harness.tick();

    await expectClosed(live, liveRevokedCode);
  });

  test(
    'a device keeps at most four sockets and the oldest gives way',
    () async {
      final TestAccount account = await harness.enrol();
      final TestDevice phone = harness.addDevice(account);
      final SignedIn mac = await harness.signIn(account.firstDevice);
      final SignedIn phoneIn = await harness.signIn(phone);
      final List<LiveClient> macSockets = <LiveClient>[];
      for (int index = 0; index < 4; index++) {
        macSockets.add(await harness.openLive(mac.token));
      }
      final LiveClient phoneLive = await harness.openLive(phoneIn.token);
      for (final LiveClient socket in <LiveClient>[...macSockets, phoneLive]) {
        await expectOpen(socket);
      }

      final LiveClient fifth = await harness.openLive(mac.token);

      await expectClosed(macSockets.first, replacedCode);
      for (final LiveClient socket in <LiveClient>[
        ...macSockets.skip(1),
        fifth,
        phoneLive,
      ]) {
        await expectOpen(socket);
      }
      expect(harness.app.live.openCount, 5);
    },
  );

  test('a frame over 4 KiB closes the socket with 1009', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn mac = await harness.signIn(account.firstDevice);
    final WebSocket socket = await WebSocket.connect(
      SyncRoutes.live.uri(harness.baseUrl).replace(scheme: 'ws').toString(),
      headers: <String, Object>{
        SyncHeaders.protocol: '$syncProtocolVersion',
        SyncHeaders.authorization: mac.session.authorization,
      },
    );
    final StreamIterator<dynamic> replies = StreamIterator<dynamic>(socket);
    addTearDown(replies.cancel);

    socket.add('x' * frameLimit);
    socket.add(jsonEncode(const LivePing().toJson()));
    expect(await replies.moveNext(), isTrue);
    expect(
      LiveMessage.fromJson(decodeJsonObject(replies.current as String)),
      const LivePong(),
    );

    socket.add('x' * (frameLimit + 1));

    expect(await replies.moveNext(), isFalse);
    expect(socket.closeCode, tooBigCode);
    expect(harness.app.live.openCount, 0);
  });
}
