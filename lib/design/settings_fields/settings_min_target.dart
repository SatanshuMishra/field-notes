import 'package:flutter/widgets.dart';

const double _androidMinTarget = 48;
const double _macosMinTarget = 28;
const double _windowsMinTarget = 40;

double settingsMinTargetOn(TargetPlatform platform) => switch (platform) {
  TargetPlatform.macOS => _macosMinTarget,
  TargetPlatform.windows => _windowsMinTarget,
  _ => _androidMinTarget,
};
