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
  int disposeCalls = 0;
  Object? seekError;
  Object? loadError;
  Completer<void>? loadGate;
  VideoPlaybackState _state = VideoPlaybackState.idle;

  void emitState(VideoPlaybackState state) {
    _state = state;
    _stateController.add(state);
  }

  void emitPosition(Duration position) => _positionController.add(position);

  void emitStateError(Object error) =>
      _stateController.addError(error, StackTrace.empty);

  void emitPositionError(Object error) =>
      _positionController.addError(error, StackTrace.empty);

  @override
  Future<void> load(String filePath) async {
    loadCalls.add(filePath);
    final Completer<void>? gate = loadGate;
    if (gate != null) {
      await gate.future;
    }
    final Object? error = loadError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> play() async => playCalls++;

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> seek(Duration position) async {
    final Object? error = seekError;
    if (error != null) {
      throw error;
    }
    seekCalls.add(position);
  }

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
    disposeCalls++;
    await _stateController.close();
    await _positionController.close();
  }
}
