import 'package:http/http.dart' as http;
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

  test('a clock stepping back holds a nudge for at most a second', () async {
    final TestAccount account = await harness.enrol();
    final TestDevice phone = harness.addDevice(account);
    final SignedIn mac = await harness.signIn(account.firstDevice);
    final SignedIn phoneIn = await harness.signIn(phone);
    final LiveClient phoneLive = await harness.openLive(phoneIn.token);
    await harness.push(mac.session, <RecordPush>[harness.record('note-0')]);
    expect(await phoneLive.next(), const LiveNudge(latestSeq: 1));

    harness.advance(const Duration(hours: -1));
    await harness.push(mac.session, <RecordPush>[harness.record('note-1')]);
    phoneLive.send(const LivePing());
    expect(await phoneLive.next(), const LivePong());

    final List<ManualTimer> held = timers.pending(liveNudgeInterval);
    expect(held, hasLength(1));
    held.single.fire();
    expect(await phoneLive.next(), const LiveNudge(latestSeq: 2));
  });

  test('a finished upload nudges the other devices once', () async {
    final TestAccount account = await harness.enrol();
    final TestDevice mac = harness.addDevice(account);
    final SignedIn phoneIn = await harness.signIn(account.firstDevice);
    final SignedIn macIn = await harness.signIn(mac);
    final LiveClient macLive = await harness.openLive(macIn.token);
    final LiveClient phoneLive = await harness.openLive(phoneIn.token);
    await harness.push(phoneIn.session, <RecordPush>[harness.record('note-0')]);
    expect(await macLive.next(), const LiveNudge(latestSeq: 1));
    harness.advance(liveNudgeInterval);
    const int partSize = 1024;
    final List<int> blob = List<int>.generate(
      partSize + 300,
      (int index) => index % 251,
    );
    final String name = harness.blobName();
    final String uploadId = newSyncId();
    Future<UploadStatusResponse> put(int index) async {
      final int start = index * partSize;
      final int end = start + partSize > blob.length
          ? blob.length
          : start + partSize;
      final http.Response response = await harness.putPart(
        phoneIn.session,
        name: name,
        uploadId: uploadId,
        index: index,
        blobSize: blob.length,
        partSize: partSize,
        bytes: blob.sublist(start, end),
      );
      return UploadStatusResponse.fromJson(decodeJsonObject(response.body));
    }

    expect((await put(0)).assembled, isFalse);
    macLive.send(const LivePing());
    expect(await macLive.next(), const LivePong());

    expect((await put(1)).assembled, isTrue);
    expect(await macLive.next(), const LiveNudge(latestSeq: 1));

    harness.advance(liveNudgeInterval);
    expect((await put(1)).assembled, isTrue);
    macLive.send(const LivePing());
    expect(await macLive.next(), const LivePong());
    phoneLive.send(const LivePing());
    expect(await phoneLive.next(), const LivePong());
  });
}
