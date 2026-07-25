import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:field_notes/features/entry_cards/playback/video_playback.dart';

class FakeEntryVideoPlayer implements EntryVideoPlayer {
  final StreamController<VideoPlaybackState> _stateController =
      StreamController<VideoPlaybackState>.broadcast(sync: true);
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast(sync: true);

  final List<String> loadCalls = <String>[];
  final List<Duration> seekCalls = <Duration>[];
  final List<double> volumeCalls = <double>[];
  int playCalls = 0;
  int pauseCalls = 0;
  VideoPlaybackState _state = VideoPlaybackState.idle;

  void emitState(VideoPlaybackState state) {
    _state = state;
    _stateController.add(state);
  }

  void emitPosition(Duration position) => _positionController.add(position);

  @override
  Future<void> load(String filePath) async => loadCalls.add(filePath);

  @override
  Future<void> play() async => playCalls++;

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> seek(Duration position) async => seekCalls.add(position);

  @override
  Future<void> setVolume(double volume) async => volumeCalls.add(volume);

  @override
  Duration? duration;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Widget buildSurface() => const SizedBox(
        key: ValueKey<String>('fake-video-surface'),
        width: 160,
        height: 90,
      );

  @override
  VideoPlaybackState get state => _state;

  @override
  Stream<VideoPlaybackState> get stateStream => _stateController.stream;

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await _positionController.close();
  }
}
