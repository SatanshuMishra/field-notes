import 'package:flutter/material.dart';

Widget voiceHarness(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
  );
}
