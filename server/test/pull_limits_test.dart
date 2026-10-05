import 'dart:async';
import 'dart:convert';
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
const Duration answerLimit = Duration(seconds: 10);
const Duration stallLimit = Duration(seconds: 30);
const Duration downloadStallLimit = Duration(minutes: 5);

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

final class HeldResponses {
  final List<StreamSubscription<List<int>>> held =
      <StreamSubscription<List<int>>>[];
  int toHold = 0;

  Stream<List<int>> output(Stream<List<int>> body) {
    if (toHold == 0) {
      return body;
    }
    toHold--;
    held.add(body.listen(null)..pause());
    return Stream<List<int>>.fromFuture(Completer<List<int>>().future);
  }
}

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

  Future<http.Response> sendPull(RelayHarness relay, SignedIn who) =>
      relay.send(
        SyncRoutes.pullRecords,
        credential: who.session,
        query: const <String, String>{SyncRoutes.afterQuery: '0'},
      );

  Future<({Socket socket, Future<void> closed})> openRawGet(
    SignedIn who,
    Uri target,
  ) async {
    final Socket socket = await Socket.connect(target.host, target.port);
    final Completer<void> closed = Completer<void>();
    void finish() {
      if (!closed.isCompleted) {
        closed.complete();
      }
    }

    socket.done.ignore();
    socket.listen(
      (List<int> _) {},
      onDone: finish,
      onError: (Object _) => finish(),
      cancelOnError: true,
    );
    socket.add(
      latin1.encode(
        'GET ${target.path}${target.hasQuery ? '?${target.query}' : ''} '
        'HTTP/1.1\r\n'
        'Host: ${target.host}:${target.port}\r\n'
        '${SyncHeaders.protocol}: $syncProtocolVersion\r\n'
        '${SyncHeaders.authorization}: ${who.session.authorization}\r\n'
        '\r\n',
      ),
    );
    await socket.flush();
    return (socket: socket, closed: closed.future);
  }

  Future<({Socket socket, Future<void> closed})> openRawPull(
    RelayHarness relay,
    SignedIn who,
  ) => openRawGet(
    who,
    relay.uri(
      SyncRoutes.pullRecords,
      query: const <String, String>{SyncRoutes.afterQuery: '0'},
    ),
  );

  test('unread pull pages are bounded per device', () async {
    final HeldResponses responses = HeldResponses();
    final RelayHarness relay = await RelayHarness.start(
      startTimer: ManualTimers().start,
      responseOutput: responses.output,
    );
    addTearDown(relay.dispose);
    final TestAccount account = await relay.enrol();
    final SignedIn mac = await relay.signIn(account.firstDevice);
    final SignedIn phone = await relay.signIn(relay.addDevice(account));
    await relay.push(mac.session, <RecordPush>[relay.record('note-1')]);
    final String deviceId = account.firstDevice.deviceId;

    responses.toHold = 2;
    for (int index = 0; index < 2; index++) {
      sendPull(relay, mac).ignore();
    }
    expect(await eventually(() => responses.held.length == 2), isTrue);
    expect(relay.app.pullsInFlight.count(deviceId), 2);
    expect(relay.app.devicesInFlight.count(deviceId), 2);

    final http.Response refused = await sendPull(
      relay,
      mac,
    ).timeout(answerLimit);

    expect(refused.statusCode, HttpStatus.tooManyRequests);
    expect(errorOf(refused).code, SyncErrorCode.tooManyRequests);
    expect(refused.headers['retry-after'], '1');
    final PullResponse elsewhere = await relay
        .pull(phone.session)
        .timeout(answerLimit);
    expect(
      elsewhere.states.map((RecordState state) => state.recordKey),
      <String>['note-1'],
    );
    expect(relay.app.pullsInFlight.count(deviceId), 2);
  });

  test('a response that makes no progress is cut off', () async {
    final HeldResponses responses = HeldResponses();
    final RelayHarness relay = await RelayHarness.start(
      startTimer: ManualTimers().start,
      responseOutput: responses.output,
    );
    addTearDown(relay.dispose);
    final TestAccount account = await relay.enrol();
    final SignedIn mac = await relay.signIn(account.firstDevice);
    final String deviceId = account.firstDevice.deviceId;

    responses.toHold = 1;
    final (:Socket socket, :Future<void> closed) = await openRawPull(
      relay,
      mac,
    );
    addTearDown(socket.destroy);
    bool cutOff = false;
    unawaited(closed.then((void _) => cutOff = true));
    expect(await eventually(() => responses.held.length == 1), isTrue);
    expect(relay.app.devicesInFlight.count(deviceId), 1);
    expect(relay.app.pullsInFlight.count(deviceId), 1);

    relay.advance(stallLimit);
    await relay.tick();
    expect(relay.app.devicesInFlight.count(deviceId), 1);
    expect(cutOff, isFalse);

    relay.advance(const Duration(seconds: 1));
    await relay.tick();

    await closed.timeout(answerLimit);
    expect(relay.app.devicesInFlight.count(deviceId), 0);
    expect(relay.app.pullsInFlight.count(deviceId), 0);
    expect(relay.app.responses.open, 0);
  });

  test('a paused download is cut off only after five minutes', () async {
    final HeldResponses responses = HeldResponses();
    final RelayHarness relay = await RelayHarness.start(
      startTimer: ManualTimers().start,
      responseOutput: responses.output,
    );
    addTearDown(relay.dispose);
    final TestAccount account = await relay.enrol();
    final SignedIn mac = await relay.signIn(account.firstDevice);
    final String deviceId = account.firstDevice.deviceId;
    final String name = relay.blobName();
    await relay.uploadBlob(mac.session, name, relay.randomOpaque(4096));

    responses.toHold = 1;
    final (:Socket socket, :Future<void> closed) = await openRawGet(
      mac,
      relay.uri(
        SyncRoutes.downloadBlob,
        parameters: <String, Object>{SyncRoutes.nameParameter: name},
      ),
    );
    addTearDown(socket.destroy);
    expect(await eventually(() => responses.held.length == 1), isTrue);
    expect(relay.app.devicesInFlight.count(deviceId), 1);

    relay.advance(stallLimit + const Duration(seconds: 1));
    await relay.tick();
    expect(relay.app.devicesInFlight.count(deviceId), 1);
    expect(relay.app.responses.open, 1);

    relay.advance(downloadStallLimit - stallLimit - const Duration(seconds: 1));
    await relay.tick();
    expect(relay.app.devicesInFlight.count(deviceId), 1);
    expect(relay.app.responses.open, 1);

    relay.advance(const Duration(seconds: 1));
    await relay.tick();

    await closed.timeout(answerLimit);
    expect(relay.app.devicesInFlight.count(deviceId), 0);
    expect(relay.app.responses.open, 0);
  });
}
