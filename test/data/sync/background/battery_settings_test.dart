import 'dart:io';

import 'package:field_notes/data/sync/background/battery_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("the battery settings open the app's page and Samsung's list", () async {
    const MethodChannel channel = MethodChannel(batterySettingsChannel);
    final List<String> calls = <String>[];
    String manufacturer = 'samsung';
    bool exempt = false;
    Set<String> unavailable = <String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'manufacturer':
              return manufacturer;
            case 'isIgnoringBatteryOptimizations':
              return exempt;
          }
          if (unavailable.contains(call.method)) {
            throw PlatformException(code: 'unavailable');
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    const BatterySettings settings = ChannelBatterySettings();

    expect(await settings.open(), BatterySettingsScreen.samsungNeverSleeping);
    expect(calls, <String>['manufacturer', 'openNeverSleepingApps']);

    calls.clear();
    manufacturer = 'Google';
    expect(await settings.open(), BatterySettingsScreen.appDetails);
    expect(calls, <String>['manufacturer', 'openAppDetails']);

    calls.clear();
    manufacturer = 'samsung';
    unavailable = <String>{'openNeverSleepingApps'};
    expect(await settings.open(), BatterySettingsScreen.appDetails);
    expect(calls, <String>[
      'manufacturer',
      'openNeverSleepingApps',
      'openAppDetails',
    ]);

    calls.clear();
    unavailable = <String>{'openNeverSleepingApps', 'openAppDetails'};
    expect(await settings.open(), BatterySettingsScreen.none);

    expect(await settings.isExempt(), isFalse);
    exempt = true;
    expect(await settings.isExempt(), isTrue);
  });

  test('the Android side never asks for the battery exemption itself', () {
    final String activity = File(
      'android/app/src/main/kotlin/dev/satanshumishra/field_notes/MainActivity.kt',
    ).readAsStringSync();

    expect(
      activity,
      isNot(contains('ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS')),
    );
    expect(activity, isNot(contains('"requestIgnoreBatteryOptimizations"')));
    expect(activity, contains('"isIgnoringBatteryOptimizations"'));
    expect(activity, contains('"openAppDetails"'));
  });
}
