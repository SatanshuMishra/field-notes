import 'dart:async';
import 'dart:collection';

typedef VideoSlotEviction = void Function();
typedef VideoSlotFreedListener = void Function();
typedef VideoSlotErrorReporter = void Function(
  Object error,
  StackTrace stackTrace,
);

const int assumedConcurrentVideoDecoderCap = 6;

enum VideoSlotEvictionRights { none, evictUnpinned }

final class VideoSlotToken {
  VideoSlotToken._();
}

abstract interface class VideoSlots {
  VideoSlotToken? acquire({
    required VideoSlotEviction onEvicted,
    required VideoSlotEvictionRights evictionRights,
  });
  bool holds(VideoSlotToken? token);
  void release(VideoSlotToken? token);
  void pin(VideoSlotToken? token);
  void unpin(VideoSlotToken? token);
  void touch(VideoSlotToken? token);
  bool addSlotFreedListener(VideoSlotFreedListener listener);
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
  final Set<VideoSlotToken> _granting = <VideoSlotToken>{};
  bool _notifying = false;
  bool _notifyPending = false;
  bool _disposed = false;

  @override
  VideoSlotToken? acquire({
    required VideoSlotEviction onEvicted,
    required VideoSlotEvictionRights evictionRights,
  }) {
    if (_disposed) {
      return null;
    }
    if (_holders.length < cap) {
      return _grant(onEvicted);
    }
    if (evictionRights == VideoSlotEvictionRights.none) {
      return null;
    }
    final VideoSlotToken? victim = _leastRecentlyUsedUnpinned();
    if (victim == null) {
      return null;
    }
    final _SlotHolder evicted = _holders.remove(victim)!;
    final VideoSlotToken token = _grant(onEvicted);
    _granting.add(token);
    try {
      _invoke(evicted.onEvicted);
    } finally {
      _granting.remove(token);
    }
    return token;
  }

  @override
  bool holds(VideoSlotToken? token) =>
      token != null && _holders.containsKey(token);

  @override
  void release(VideoSlotToken? token) {
    if (token == null || _disposed || _holders.remove(token) == null) {
      return;
    }
    _notifySlotFreed();
  }

  @override
  void pin(VideoSlotToken? token) {
    if (token == null || _disposed) {
      return;
    }
    final _SlotHolder? holder = _holders[token];
    if (holder == null || holder.pinned) {
      return;
    }
    _holders[token] = holder.withPinned(true);
  }

  @override
  void unpin(VideoSlotToken? token) {
    if (token == null || _disposed) {
      return;
    }
    final _SlotHolder? holder = _holders.remove(token);
    if (holder == null) {
      return;
    }
    _holders[token] = holder.withPinned(false);
  }

  @override
  void touch(VideoSlotToken? token) {
    if (token == null || _disposed) {
      return;
    }
    final _SlotHolder? holder = _holders.remove(token);
    if (holder == null) {
      return;
    }
    _holders[token] = holder;
  }

  @override
  bool addSlotFreedListener(VideoSlotFreedListener listener) {
    if (_disposed) {
      return false;
    }
    if (!_slotFreedListeners.contains(listener)) {
      _slotFreedListeners.add(listener);
    }
    return true;
  }

  @override
  void removeSlotFreedListener(VideoSlotFreedListener listener) {
    _slotFreedListeners.remove(listener);
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final List<_SlotHolder> abandoned = List<_SlotHolder>.of(_holders.values);
    _holders.clear();
    _granting.clear();
    _slotFreedListeners.clear();
    for (final _SlotHolder holder in abandoned) {
      _invoke(holder.onEvicted);
    }
  }

  VideoSlotToken _grant(VideoSlotEviction onEvicted) {
    final VideoSlotToken token = VideoSlotToken._();
    _holders[token] = _SlotHolder(onEvicted: onEvicted, pinned: false);
    return token;
  }

  VideoSlotToken? _leastRecentlyUsedUnpinned() {
    for (final MapEntry<VideoSlotToken, _SlotHolder> entry
        in _holders.entries) {
      if (entry.value.pinned || _granting.contains(entry.key)) {
        continue;
      }
      return entry.key;
    }
    return null;
  }

  void _notifySlotFreed() {
    if (_notifying) {
      _notifyPending = true;
      return;
    }
    _notifying = true;
    try {
      _runSlotFreedPass();
      while (_notifyPending) {
        _notifyPending = false;
        _runSlotFreedPass();
      }
    } finally {
      _notifying = false;
      _notifyPending = false;
    }
  }

  void _runSlotFreedPass() {
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
  VideoSlotToken acquire({
    required VideoSlotEviction onEvicted,
    required VideoSlotEvictionRights evictionRights,
  }) =>
      VideoSlotToken._();

  @override
  bool holds(VideoSlotToken? token) => token != null;

  @override
  void release(VideoSlotToken? token) {}

  @override
  void pin(VideoSlotToken? token) {}

  @override
  void unpin(VideoSlotToken? token) {}

  @override
  void touch(VideoSlotToken? token) {}

  @override
  bool addSlotFreedListener(VideoSlotFreedListener listener) => true;

  @override
  void removeSlotFreedListener(VideoSlotFreedListener listener) {}

  @override
  void dispose() {}
}
