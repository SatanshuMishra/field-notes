import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

class ImageCount {
  int created = 0;
  int disposed = 0;

  void start() => FlutterMemoryAllocations.instance.addListener(_heard);

  void stop() => FlutterMemoryAllocations.instance.removeListener(_heard);

  void _heard(ObjectEvent event) {
    if (event.object is! ui.Image) {
      return;
    }
    if (event is ObjectCreated) {
      created++;
    } else if (event is ObjectDisposed) {
      disposed++;
    }
  }
}
