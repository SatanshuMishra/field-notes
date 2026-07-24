import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart' as vp;

import 'video_playback.dart';

class VideoPlayerEntryPlayer implements EntryVideoPlayer {
  VideoPlayerEntryPlayer();

  vp.VideoPlayerController? _controller;
  final StreamController<VideoPlaybackState> _stateController =
      StreamController<VideoPlaybackState>.broadcast();
  VideoPlaybackState _state = VideoPlaybackState.idle;

  @override
  VideoPlaybackState get state => _state;

  @override
  Stream<VideoPlaybackState> get stateStream => _stateController.stream;

  @override
  Future<void> load(String filePath) async {
    _setState(VideoPlaybackState.loading);
    final vp.VideoPlayerController controller =
        vp.VideoPlayerController.file(File(filePath));
    _controller = controller;
    controller.addListener(_onValue);
    try {
      await controller.initialize();
      _setState(VideoPlaybackState.ready);
    } catch (_) {
      _setState(VideoPlaybackState.error);
      rethrow;
    }
  }

  void _onValue() {
    final vp.VideoPlayerController? controller = _controller;
    if (controller == null) {
      return;
    }
    if (controller.value.hasError) {
      debugPrint(
        'Video controller reported an error: '
        '${controller.value.errorDescription}',
      );
      _setState(VideoPlaybackState.error);
      return;
    }
    if (!controller.value.isInitialized) {
      return;
    }
    _setState(
      controller.value.isPlaying
          ? VideoPlaybackState.playing
          : VideoPlaybackState.paused,
    );
  }

  @override
  Future<void> play() async {
    await _controller?.play();
  }

  @override
  Future<void> pause() async {
    await _controller?.pause();
  }

  @override
  Widget buildSurface() {
    final vp.VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: vp.VideoPlayer(controller),
    );
  }

  @override
  Future<void> dispose() async {
    _controller?.removeListener(_onValue);
    await _controller?.dispose();
    await _stateController.close();
  }

  void _setState(VideoPlaybackState state) {
    _state = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }
}

EntryVideoPlayer createVideoPlayerEntryPlayer() => VideoPlayerEntryPlayer();
