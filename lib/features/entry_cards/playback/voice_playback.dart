import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/media/live_media.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/audio_playback.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';

class VoicePlayback extends ChangeNotifier {
  VoicePlayback({
    required this._entry,
    required this._resolver,
    required this._playerFactory,
    PlaybackFocus? focus,
  }) : _focus = focus ?? playbackFocus {
    _startPrepare();
  }

  final EntryAudioPlayerFactory _playerFactory;
  final PlaybackFocus _focus;
  final MediaArrivalWatch _arrivals = MediaArrivalWatch();
  Entry _entry;
  MediaResolver _resolver;
  EntryAudioPlayer? _player;
  StreamSubscription<AudioPlaybackState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  AudioPlaybackState _state = AudioPlaybackState.idle;
  Duration _position = Duration.zero;
  bool _unavailable = false;
  bool _ready = false;
  bool _disposed = false;
  int _generation = 0;

  AudioPlaybackState get state => _state;

  Duration get position => _position;

  bool get ready => _ready;

  bool get unavailable => _unavailable;

  bool get isPlaying => _state == AudioPlaybackState.playing;

  bool get isActive => switch (_state) {
    AudioPlaybackState.playing => true,
    AudioPlaybackState.paused ||
    AudioPlaybackState.loading => _position > Duration.zero,
    AudioPlaybackState.idle ||
    AudioPlaybackState.completed ||
    AudioPlaybackState.error => false,
  };

  Duration get total =>
      Duration(milliseconds: math.max(0, _entry.durationMs ?? 0));

  double get progress {
    final int totalMs = total.inMilliseconds;
    if (totalMs <= 0) {
      return 0;
    }
    return (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  Duration stepped(Duration delta) {
    final Duration target = _position + delta;
    if (target <= Duration.zero) {
      return Duration.zero;
    }
    final Duration end = total;
    return target >= end ? end : target;
  }

  void rebind({Entry? entry, MediaResolver? resolver}) {
    final Entry previousEntry = _entry;
    final MediaResolver previousResolver = _resolver;
    _entry = entry ?? previousEntry;
    _resolver = resolver ?? previousResolver;
    if (_needsRePrepare(previousEntry, previousResolver)) {
      _restart();
      return;
    }
    if (_entry != previousEntry) {
      notifyListeners();
    }
  }

  void seekToFraction(double fraction) {
    final Duration target = Duration(
      milliseconds: (fraction.clamp(0.0, 1.0) * total.inMilliseconds).round(),
    );
    unawaited(_seek(target, play: !isActive));
  }

  void seekBy(Duration delta) {
    unawaited(_seek(stepped(delta), play: false));
  }

  Future<void> toggle() async {
    final EntryAudioPlayer? player = _player;
    if (player == null) {
      return;
    }
    try {
      if (isPlaying) {
        _focus.release(this);
        await player.pause();
        return;
      }
      if (_state == AudioPlaybackState.completed) {
        await player.seek(Duration.zero);
      }
      await _play(player);
    } catch (error, stackTrace) {
      debugPrint('Voice playback toggle failed: $error\n$stackTrace');
      _markUnavailable();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    _arrivals.cancel();
    _teardownPlayer();
    super.dispose();
  }

  bool _needsRePrepare(Entry previousEntry, MediaResolver previousResolver) {
    if (previousEntry.mediaId != _entry.mediaId) {
      return true;
    }
    if (identical(previousResolver, _resolver)) {
      return false;
    }
    return !_ready;
  }

  void _onArrived() {
    if (_disposed || !_unavailable) {
      return;
    }
    _restart();
  }

  void _restart() {
    _arrivals.cancel();
    _teardownPlayer();
    _state = AudioPlaybackState.idle;
    _position = Duration.zero;
    _unavailable = false;
    _ready = false;
    notifyListeners();
    _startPrepare();
  }

  void _startPrepare() {
    unawaited(
      _prepare().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Voice prepare failed: $error\n$stackTrace');
      }),
    );
  }

  Future<void> _prepare() async {
    final int gen = ++_generation;
    final String? mediaId = _entry.mediaId;
    final ResolvedMedia media;
    try {
      media = await _resolver.resolve(mediaId);
    } catch (error, stackTrace) {
      debugPrint('Voice media resolve failed: $error\n$stackTrace');
      if (_isCurrent(gen)) {
        _markUnavailable();
      }
      return;
    }
    if (!_isCurrent(gen)) {
      return;
    }
    if (!media.isAvailable || media.file == null) {
      _unavailable = true;
      notifyListeners();
      _arrivals.watch(_resolver, mediaId, _onArrived);
      return;
    }
    final EntryAudioPlayer player = _playerFactory();
    _player = player;
    _stateSub = player.stateStream.listen(
      _onState,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Voice playback stream failed: $error\n$stackTrace');
        _markUnavailable();
      },
    );
    _positionSub = player.positionStream.listen(
      _onPosition,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Voice position stream failed: $error\n$stackTrace');
        _markUnavailable();
      },
    );
    try {
      await player.load(media.file!.path);
    } catch (error, stackTrace) {
      debugPrint('Voice playback load failed: $error\n$stackTrace');
      if (_isCurrent(gen)) {
        _markUnavailable();
      }
      return;
    }
    if (!_isCurrent(gen)) {
      return;
    }
    _ready = true;
    notifyListeners();
  }

  bool _isCurrent(int gen) => !_disposed && gen == _generation;

  void _teardownPlayer() {
    final EntryAudioPlayer? player = _player;
    _player = null;
    _focus.release(this);
    unawaited(_stateSub?.cancel());
    unawaited(_positionSub?.cancel());
    _stateSub = null;
    _positionSub = null;
    unawaited(player?.dispose());
  }

  void _markUnavailable() {
    if (_disposed) {
      return;
    }
    _focus.release(this);
    _unavailable = true;
    _ready = false;
    notifyListeners();
  }

  void _onState(AudioPlaybackState state) {
    if (_disposed) {
      return;
    }
    if (_endsPlayback(_state, state)) {
      _focus.release(this);
    }
    _state = state;
    notifyListeners();
  }

  void _onPosition(Duration position) {
    if (_disposed) {
      return;
    }
    _position = position;
    notifyListeners();
  }

  Future<void> _seek(Duration target, {required bool play}) async {
    final EntryAudioPlayer? player = _player;
    if (player == null) {
      return;
    }
    _position = target;
    notifyListeners();
    try {
      await player.seek(target);
      if (play) {
        await _play(player);
      }
    } catch (error, stackTrace) {
      debugPrint('Voice playback seek failed: $error\n$stackTrace');
      _markUnavailable();
    }
  }

  Future<void> _play(EntryAudioPlayer player) async {
    if (!identical(player, _player)) {
      return;
    }
    _focus.claim(this, () => unawaited(_yieldPlayback(player)));
    await player.play();
  }

  Future<void> _yieldPlayback(EntryAudioPlayer player) async {
    try {
      await player.pause();
    } catch (error, stackTrace) {
      debugPrint('Voice playback pause failed: $error\n$stackTrace');
      if (identical(player, _player)) {
        _markUnavailable();
      }
    }
  }

  static bool _endsPlayback(
    AudioPlaybackState previous,
    AudioPlaybackState next,
  ) => switch (next) {
    AudioPlaybackState.completed || AudioPlaybackState.error => true,
    AudioPlaybackState.paused ||
    AudioPlaybackState.idle => previous == AudioPlaybackState.playing,
    AudioPlaybackState.playing || AudioPlaybackState.loading => false,
  };
}
