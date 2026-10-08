import 'dart:io';

import 'package:field_notes/data/media/media_probe.dart';
import 'package:field_notes/domain/models/media_kind.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

const int _playerId = 23;

class _RotatedVideoPlatform extends VideoPlayerPlatform {
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
      size: const Size(1920.4, 1079.6),
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

void main() {
  test('a rotated frame stores its upright size', () {
    const Size landscape = Size(1920, 1080);
    const Size portrait = Size(1080, 1920);

    expect(uprightSizeOf(landscape, 90), portrait);
    expect(uprightSizeOf(landscape, 270), portrait);
    expect(uprightSizeOf(landscape, 0), landscape);
    expect(uprightSizeOf(landscape, 180), landscape);
    expect(uprightSizeOf(landscape, -90), portrait);
    expect(uprightSizeOf(landscape, 450), portrait);
    expect(uprightSizeOf(Size.zero, 0), isNull);
    expect(uprightSizeOf(Size.zero, 90), isNull);
    expect(uprightSizeOf(const Size(1920, 0), 0), isNull);
    expect(uprightSizeOf(const Size(double.infinity, 1080), 0), isNull);
    expect(uprightSizeOf(const Size(double.nan, 1080), 90), isNull);
  });

  testWidgets(
    'the platform probe measures a rotated video upright and releases it',
    (WidgetTester tester) async {
      final VideoPlayerPlatform previous = VideoPlayerPlatform.instance;
      final _RotatedVideoPlatform platform = _RotatedVideoPlatform();
      VideoPlayerPlatform.instance = platform;
      addTearDown(() => VideoPlayerPlatform.instance = previous);

      final MediaMeasure? measured = await tester.runAsync<MediaMeasure?>(
        () => const PlatformMediaProbe().measure(
          file: File('portrait.mp4'),
          kind: MediaKind.video,
        ),
      );

      expect(
        measured,
        const MediaMeasure(
          duration: Duration(milliseconds: 6400),
          width: 1080,
          height: 1920,
        ),
      );
      expect(platform.disposedPlayers, <int>[_playerId]);
    },
  );
}
