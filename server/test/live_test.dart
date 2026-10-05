import 'package:relay_server/src/live.dart';
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

  Future<void> expectQuiet(LiveClient client) async {
    client.send(const LivePing());
    expect(await client.next(), const LivePong());
  }

  test("an accepted push nudges only the account's other devices", () async {
    final TestAccount account = await harness.enrol();
    final TestDevice phone = harness.addDevice(account);
    final TestDevice tablet = harness.addDevice(account);
    final TestAccount stranger = await harness.enrol(note: 'Stranger');
    final SignedIn mac = await harness.signIn(account.firstDevice);
    final SignedIn phoneIn = await harness.signIn(phone);
    final SignedIn tabletIn = await harness.signIn(tablet);
    final SignedIn strangerIn = await harness.signIn(stranger.firstDevice);
    final LiveClient macLive = await harness.openLive(mac.token);
    final LiveClient phoneLive = await harness.openLive(phoneIn.token);
    final LiveClient tabletLive = await harness.openLive(tabletIn.token);
    final LiveClient strangerLive = await harness.openLive(strangerIn.token);
    final RecordPush change = harness.record('note-1');

    final PushResponse pushed = await harness.push(mac.session, <RecordPush>[
      change,
    ]);

    expect(pushed.results.single.status, PushStatus.accepted);
    expect(await phoneLive.next(), const LiveNudge(latestSeq: 1));
    expect(await tabletLive.next(), const LiveNudge(latestSeq: 1));
    await expectQuiet(macLive);
    await expectQuiet(strangerLive);

    await harness.push(mac.session, <RecordPush>[change]);
    await harness.push(mac.session, <RecordPush>[harness.record('note-1')]);
    await expectQuiet(phoneLive);
    await expectQuiet(tabletLive);

    final PushResponse passPush = await harness.push(phoneIn.pass, <RecordPush>[
      harness.record('note-2'),
    ]);

    expect(passPush.results.single.status, PushStatus.accepted);
    expect(await macLive.next(), const LiveNudge(latestSeq: 2));
    expect(await tabletLive.next(), const LiveNudge(latestSeq: 2));
    await expectQuiet(phoneLive);
    await expectQuiet(strangerLive);
  });

  test(
    'a silent socket is closed after ninety seconds and pings keep it open',
    () async {
      final TestAccount account = await harness.enrol();
      final TestDevice phone = harness.addDevice(account);
      final SignedIn mac = await harness.signIn(account.firstDevice);
      final SignedIn phoneIn = await harness.signIn(phone);
      final LiveClient silent = await harness.openLive(mac.token);
      final LiveClient chatty = await harness.openLive(phoneIn.token);
      expect(harness.app.live.openCount, 2);

      for (int step = 1; step <= 3; step++) {
        harness.advance(const Duration(seconds: 30));
        chatty.send(const LivePing());
        expect(await chatty.next(), const LivePong());
        await harness.tick();
        if (step < 3) {
          expect(harness.app.live.openCount, 2);
        }
      }

      await silent.closed;
      expect(silent.closeCode, liveIdleCode);
      expect(harness.app.live.openCount, 1);
      expect(chatty.isClosed, isFalse);

      harness.advance(const Duration(seconds: 30));
      chatty.send(const LivePing());
      expect(await chatty.next(), const LivePong());
      await harness.tick();
      expect(harness.app.live.openCount, 1);
      expect(chatty.isClosed, isFalse);
    },
  );
}
