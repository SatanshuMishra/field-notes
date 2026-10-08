import 'dart:io';

import 'package:field_notes/data/media/media_probe.dart';
import 'package:field_notes/domain/models/media_kind.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

const int _playerId = 23;

class _RotatedVideoPlatform extends VideoPlayerPlatform {
  _RotatedVideoPlatform({required this.size});

  final Size size;
  final List<int> disposedPlayers = <int>[];

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async =>
      _playerId;

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream<VideoEvent>.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      size: size,
      duration: const Duration(milliseconds: 6400),
      rotationCorrection: 90,
    ),
  );

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> dispose(int playerId) async => disposedPlayers.add(playerId);
}

Future<MediaMeasure?> _measure(
  WidgetTester tester,
  _RotatedVideoPlatform platform,
) async {
  final VideoPlayerPlatform previous = VideoPlayerPlatform.instance;
  VideoPlayerPlatform.instance = platform;
  addTearDown(() => VideoPlayerPlatform.instance = previous);
  return tester.runAsync<MediaMeasure?>(
    () => const PlatformMediaProbe().measure(
      file: File('portrait.mp4'),
      kind: MediaKind.video,
    ),
  );
}

void main() {
  testWidgets('a rotated frame stores its upright size', (
    WidgetTester tester,
  ) async {
    final _RotatedVideoPlatform platform = _RotatedVideoPlatform(
      size: const Size(1079.6, 1920.4),
    );

    final MediaMeasure? measured = await _measure(tester, platform);

    expect(
      measured,
      const MediaMeasure(
        duration: Duration(milliseconds: 6400),
        width: 1080,
        height: 1920,
      ),
    );
    expect(platform.disposedPlayers, <int>[_playerId]);
  });

  testWidgets('a video without a frame size stores no size', (
    WidgetTester tester,
  ) async {
    final MediaMeasure? measured = await _measure(
      tester,
      _RotatedVideoPlatform(size: Size.zero),
    );

    expect(
      measured,
      const MediaMeasure(duration: Duration(milliseconds: 6400)),
    );
  });
}
