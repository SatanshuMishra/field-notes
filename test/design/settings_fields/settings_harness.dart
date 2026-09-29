import 'package:flutter/material.dart';

import 'package:field_notes/design/tokens/tokens.dart';

Widget settingsHarness(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: FieldNotesColors.light.page,
      body: Align(
        alignment: Alignment.topLeft,
        child: child,
      ),
    ),
  );
}
