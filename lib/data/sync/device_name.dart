import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

const String fallbackDeviceName = 'This device';

typedef DeviceNameReader = Future<String> Function();

Future<String> defaultDeviceName({
  DeviceInfoPlugin? plugin,
  TargetPlatform? platform,
}) async {
  try {
    return await _modelName(
          plugin ?? DeviceInfoPlugin(),
          platform ?? defaultTargetPlatform,
        ) ??
        fallbackDeviceName;
  } on Exception {
    return fallbackDeviceName;
  }
}

Future<String?> _modelName(
  DeviceInfoPlugin info,
  TargetPlatform platform,
) async {
  switch (platform) {
    case TargetPlatform.macOS:
      final MacOsDeviceInfo mac = await info.macOsInfo;
      return _present(mac.modelName) ?? _present(mac.model);
    case TargetPlatform.android:
      final AndroidDeviceInfo android = await info.androidInfo;
      return _present(android.model);
    case TargetPlatform.fuchsia:
    case TargetPlatform.iOS:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return null;
  }
}

String? _present(String value) {
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
