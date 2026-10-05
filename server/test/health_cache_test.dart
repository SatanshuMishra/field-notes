import 'dart:io';

import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

final bool runningAsRoot =
    '${Process.runSync('id', <String>['-u']).stdout}'.trim() == '0';

const String rootSkip = 'chmod does not stop root from writing files';

void main() {
  test('the health probe runs at most once every five seconds', () async {
    final RelayHarness harness = await RelayHarness.start();
    addTearDown(harness.dispose);
    Future<int> health() async =>
        (await harness.send(SyncRoutes.health)).statusCode;

    expect(await health(), HttpStatus.ok);
    Process.runSync('chmod', <String>['555', harness.mediaDirectory]);
    addTearDown(
      () => Process.runSync('chmod', <String>['755', harness.mediaDirectory]),
    );

    expect(await health(), HttpStatus.ok);
    harness.advance(const Duration(seconds: 4, milliseconds: 999));
    expect(await health(), HttpStatus.ok);
    harness.advance(const Duration(milliseconds: 1));
    expect(await health(), HttpStatus.serviceUnavailable);

    Process.runSync('chmod', <String>['755', harness.mediaDirectory]);
    expect(await health(), HttpStatus.serviceUnavailable);
    harness.advance(const Duration(seconds: 5));
    expect(await health(), HttpStatus.ok);
  }, skip: runningAsRoot ? rootSkip : null);
}
