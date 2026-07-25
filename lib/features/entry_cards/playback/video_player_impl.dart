import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart' as vp;

import 'video_playback.dart';

VideoPlaybackState videoStateFromValue({
  required bool hasError,
  required bool isInitialized,
  required bool isCompleted,
  required bool isPlaying,
  required VideoPlaybackState current,
}) {
  if (hasError) {
    return VideoPlaybackState.error;
  }
  if (!isInitialized) {
    return current;
  }
  if (isCompleted && !isPlaying) {
    return VideoPlaybackState.completed;
  }
  return isPlaying ? VideoPlaybackState.playing : VideoPlaybackState.paused;
}

class VideoPlayerEntryPlayer implements EntryVideoPlayer {
  VideoPlayerEntryPlayer();

  vp.VideoPlayerController? _controller;
  final StreamController<VideoPlaybackState> _stateController =
      StreamController<VideoPlaybackState>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  VideoPlaybackState _state = VideoPlaybackState.idle;
  Duration? _lastPosition;

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
    final vp.VideoPlayerValue value = controller.value;
    if (value.hasError) {
      debugPrint(
        'Video controller reported an error: ${value.errorDescription}',
      );
    }
    _setState(
      videoStateFromValue(
        hasError: value.hasError,
        isInitialized: value.isInitialized,
        isCompleted: value.isCompleted,
        isPlaying: value.isPlaying,
        current: _state,
      ),
    );
    if (value.isInitialized) {
      _emitPosition(value.position);
    }
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
  Future<void> seek(Duration position) async {
    await _controller?.seekTo(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    await _controller?.setVolume(volume.clamp(0.0, 1.0));
  }

  @override
  Duration? get duration {
    final vp.VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return null;
    }
    return controller.value.duration;
  }

  @override
  Stream<Duration> get positionStream => _positionController.stream;

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
    await _positionController.close();
  }

  void _setState(VideoPlaybackState state) {
    if (state == _state) {
      return;
    }
    _state = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void _emitPosition(Duration position) {
    if (position == _lastPosition) {
      return;
    }
    _lastPosition = position;
    if (!_positionController.isClosed) {
      _positionController.add(position);
    }
  }
}

EntryVideoPlayer createVideoPlayerEntryPlayer() => VideoPlayerEntryPlayer();
