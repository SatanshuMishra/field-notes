import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

final Uint8List tinyPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

Widget photoHarness(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
  );
}
