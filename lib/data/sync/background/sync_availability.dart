import 'dart:async';

import 'package:field_notes/data/sync/background/background_uploads.dart';
import 'package:flutter/services.dart';

const String syncAvailableMethod = 'available';
const Duration syncAvailableWait = Duration(seconds: 1);

Future<bool> syncAvailableOnThisDevice({
  required TargetPlatform platform,
  MethodChannel channel = const MethodChannel(backgroundUploadsChannel),
  Duration wait = syncAvailableWait,
}) async {
  if (platform != TargetPlatform.android) {
    return true;
  }
  try {
    final bool? answer = await channel
        .invokeMethod<bool>(syncAvailableMethod)
        .timeout(wait);
    return answer != false;
  } on MissingPluginException {
    return true;
  } on PlatformException {
    return true;
  } on TimeoutException {
    return true;
  }
}
