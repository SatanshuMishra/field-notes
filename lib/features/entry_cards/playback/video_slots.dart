typedef VideoSlotEviction = void Function();
typedef VideoSlotFreedListener = void Function();
typedef VideoSlotErrorReporter = void Function(
  Object error,
  StackTrace stackTrace,
);

const int assumedConcurrentVideoDecoderCap = 6;

final class VideoSlotToken {
  VideoSlotToken._();
}

abstract interface class VideoSlots {
  VideoSlotToken? acquire({required VideoSlotEviction onEvicted});
  void release(VideoSlotToken? token);
  void pin(VideoSlotToken? token);
  void unpin(VideoSlotToken? token);
  void touch(VideoSlotToken? token);
  void addSlotFreedListener(VideoSlotFreedListener listener);
  void removeSlotFreedListener(VideoSlotFreedListener listener);
  void dispose();
}

final class LruVideoSlots implements VideoSlots {
  LruVideoSlots({
    this.cap = assumedConcurrentVideoDecoderCap,
    VideoSlotErrorReporter? onCallbackError,
  }) : _onCallbackError = onCallbackError;

  final int cap;
  final VideoSlotErrorReporter? _onCallbackError;

  @override
  VideoSlotToken? acquire({required VideoSlotEviction onEvicted}) => null;

  @override
  void release(VideoSlotToken? token) {}

  @override
  void pin(VideoSlotToken? token) {}

  @override
  void unpin(VideoSlotToken? token) {}

  @override
  void touch(VideoSlotToken? token) {}

  @override
  void addSlotFreedListener(VideoSlotFreedListener listener) {}

  @override
  void removeSlotFreedListener(VideoSlotFreedListener listener) {}

  @override
  void dispose() {}
}

final class UnlimitedVideoSlots implements VideoSlots {
  const UnlimitedVideoSlots();

  @override
  VideoSlotToken? acquire({required VideoSlotEviction onEvicted}) => null;

  @override
  void release(VideoSlotToken? token) {}

  @override
  void pin(VideoSlotToken? token) {}

  @override
  void unpin(VideoSlotToken? token) {}

  @override
  void touch(VideoSlotToken? token) {}

  @override
  void addSlotFreedListener(VideoSlotFreedListener listener) {}

  @override
  void removeSlotFreedListener(VideoSlotFreedListener listener) {}

  @override
  void dispose() {}
}
