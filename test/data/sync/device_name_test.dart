import 'package:device_info_plus/device_info_plus.dart';
import 'package:field_notes/data/sync/device_name.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDeviceInfo extends Fake implements DeviceInfoPlugin {
  _FakeDeviceInfo(this._computerName);

  final String _computerName;

  @override
  Future<WindowsDeviceInfo> get windowsInfo async => WindowsDeviceInfo(
    computerName: _computerName,
    numberOfCores: 8,
    systemMemoryInMegabytes: 16384,
    userName: 'student',
    majorVersion: 10,
    minorVersion: 0,
    buildNumber: 22631,
    platformId: 2,
    csdVersion: '',
    servicePackMajor: 0,
    servicePackMinor: 0,
    suitMask: 0,
    productType: 1,
    reserved: 0,
    buildLab: '',
    buildLabEx: '',
    digitalProductId: Uint8List(0),
    displayVersion: '23H2',
    editionId: 'Professional',
    installDate: DateTime.utc(2026),
    productId: '',
    productName: 'Windows 11 Pro',
    registeredOwner: '',
    releaseId: '2009',
    deviceId: '',
  );
}

void main() {
  test('Windows names the device after the computer', () async {
    expect(
      await defaultDeviceName(
        plugin: _FakeDeviceInfo('STUDY-PC'),
        platform: TargetPlatform.windows,
      ),
      'STUDY-PC',
    );
    expect(
      await defaultDeviceName(
        plugin: _FakeDeviceInfo('  '),
        platform: TargetPlatform.windows,
      ),
      fallbackDeviceName,
    );
  });
}
