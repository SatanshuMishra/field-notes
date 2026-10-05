import 'package:flutter/services.dart';

const String batterySettingsChannel = 'field_notes/battery_settings';
const String samsungManufacturer = 'samsung';

enum BatterySettingsScreen {
  samsungNeverSleeping,
  ignoreOptimizationsRequest,
  appDetails,
  none,
}

abstract interface class BatterySettings {
  Future<bool> isExempt();

  Future<BatterySettingsScreen> open();
}

class ChannelBatterySettings implements BatterySettings {
  const ChannelBatterySettings({
    this.channel = const MethodChannel(batterySettingsChannel),
  });

  final MethodChannel channel;

  @override
  Future<bool> isExempt() async =>
      await channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
      false;

  @override
  Future<BatterySettingsScreen> open() async {
    final String manufacturer =
        (await channel.invokeMethod<String>('manufacturer') ?? '')
            .trim()
            .toLowerCase();
    if (manufacturer == samsungManufacturer) {
      if (await _start('openNeverSleepingApps')) {
        return BatterySettingsScreen.samsungNeverSleeping;
      }
    } else if (await _start('requestIgnoreBatteryOptimizations')) {
      return BatterySettingsScreen.ignoreOptimizationsRequest;
    }
    if (await _start('openAppDetails')) {
      return BatterySettingsScreen.appDetails;
    }
    return BatterySettingsScreen.none;
  }

  Future<bool> _start(String method) async {
    try {
      await channel.invokeMethod<void>(method);
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
