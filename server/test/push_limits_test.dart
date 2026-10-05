import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relay_server/src/in_flight.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

const Duration answerLimit = Duration(seconds: 10);

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

void main() {
  test('unread push answers are bounded per device', () async {
    final HeldResponses responses = HeldResponses();
    final RelayHarness relay = await RelayHarness.start(
      startTimer: ManualTimers().start,
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

    final http.Response refused = await sendPush(relay, mac, <RecordPush>[
      relay.record('refused'),
    ]).timeout(answerLimit);

    expect(refused.statusCode, HttpStatus.tooManyRequests);
    expect(errorOf(refused).code, SyncErrorCode.tooManyRequests);
    expect(refused.headers['retry-after'], '1');
    expect(relay.app.pushesInFlight.count(deviceId), maxPushesInFlight);
    final PushResponse elsewhere = await relay
        .push(phone.session, <RecordPush>[relay.record('elsewhere')])
        .timeout(answerLimit);
    expect(elsewhere.results.single.status, PushStatus.accepted);
  });
}
