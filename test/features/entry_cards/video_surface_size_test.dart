import 'package:field_notes/features/entry_cards/playback/video_player_impl.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

const int _textureId = 7;

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async => _textureId;

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async =>
      _textureId;

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream<VideoEvent>.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      size: const Size(1920, 1080),
      duration: const Duration(seconds: 10),
    ),
  );

  @override
  Widget buildView(int playerId) => Texture(textureId: playerId);

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      Texture(textureId: options.playerId);

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
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> dispose(int playerId) async {}
}

void main() {
  testWidgets('the video surface is laid out at the video natural size', (
    tester,
  ) async {
    VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform();
    final VideoPlayerEntryPlayer player = VideoPlayerEntryPlayer();
    addTearDown(() => tester.runAsync(player.dispose));

    await tester.runAsync(
      () => player.load('/tmp/field_notes_surface_probe.mp4'),
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 400,
            height: 225,
            child: player.buildSurface(),
          ),
        ),
      ),
    );

    expect(
      tester.renderObject<RenderBox>(find.byType(VideoPlayer)).size,
      const Size(1920, 1080),
    );
  });
}
