import 'package:relay_server/src/live.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

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

  test('nudges to one socket are held to one a second', () async {
    final TestAccount account = await harness.enrol();
    final TestDevice phone = harness.addDevice(account);
    final SignedIn mac = await harness.signIn(account.firstDevice);
    final SignedIn phoneIn = await harness.signIn(phone);
    final LiveClient phoneLive = await harness.openLive(phoneIn.token);

    await harness.push(mac.session, <RecordPush>[harness.record('note-0')]);
    expect(await phoneLive.next(), const LiveNudge(latestSeq: 1));

    for (int index = 1; index <= 20; index++) {
      final PushResponse pushed = await harness.push(mac.session, <RecordPush>[
        harness.record('note-$index'),
      ]);
      expect(pushed.results.single.status, PushStatus.accepted);
    }
    phoneLive.send(const LivePing());
    expect(await phoneLive.next(), const LivePong());

    final List<ManualTimer> held = timers.pending(liveNudgeInterval);
    expect(held, hasLength(1));
    held.single.fire();
    expect(await phoneLive.next(), const LiveNudge(latestSeq: 21));

    harness.advance(liveNudgeInterval);
    await harness.push(mac.session, <RecordPush>[harness.record('note-21')]);
    expect(await phoneLive.next(), const LiveNudge(latestSeq: 22));
    expect(timers.pending(liveNudgeInterval), isEmpty);
  });
}
