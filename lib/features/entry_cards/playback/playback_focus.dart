import 'package:flutter/foundation.dart';

typedef _PlaybackHolder = ({Object owner, VoidCallback pause});

final class PlaybackFocus {
  _PlaybackHolder? _holder;

  void claim(Object owner, VoidCallback pause) {
    final _PlaybackHolder? previous = _holder;
    _holder = (owner: owner, pause: pause);
    if (previous == null || identical(previous.owner, owner)) {
      return;
    }
    _pause(previous.pause);
  }

  void release(Object owner) {
    if (identical(_holder?.owner, owner)) {
      _holder = null;
    }
  }

  void silence() {
    final _PlaybackHolder? current = _holder;
    _holder = null;
    if (current != null) {
      _pause(current.pause);
    }
  }

  void _pause(VoidCallback pause) {
    try {
      pause();
    } catch (error, stackTrace) {
      debugPrint('Playback pause failed: $error\n$stackTrace');
    }
  }
}

final PlaybackFocus playbackFocus = PlaybackFocus();
