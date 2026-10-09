import 'package:flutter/foundation.dart';

bool isDesktopPlatform(TargetPlatform platform) => switch (platform) {
  TargetPlatform.macOS || TargetPlatform.windows => true,
  TargetPlatform.android ||
  TargetPlatform.iOS ||
  TargetPlatform.linux ||
  TargetPlatform.fuchsia => false,
};
