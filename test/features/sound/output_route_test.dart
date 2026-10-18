import 'package:audioplayers/audioplayers.dart' as audioplayers;
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/entry_cards/playback/just_audio_player.dart';
import 'package:field_notes/features/entry_cards/playback/video_player_impl.dart';
import 'package:field_notes/features/sound/audioplayers_sound_player.dart';
import 'package:field_notes/features/sound/output_route.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../settings/support/fake_settings_repository.dart';

const int _videoPlayerId = 7;

const List<String> _outputRouteChannels = <String>[
  'field_notes/output_route/just_audio',
  'field_notes/output_route/just_audio_windows',
  'field_notes/output_route/video_player_avfoundation',
  'field_notes/output_route/video_player_android',
  'field_notes/output_route/video_player_win',
  'field_notes/output_route/audioplayers_darwin',
  'field_notes/output_route/audioplayers_android',
  'field_notes/output_route/audioplayers_windows',
];

class _FakeVoicePlayer extends Fake implements just_audio.AudioPlayer {
  double _volume = 1.0;
  bool started = false;

  @override
  double get volume => _volume;

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
  }

  @override
  Future<void> play() async {
    started = true;
  }

  @override
  Future<void> dispose() async {}
}

class _FakeSoundPlayer extends Fake implements audioplayers.AudioPlayer {
  double _volume = 1.0;

  @override
  double get volume => _volume;

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
  }

  @override
  Future<void> dispose() async {}
}

class _VolumeVideoPlatform extends VideoPlayerPlatform {
  final List<double> volumes = <double>[];

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async => _videoPlayerId;

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async =>
      _videoPlayerId;

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
  Future<void> setVolume(int playerId, double volume) async {
    volumes.add(volume);
  }

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

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump();
  }
}

ProviderContainer _startRouteSync(
  WidgetTester tester,
  FakeSettingsRepository settings,
) {
  addTearDown(() => playbackVolume.value = 1.0);
  final ProviderContainer container = ProviderContainer(
    overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
  );
  addTearDown(container.dispose);
  container.read(outputRouteSyncProvider);
  return container;
}

Map<String, List<Object?>> _recordOutputRoutes(WidgetTester tester) {
  final Map<String, List<Object?>> routes = <String, List<Object?>>{
    for (final String channel in _outputRouteChannels) channel: <Object?>[],
  };
  for (final String channel in _outputRouteChannels) {
    final MethodChannel methodChannel = MethodChannel(channel);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      methodChannel,
      (MethodCall call) async {
        if (call.method == 'setPreferredOutputDevice') {
          routes[channel]!.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        methodChannel,
        null,
      ),
    );
  }
  return routes;
}

void _listOutputsAandB(WidgetTester tester) {
  const MethodChannel outputs = MethodChannel('field_notes/audio_output');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(outputs, (
    MethodCall call,
  ) async {
    if (call.method == 'listOutputs') {
      return <Object?>[
        <String, Object?>{'id': 'a', 'name': 'Desk speakers'},
        <String, Object?>{'id': 'b', 'name': 'Headphones'},
      ];
    }
    return null;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      outputs,
      null,
    ),
  );
}

