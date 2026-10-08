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
  Future<void> setVolume(double volume);
  Duration? get duration;
  Size? get uprightSize;
  Stream<Duration> get positionStream;
  Widget buildSurface();
  VideoPlaybackState get state;
  Stream<VideoPlaybackState> get stateStream;
  Future<void> dispose();
}

typedef EntryVideoPlayerFactory = EntryVideoPlayer Function();
