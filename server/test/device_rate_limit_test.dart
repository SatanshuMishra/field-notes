import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relay_server/src/config.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

Future<http.Response> _pull(RelayHarness harness, SignedIn device) =>
    harness.send(
      SyncRoutes.pullRecords,
      credential: device.session,
      query: const <String, String>{SyncRoutes.afterQuery: '0'},
    );

void main() {
  late RelayHarness harness;

  tearDown(() => harness.dispose());

  test(
    'a device past its request budget waits, and only that device',
    () async {
      harness = await RelayHarness.start(
        deviceRateBurst: 5,
        deviceRatePerSecond: 1,
      );
      final TestAccount account = await harness.enrol();
      final SignedIn mac = await harness.signIn(account.firstDevice);
      final SignedIn phone = await harness.signIn(harness.addDevice(account));

      for (int request = 1; request <= 5; request++) {
        expect(
          (await _pull(harness, mac)).statusCode,
          HttpStatus.ok,
          reason: 'pull $request',
        );
      }
      final http.Response refused = await _pull(harness, mac);

      expect(refused.statusCode, HttpStatus.tooManyRequests);
      expect(errorOf(refused).code, SyncErrorCode.tooManyRequests);
      expect(refused.headers['retry-after'], '1');
      expect((await _pull(harness, phone)).statusCode, HttpStatus.ok);

      harness.advance(const Duration(seconds: 1));
      expect((await _pull(harness, mac)).statusCode, HttpStatus.ok);
    },
  );

  test('by default a device may send 600 requests before it waits', () async {
    harness = await RelayHarness.start();
    final TestAccount account = await harness.enrol();
    final SignedIn mac = await harness.signIn(account.firstDevice);

    for (
      int request = 1;
      request <= RelayConfig.defaultDeviceRateBurst;
      request++
    ) {
      expect(
        (await _pull(harness, mac)).statusCode,
        HttpStatus.ok,
        reason: 'pull $request',
      );
    }
    expect((await _pull(harness, mac)).statusCode, HttpStatus.tooManyRequests);
  });

  test('the device budget comes from the environment', () {
    final RelayConfig config = RelayConfig.fromEnvironment(<String, String>{
      RelayConfig.deviceRateBurstVariable: '40',
      RelayConfig.deviceRatePerSecondVariable: '2.5',
    });

    expect(config.deviceRateBurst, 40);
    expect(config.deviceRatePerSecond, 2.5);
    expect(
      RelayConfig.fromEnvironment(const <String, String>{}).deviceRateBurst,
      RelayConfig.defaultDeviceRateBurst,
    );
    expect(
      () => RelayConfig.fromEnvironment(<String, String>{
        RelayConfig.deviceRatePerSecondVariable: '0',
      }),
      throwsA(isA<ConfigException>()),
    );
  });
}
