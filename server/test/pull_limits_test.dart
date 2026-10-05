import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

const int pageLimit = 8 * 1024 * 1024;
const int largeState = 2 * 1024 * 1024;
const int storedStates = 6;
const int freeFloor = 1024 * 1024 * 1024;
const Duration probeLifetime = Duration(seconds: 5);
const Timeout largeTimeout = Timeout(Duration(minutes: 2));

void main() {
  late RelayHarness harness;

  setUp(() async {
    harness = await RelayHarness.start(startTimer: ManualTimers().start);
  });

  tearDown(() async {
    await harness.dispose();
  });

  int records() => harness.database.count('SELECT count(*) FROM records');

  Future<http.Response> sendPush(
    RelayHarness relay,
    SignedIn who,
    List<RecordPush> changes,
  ) => relay.send(
    SyncRoutes.pushRecords,
    credential: who.session,
    body: PushRequest(changes: changes),
  );

  Future<List<Uint8List>> storeLargeStates(SignedIn who) async {
    final List<Uint8List> envelopes = <Uint8List>[];
    for (int index = 0; index < storedStates; index++) {
      final Uint8List envelope = harness.randomOpaque(largeState);
      final PushResponse pushed = await harness.push(who.session, <RecordPush>[
        harness.record('note-$index', envelope: envelope),
      ]);
      expect(pushed.results.single.status, PushStatus.accepted);
      envelopes.add(envelope);
    }
    return envelopes;
  }

  test('a push with an oversized envelope is refused', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn mac = await harness.signIn(account.firstDevice);

    final http.Response refused = await sendPush(harness, mac, <RecordPush>[
      harness.record('small'),
      harness.record('large', envelope: Uint8List(maxEnvelopeBytes + 1)),
    ]);

    expect(refused.statusCode, HttpStatus.badRequest);
    expect(errorOf(refused).code, SyncErrorCode.badRequest);
    expect(records(), 0);

    final PushResponse accepted = await harness.push(mac.session, <RecordPush>[
      harness.record('small'),
      harness.record('large', envelope: Uint8List(maxEnvelopeBytes)),
    ]);

    expect(
      accepted.results.map((RecordPushResult result) => result.status),
      <PushStatus>[PushStatus.accepted, PushStatus.accepted],
    );
    expect(records(), 2);
  }, timeout: largeTimeout);

  test('a pull page stays under its byte limit', () async {
    final TestAccount account = await harness.enrol();
    final SignedIn mac = await harness.signIn(account.firstDevice);
    final List<Uint8List> envelopes = await storeLargeStates(mac);

    final List<RecordState> pulled = <RecordState>[];
    int after = 0;
    int pages = 0;
    bool hasMore = true;
    while (hasMore) {
      final http.Response page = await harness.send(
        SyncRoutes.pullRecords,
        credential: mac.session,
        query: <String, String>{SyncRoutes.afterQuery: '$after'},
      );
      pages++;
      expect(page.statusCode, HttpStatus.ok);
      expect(page.bodyBytes.length, lessThan(pageLimit), reason: 'page $pages');
      final PullResponse response = PullResponse.fromJson(
        decodeJsonObject(page.body),
      );
      expect(response.states, isNotEmpty, reason: 'page $pages');
      pulled.addAll(response.states);
      expect(response.remaining, storedStates - pulled.length);
      expect(response.hasMore, response.remaining > 0);
      hasMore = response.hasMore;
      after = response.states.last.seq;
    }

    expect(pages, greaterThan(1));
    expect(pulled.map((RecordState state) => state.recordKey), <String>[
      for (int index = 0; index < storedStates; index++) 'note-$index',
    ]);
    expect(pulled.map((RecordState state) => state.seq), <int>[
      for (int seq = 1; seq <= storedStates; seq++) seq,
    ]);
    for (int index = 0; index < storedStates; index++) {
      expect(pulled[index].envelope, envelopes[index], reason: 'note-$index');
    }
  }, timeout: largeTimeout);

  test('a push is refused while the disk is nearly full', () async {
    final RelayHarness tight = await RelayHarness.start(
      minFreeBytes: freeFloor,
      startTimer: ManualTimers().start,
    );
    addTearDown(tight.dispose);
    final TestAccount account = await tight.enrol();
    final SignedIn mac = await tight.signIn(account.firstDevice);
    tight.freeBytes = freeFloor + 512;

    final http.Response refused = await sendPush(tight, mac, <RecordPush>[
      tight.record('note-1'),
    ]);

    expect(refused.statusCode, HttpStatus.insufficientStorage);
    expect(errorOf(refused).code, SyncErrorCode.storageFull);
    expect(tight.database.count('SELECT count(*) FROM records'), 0);

    tight.freeBytes = freeFloor + 1024 * 1024;
    tight.advance(probeLifetime);
    final PushResponse accepted = await tight.push(mac.session, <RecordPush>[
      tight.record('note-1'),
    ]);

    expect(accepted.results.single.status, PushStatus.accepted);
    expect(tight.database.count('SELECT count(*) FROM records'), 1);
  });

  test(
    'a stale push carries current states only within the byte limit',
    () async {
      final TestAccount account = await harness.enrol();
      final SignedIn mac = await harness.signIn(account.firstDevice);
      await storeLargeStates(mac);

      final http.Response answered = await sendPush(harness, mac, <RecordPush>[
        for (int index = 0; index < storedStates; index++)
          harness.record('note-$index'),
      ]);

      expect(answered.statusCode, HttpStatus.ok);
      expect(answered.bodyBytes.length, lessThan(pageLimit));
      final PushResponse response = PushResponse.fromJson(
        decodeJsonObject(answered.body),
      );
      expect(
        response.results.map((RecordPushResult result) => result.status),
        everyElement(PushStatus.stale),
      );
      final List<RecordState?> current = <RecordState?>[
        for (final RecordPushResult result in response.results) result.current,
      ];
      expect(
        current.whereType<RecordState>().map(
          (RecordState state) => state.recordKey,
        ),
        <String>['note-0', 'note-1'],
      );
      expect(current.skip(2), everyElement(isNull));
    },
    timeout: largeTimeout,
  );
}
