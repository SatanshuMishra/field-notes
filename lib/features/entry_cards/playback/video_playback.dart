import 'package:flutter/widgets.dart';

enum VideoPlaybackState { idle, loading, ready, playing, paused, error }

abstract interface class EntryVideoPlayer {
  Future<void> load(String filePath);
  Future<void> play();
  Future<void> pause();
  Widget buildSurface();
  VideoPlaybackState get state;
  Stream<VideoPlaybackState> get stateStream;
  Future<void> dispose();
}

typedef EntryVideoPlayerFactory = EntryVideoPlayer Function();
