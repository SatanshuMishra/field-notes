import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relay_server/src/in_flight.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

const Duration answerLimit = Duration(seconds: 10);
const int largeEnvelope = 150 * 1024;
const int sentFirst = 64 * 1024;

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

Future<http.Response> sendPush(
  RelayHarness relay,
  SignedIn who,
  List<RecordPush> changes,
) => relay.send(
  SyncRoutes.pushRecords,
  credential: who.session,
  body: PushRequest(changes: changes),
);

typedef RawPush = ({Socket socket, Future<String> answer});

Future<RawPush> openRawPush(
  RelayHarness relay,
  SignedIn who,
  List<int> body,
  int sent,
) async {
  final Uri target = relay.uri(SyncRoutes.pushRecords);
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
        '${SyncRoutes.pushRecords.method} ${target.path} HTTP/1.1\r\n'
        'Host: ${target.host}:${target.port}\r\n'
        'Connection: close\r\n'
        'Content-Length: ${body.length}\r\n'
        'content-type: application/json\r\n'
        '${SyncHeaders.protocol}: $syncProtocolVersion\r\n'
        '${SyncHeaders.authorization}: ${who.session.authorization}\r\n'
        '\r\n',
      ),
    )
    ..add(body.sublist(0, sent));
  await socket.flush();
  return (socket: socket, answer: answered.future);
}

void main() {
  test('unread push answers are bounded per device', () async {
    final ManualTimers timers = ManualTimers();
    final HeldResponses responses = HeldResponses();
    final RelayHarness relay = await RelayHarness.start(
      startTimer: timers.start,
      responseOutput: responses.output,
    );
    addTearDown(relay.dispose);
    final TestAccount account = await relay.enrol();
    final SignedIn mac = await relay.signIn(account.firstDevice);
    final SignedIn phone = await relay.signIn(relay.addDevice(account));
    final String deviceId = account.firstDevice.deviceId;

    responses.toHold = maxPushesInFlight;
    for (int index = 0; index < maxPushesInFlight; index++) {
      sendPush(relay, mac, <RecordPush>[relay.record('held-$index')]).ignore();
    }
    expect(
      await eventually(() => responses.held.length == maxPushesInFlight),
      isTrue,
    );

    final Future<http.Response> waiting = sendPush(relay, mac, <RecordPush>[
      relay.record('refused'),
    ]);
    expect(
      await eventually(() => relay.app.pushesInFlight.waiting(deviceId) == 1),
      isTrue,
    );
    timers.pending(pushSlotWaitLimit).single.fire();
    final http.Response refused = await waiting.timeout(answerLimit);

    expect(refused.statusCode, HttpStatus.tooManyRequests);
    expect(errorOf(refused).code, SyncErrorCode.tooManyRequests);
    expect(refused.headers['retry-after'], '1');
    expect(relay.app.pushesInFlight.count(deviceId), maxPushesInFlight);
    expect(relay.app.pushesInFlight.waiting(deviceId), 0);
    final PushResponse elsewhere = await relay
        .push(phone.session, <RecordPush>[relay.record('elsewhere')])
        .timeout(answerLimit);
    expect(elsewhere.results.single.status, PushStatus.accepted);
  });

  test('a fifth push waits for a push slot', () async {
    final ManualTimers timers = ManualTimers();
    final HeldResponses responses = HeldResponses();
    final RelayHarness relay = await RelayHarness.start(
      startTimer: timers.start,
      responseOutput: responses.output,
    );
    addTearDown(relay.dispose);
    final TestAccount account = await relay.enrol();
    final SignedIn mac = await relay.signIn(account.firstDevice);
    final String deviceId = account.firstDevice.deviceId;
    int records() => relay.database.count('SELECT count(*) FROM records');

    responses.toHold = maxPushesInFlight;
    for (int index = 0; index < maxPushesInFlight; index++) {
      sendPush(relay, mac, <RecordPush>[relay.record('held-$index')]).ignore();
    }
    expect(
      await eventually(() => responses.held.length == maxPushesInFlight),
      isTrue,
    );
    expect(records(), maxPushesInFlight);

    final List<int> body = utf8.encode(
      jsonEncode(
        PushRequest(
          changes: <RecordPush>[
            relay.record('waited', envelope: relay.randomOpaque(largeEnvelope)),
          ],
        ).toJson(),
      ),
    );
    final (:Socket socket, :Future<String> answer) = await openRawPush(
      relay,
      mac,
      body,
      sentFirst,
    );
    addTearDown(socket.destroy);
    bool answered = false;
    unawaited(answer.then((String _) => answered = true));

    expect(
      await eventually(() => relay.app.pushesInFlight.waiting(deviceId) == 1),
      isTrue,
    );
    final ManualTimer slotWait = timers.pending(pushSlotWaitLimit).single;
    expect(relay.app.pushesInFlight.count(deviceId), maxPushesInFlight);
    expect(relay.app.largeBodies.active, 0);
    expect(relay.app.addressesInFlight.count('127.0.0.1'), 0);
    expect(answered, isFalse);

    responses.held.first.resume();

    expect(await eventually(() => relay.app.largeBodies.active == 1), isTrue);
    expect(relay.app.pushesInFlight.waiting(deviceId), 0);
    expect(relay.app.pushesInFlight.count(deviceId), maxPushesInFlight);
    expect(slotWait.isActive, isFalse);
    expect(answered, isFalse);
    socket.add(body.sublist(sentFirst));

    final String accepted = await answer.timeout(answerLimit);
    expect(accepted, startsWith('HTTP/1.1 200'));
    final PushResponse response = PushResponse.fromJson(
      decodeJsonObject(accepted.substring(accepted.indexOf('\r\n\r\n') + 4)),
    );
    expect(response.results.single.status, PushStatus.accepted);
    expect(records(), maxPushesInFlight + 1);
  });
}
