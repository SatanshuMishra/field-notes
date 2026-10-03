import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const SystemUiOverlayStyle lightBackdropSystemBars = SystemUiOverlayStyle(
  statusBarBrightness: Brightness.light,
  statusBarIconBrightness: Brightness.dark,
  systemNavigationBarIconBrightness: Brightness.dark,
);

const SystemUiOverlayStyle darkBackdropSystemBars = SystemUiOverlayStyle(
  statusBarBrightness: Brightness.dark,
  statusBarIconBrightness: Brightness.light,
  systemNavigationBarIconBrightness: Brightness.light,
);

SystemUiOverlayStyle systemBarsOver(Brightness backdrop) => switch (backdrop) {
  Brightness.light => lightBackdropSystemBars,
  Brightness.dark => darkBackdropSystemBars,
};

SystemUiOverlayStyle systemBarsOverColor(Color backdrop) =>
    systemBarsOver(ThemeData.estimateBrightnessForColor(backdrop));
