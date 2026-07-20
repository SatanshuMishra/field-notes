import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:field_notes/features/entry_cards/playback/video_playback.dart';

class FakeEntryVideoPlayer implements EntryVideoPlayer {
  final StreamController<VideoPlaybackState> _stateController =
      StreamController<VideoPlaybackState>.broadcast(sync: true);

  final List<String> loadCalls = <String>[];
  int playCalls = 0;
  int pauseCalls = 0;
  VideoPlaybackState _state = VideoPlaybackState.idle;

  void emitState(VideoPlaybackState state) {
    _state = state;
    _stateController.add(state);
  }

  @override
  Future<void> load(String filePath) async => loadCalls.add(filePath);

  @override
  Future<void> play() async => playCalls++;

  @override
  Future<void> pause() async => pauseCalls++;

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
  Future<void> dispose() async => _stateController.close();
}
