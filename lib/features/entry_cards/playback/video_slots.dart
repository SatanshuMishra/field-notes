import 'dart:async';
import 'dart:collection';

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

final class _SlotHolder {
  const _SlotHolder({required this.onEvicted, required this.pinned});

  final VideoSlotEviction onEvicted;
  final bool pinned;

  _SlotHolder withPinned(bool value) =>
      _SlotHolder(onEvicted: onEvicted, pinned: value);
}

final class LruVideoSlots implements VideoSlots {
  LruVideoSlots({
    this.cap = assumedConcurrentVideoDecoderCap,
    this.onCallbackError,
  }) {
    if (cap < 1) {
      throw ArgumentError.value(cap, 'cap', 'must allow at least one slot');
    }
  }

  final int cap;
  final VideoSlotErrorReporter? onCallbackError;
  final LinkedHashMap<VideoSlotToken, _SlotHolder> _holders =
      LinkedHashMap<VideoSlotToken, _SlotHolder>();
  final List<VideoSlotFreedListener> _slotFreedListeners =
      <VideoSlotFreedListener>[];

  @override
  VideoSlotToken? acquire({required VideoSlotEviction onEvicted}) {
    if (_holders.length < cap) {
      return _grant(onEvicted);
    }
    final VideoSlotToken? victim = _leastRecentlyUsedUnpinned();
    if (victim == null) {
      return null;
    }
    final _SlotHolder? evicted = _holders.remove(victim);
    final VideoSlotToken token = _grant(onEvicted);
    if (evicted != null) {
      _invoke(evicted.onEvicted);
    }
    return token;
  }

  @override
  void release(VideoSlotToken? token) {
    if (token == null || _holders.remove(token) == null) {
      return;
    }
    _notifySlotFreed();
  }

  @override
  void pin(VideoSlotToken? token) => _setPinned(token, true);

  @override
  void unpin(VideoSlotToken? token) => _setPinned(token, false);

  @override
  void touch(VideoSlotToken? token) {
    if (token == null) {
      return;
    }
    final _SlotHolder? holder = _holders.remove(token);
    if (holder == null) {
      return;
    }
    _holders[token] = holder;
  }

  @override
  void addSlotFreedListener(VideoSlotFreedListener listener) {
    if (_slotFreedListeners.contains(listener)) {
      return;
    }
    _slotFreedListeners.add(listener);
  }

  @override
  void removeSlotFreedListener(VideoSlotFreedListener listener) {
    _slotFreedListeners.remove(listener);
  }

  @override
  void dispose() {
    _holders.clear();
    _slotFreedListeners.clear();
  }

  VideoSlotToken _grant(VideoSlotEviction onEvicted) {
    final VideoSlotToken token = VideoSlotToken._();
    _holders[token] = _SlotHolder(onEvicted: onEvicted, pinned: false);
    return token;
  }

  VideoSlotToken? _leastRecentlyUsedUnpinned() {
    for (final MapEntry<VideoSlotToken, _SlotHolder> entry
        in _holders.entries) {
      if (!entry.value.pinned) {
        return entry.key;
      }
    }
    return null;
  }

  void _setPinned(VideoSlotToken? token, bool pinned) {
    if (token == null) {
      return;
    }
    final _SlotHolder? holder = _holders[token];
    if (holder == null || holder.pinned == pinned) {
      return;
    }
    _holders[token] = holder.withPinned(pinned);
  }

  void _notifySlotFreed() {
    for (final VideoSlotFreedListener listener
        in List<VideoSlotFreedListener>.of(_slotFreedListeners)) {
      if (!_slotFreedListeners.contains(listener)) {
        continue;
      }
      _invoke(listener);
    }
  }

  void _invoke(void Function() callback) {
    try {
      callback();
    } catch (error, stackTrace) {
      _report(error, stackTrace);
    }
  }

  void _report(Object error, StackTrace stackTrace) {
    final VideoSlotErrorReporter? reporter = onCallbackError;
    if (reporter == null) {
      Zone.current.handleUncaughtError(error, stackTrace);
      return;
    }
    reporter(error, stackTrace);
  }
}

final class UnlimitedVideoSlots implements VideoSlots {
  const UnlimitedVideoSlots();

  @override
  VideoSlotToken acquire({required VideoSlotEviction onEvicted}) =>
      VideoSlotToken._();

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
