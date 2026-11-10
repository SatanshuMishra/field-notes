import 'dart:async';

import 'package:flutter/widgets.dart';

enum VideoPlaybackState {
  idle,
  loading,
  ready,
  playing,
  paused,
  completed,
  error,
}

abstract interface class EntryVideoPlayer {
  Future<void> load(String filePath);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Duration? get duration;
  Size? get uprightSize;
  Stream<Duration> get positionStream;
  Widget buildSurface();
  VideoPlaybackState get state;
  Stream<VideoPlaybackState> get stateStream;
  Future<void> dispose();
}

typedef EntryVideoPlayerFactory = EntryVideoPlayer Function();

abstract interface class TunablePlayer {
  Future<void> setVolume(double volume);
  Future<void> setSpeed(double speed);
}

const List<double> playbackSpeeds = <double>[0.5, 0.75, 1, 1.25, 1.5, 2];

const double _fullVolume = 1;
const double _silence = 0;
const double _normalSpeed = 1;

final class PlaybackTuning extends ChangeNotifier {
  double _volume = _fullVolume;
  bool _muted = false;
  double _speed = _normalSpeed;

  double get volume => _volume;

  bool get muted => _muted;

  double get speed => _speed;

  double get audibleVolume => _muted ? _silence : _volume;

  void setVolume(double volume) {
    final double next = volume.clamp(_silence, _fullVolume);
    if (next == _volume && !_muted) {
      return;
    }
    _volume = next;
    _muted = false;
    notifyListeners();
  }

  void toggleMute() {
    _muted = !_muted;
    notifyListeners();
  }

  void setSpeed(double speed) {
    if (speed == _speed) {
      return;
    }
    _speed = speed;
    notifyListeners();
  }
}

final PlaybackTuning playbackTuning = PlaybackTuning();

void applyPlaybackTuning(Object? player, PlaybackTuning tuning) {
  if (player is TunablePlayer) {
    unawaited(_tune(player, tuning.audibleVolume, tuning.speed));
  }
}

Future<void> _tune(TunablePlayer player, double volume, double speed) async {
  try {
    await player.setVolume(volume);
    await player.setSpeed(speed);
  } catch (error, stackTrace) {
    debugPrint('Playback tuning failed: $error\n$stackTrace');
  }
}
