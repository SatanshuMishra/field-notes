import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_player_impl.dart';

const int _playerId = 31;
const Size _portrait = Size(1080, 1920);

class _QuarterTurnedVideoPlatform extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async => _playerId;

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async =>
      _playerId;

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream<VideoEvent>.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      size: _portrait,
      duration: const Duration(seconds: 10),
      rotationCorrection: 90,
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

Future<VideoPlayerEntryPlayer> _loadedQuarterTurnedPlayer(
  WidgetTester tester,
) async {
  final VideoPlayerPlatform previous = VideoPlayerPlatform.instance;
  VideoPlayerPlatform.instance = _QuarterTurnedVideoPlatform();
  addTearDown(() => VideoPlayerPlatform.instance = previous);
  final VideoPlayerEntryPlayer player = VideoPlayerEntryPlayer();
  addTearDown(() => tester.runAsync(player.dispose));
  await tester.runAsync(
    () => player.load('/tmp/field_notes_upright_probe.mp4'),
  );
  return player;
}

typedef _Case = ({
  String name,
  bool hasError,
  bool isInitialized,
  bool isCompleted,
  bool isPlaying,
  VideoPlaybackState current,
  VideoPlaybackState expected,
});

void main() {
  group('videoStateFromValue', () {
    const List<_Case> cases = <_Case>[
      (
        name: 'maps a finished video to completed rather than paused',
        hasError: false,
        isInitialized: true,
        isCompleted: true,
        isPlaying: false,
        current: VideoPlaybackState.playing,
        expected: VideoPlaybackState.completed,
      ),
      (
        name: 'maps a seek to the end during playback to playing',
        hasError: false,
        isInitialized: true,
        isCompleted: true,
        isPlaying: true,
        current: VideoPlaybackState.playing,
        expected: VideoPlaybackState.playing,
      ),
      (
        name: 'maps a seek to the end while paused to completed',
        hasError: false,
        isInitialized: true,
        isCompleted: true,
        isPlaying: false,
        current: VideoPlaybackState.paused,
        expected: VideoPlaybackState.completed,
      ),
      (
        name: 'maps an error over a completed video',
        hasError: true,
        isInitialized: true,
        isCompleted: true,
        isPlaying: false,
        current: VideoPlaybackState.completed,
        expected: VideoPlaybackState.error,
      ),
      (
        name: 'maps an error over a playing video',
        hasError: true,
        isInitialized: true,
        isCompleted: false,
        isPlaying: true,
        current: VideoPlaybackState.playing,
        expected: VideoPlaybackState.error,
      ),
      (
        name: 'maps an error raised before initialization',
        hasError: true,
        isInitialized: false,
        isCompleted: false,
        isPlaying: false,
        current: VideoPlaybackState.loading,
        expected: VideoPlaybackState.error,
      ),
      (
        name: 'leaves loading untouched until the controller initializes',
        hasError: false,
        isInitialized: false,
        isCompleted: false,
        isPlaying: false,
        current: VideoPlaybackState.loading,
        expected: VideoPlaybackState.loading,
      ),
      (
        name: 'leaves idle untouched until the controller initializes',
        hasError: false,
        isInitialized: false,
        isCompleted: false,
        isPlaying: true,
        current: VideoPlaybackState.idle,
        expected: VideoPlaybackState.idle,
      ),
      (
        name: 'maps an initialized playing video to playing',
        hasError: false,
        isInitialized: true,
        isCompleted: false,
        isPlaying: true,
        current: VideoPlaybackState.ready,
        expected: VideoPlaybackState.playing,
      ),
      (
        name: 'maps an initialized idle video to paused',
        hasError: false,
        isInitialized: true,
        isCompleted: false,
        isPlaying: false,
        current: VideoPlaybackState.playing,
        expected: VideoPlaybackState.paused,
      ),
      (
        name: 'maps a replay after completion back to playing',
        hasError: false,
        isInitialized: true,
        isCompleted: false,
        isPlaying: true,
        current: VideoPlaybackState.completed,
        expected: VideoPlaybackState.playing,
      ),
      (
        name: 'maps a seek away from the end back to paused',
        hasError: false,
        isInitialized: true,
        isCompleted: false,
        isPlaying: false,
        current: VideoPlaybackState.completed,
        expected: VideoPlaybackState.paused,
      ),
    ];

    for (final _Case testCase in cases) {
      test(testCase.name, () {
        expect(
          videoStateFromValue(
            hasError: testCase.hasError,
            isInitialized: testCase.isInitialized,
            isCompleted: testCase.isCompleted,
            isPlaying: testCase.isPlaying,
            current: testCase.current,
          ),
          testCase.expected,
        );
      });
    }
  });

  testWidgets('the surface is sized upright and never cropped', (
    WidgetTester tester,
  ) async {
    final VideoPlayerEntryPlayer player = await _loadedQuarterTurnedPlayer(
      tester,
    );

    final Widget surface = player.buildSurface();
    expect(surface, isA<FittedBox>());
    final FittedBox fitted = surface as FittedBox;
    expect(fitted.fit, BoxFit.contain);
    expect(fitted.clipBehavior, Clip.none);
    final SizedBox frame = fitted.child! as SizedBox;
    expect(Size(frame.width!, frame.height!), _portrait);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(width: 400, height: 400, child: surface)),
      ),
    );

    expect(
      tester.renderObject<RenderBox>(find.byType(VideoPlayer)).size,
      _portrait,
    );
    final Rect shown = tester.getRect(find.byType(VideoPlayer));
    expect(shown.height, closeTo(400, 0.01));
    expect(shown.width, closeTo(400 * 1080 / 1920, 0.01));
    expect(shown.center.dx, closeTo(400, 0.01));
    expect(shown.center.dy, closeTo(300, 0.01));
  });

  testWidgets('the player reports its upright size once loaded', (
    WidgetTester tester,
  ) async {
    final VideoPlayerEntryPlayer player = await _loadedQuarterTurnedPlayer(
      tester,
    );

    expect(player.uprightSize, _portrait);
  });
}