void main() {
  testWidgets('players take the output volume', (WidgetTester tester) async {
    _startRouteSync(
      tester,
      FakeSettingsRepository(
        initial: AppSettings.defaults.copyWith(outputVolume: 40),
      ),
    );
    await _settle(tester);

    final _FakeVoicePlayer voice = _FakeVoicePlayer();
    final JustAudioEntryPlayer voicePlayer = JustAudioEntryPlayer(
      player: voice,
    );
    addTearDown(voicePlayer.dispose);
    final _FakeSoundPlayer sound = _FakeSoundPlayer();
    final AudioPlayersSoundPlayer soundPlayer = AudioPlayersSoundPlayer(
      player: sound,
    );
    addTearDown(soundPlayer.dispose);
    final VideoPlayerPlatform previousVideo = VideoPlayerPlatform.instance;
    final _VolumeVideoPlatform video = _VolumeVideoPlatform();
    VideoPlayerPlatform.instance = video;
    addTearDown(() => VideoPlayerPlatform.instance = previousVideo);
    final VideoPlayerEntryPlayer videoPlayer = VideoPlayerEntryPlayer();
    addTearDown(() => tester.runAsync(videoPlayer.dispose));
    await tester.runAsync(
      () => videoPlayer.load('/tmp/field_notes_output_volume_probe.mp4'),
    );
    await _settle(tester);

    expect(voice.volume, 0.4);
    expect(sound.volume, 0.4);
    expect(video.volumes, isNotEmpty);
    expect(video.volumes.last, 0.4);
  });

  testWidgets('a volume change reaches live players', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository settings = FakeSettingsRepository();
    _startRouteSync(tester, settings);
    await _settle(tester);
    final _FakeVoicePlayer voice = _FakeVoicePlayer();
    final JustAudioEntryPlayer voicePlayer = JustAudioEntryPlayer(
      player: voice,
    );
    addTearDown(voicePlayer.dispose);
    await voicePlayer.play();
    expect(voice.started, isTrue);

    await settings.setOutputVolume(70);
    await _settle(tester);

    expect(voice.volume, 0.7);
  });

  testWidgets('the chosen output reaches every macOS package', (
    WidgetTester tester,
  ) async {
    final Map<String, List<Object?>> routes = _recordOutputRoutes(tester);
    _listOutputsAandB(tester);
    _startRouteSync(
      tester,
      FakeSettingsRepository(
        initial: AppSettings.defaults.copyWith(audioOutputId: 'b'),
      ),
    );
    await _settle(tester);

    expect(routes, <String, List<Object?>>{
      'field_notes/output_route/just_audio': <Object?>[
        <String, Object?>{'id': 'b'},
      ],
      'field_notes/output_route/just_audio_windows': <Object?>[],
      'field_notes/output_route/video_player_avfoundation': <Object?>[
        <String, Object?>{'id': 'b'},
      ],
      'field_notes/output_route/video_player_android': <Object?>[],
      'field_notes/output_route/video_player_win': <Object?>[],
      'field_notes/output_route/audioplayers_darwin': <Object?>[
        <String, Object?>{'id': 'b'},
      ],
      'field_notes/output_route/audioplayers_android': <Object?>[],
      'field_notes/output_route/audioplayers_windows': <Object?>[],
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('the chosen output reaches every Windows package', (
    WidgetTester tester,
  ) async {
    final Map<String, List<Object?>> routes = _recordOutputRoutes(tester);
    _listOutputsAandB(tester);
    _startRouteSync(
      tester,
      FakeSettingsRepository(
        initial: AppSettings.defaults.copyWith(audioOutputId: 'b'),
      ),
    );
    await _settle(tester);

    expect(routes, <String, List<Object?>>{
      'field_notes/output_route/just_audio': <Object?>[],
      'field_notes/output_route/just_audio_windows': <Object?>[
        <String, Object?>{'id': 'b'},
      ],
      'field_notes/output_route/video_player_avfoundation': <Object?>[],
      'field_notes/output_route/video_player_android': <Object?>[],
      'field_notes/output_route/video_player_win': <Object?>[
        <String, Object?>{'id': 'b'},
      ],
      'field_notes/output_route/audioplayers_darwin': <Object?>[],
      'field_notes/output_route/audioplayers_android': <Object?>[],
      'field_notes/output_route/audioplayers_windows': <Object?>[
        <String, Object?>{'id': 'b'},
      ],
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('the chosen output reaches every Android package', (
    WidgetTester tester,
  ) async {
    final Map<String, List<Object?>> routes = _recordOutputRoutes(tester);
    _listOutputsAandB(tester);
    _startRouteSync(
      tester,
      FakeSettingsRepository(
        initial: AppSettings.defaults.copyWith(audioOutputId: 'b'),
      ),
    );
    await _settle(tester);

    expect(routes, <String, List<Object?>>{
      'field_notes/output_route/just_audio': <Object?>[
        <String, Object?>{'id': 'b'},
      ],
      'field_notes/output_route/just_audio_windows': <Object?>[],
      'field_notes/output_route/video_player_avfoundation': <Object?>[],
      'field_notes/output_route/video_player_android': <Object?>[
        <String, Object?>{'id': 'b'},
      ],
      'field_notes/output_route/video_player_win': <Object?>[],
      'field_notes/output_route/audioplayers_darwin': <Object?>[],
      'field_notes/output_route/audioplayers_android': <Object?>[
        <String, Object?>{'id': 'b'},
      ],
      'field_notes/output_route/audioplayers_windows': <Object?>[],
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
