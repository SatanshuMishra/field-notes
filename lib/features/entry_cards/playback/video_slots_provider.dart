import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'video_slots.dart';

part 'video_slots_provider.g.dart';

@Riverpod(keepAlive: true)
VideoSlots videoSlots(Ref ref) {
  final LruVideoSlots slots = LruVideoSlots();
  ref.onDispose(slots.dispose);
  return slots;
}
