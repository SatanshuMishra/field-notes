import 'package:flutter/material.dart';

import 'package:field_notes/app/theme/app_theme.dart';

Widget appHarness(
  Widget child, {
  TargetPlatform platform = TargetPlatform.macOS,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: fieldNotesTheme(platform: platform),
    home: child,
  );
}
