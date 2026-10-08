import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

Future<Directory> journalDirectory({TargetPlatform? platform}) {
  final TargetPlatform target = platform ?? defaultTargetPlatform;
  if (target == TargetPlatform.windows) {
    return getApplicationSupportDirectory();
  }
  return getApplicationDocumentsDirectory();
}
