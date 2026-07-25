import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'video_slots.dart';

part 'video_slots_provider.g.dart';

@Riverpod(keepAlive: true)
VideoSlots videoSlots(Ref ref) {
  final LruVideoSlots slots = LruVideoSlots(
    onCallbackError: (Object error, StackTrace stackTrace) =>
        FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'field_notes',
        context: ErrorDescription('tearing down a capped video decoder slot'),
      ),
    ),
  );
  ref.onDispose(slots.dispose);
  return slots;
}
