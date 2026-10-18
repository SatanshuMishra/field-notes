import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _justAudioSources =
    'third_party/just_audio/android/src/main/java/com/ryanheise/just_audio';
const String _videoPlayerSources =
    'third_party/video_player_android/android/src/main/java/io/flutter/plugins/videoplayer';
const String _audioplayersSources =
    'third_party/audioplayers_android/android/src/main/kotlin/xyz/luan/audioplayers';

String _read(String path) => File(path).readAsStringSync();

String _handler(String source, String channel, String fallback) {
  final int start = source.indexOf(channel);
  expect(start, isNot(-1), reason: '$channel is not registered');
  final int end = source.indexOf(fallback, start);
  expect(end, isNot(-1), reason: '$channel handler has no fallback');
  return source.substring(start, end);
}

void _expectResolvesTheOutputId(String source, String package) {
  expect(
    source,
    contains('AudioManager.GET_DEVICES_OUTPUTS'),
    reason: '$package does not search the output devices',
  );
  expect(
    RegExp(
      r'device\.getType\(\) \+ ":" \+ device\.getProductName\(\)|'
      r'"\$\{device\.type\}:\$\{device\.productName\}"',
    ).hasMatch(source),
    isTrue,
    reason: '$package does not build the type and product name id',
  );
  expect(
    RegExp(
      r'Build\.VERSION\.SDK_INT >= Build\.VERSION_CODES\.P(\) | \? )'
      r'device\.(getAddress\(\)|address\.orEmpty\(\))',
    ).hasMatch(source),
    isTrue,
    reason: '$package does not add the address from API 28',
  );
  expect(
    RegExp(r'base \+ ":" \+ address|"\$base:\$address"').hasMatch(source),
    isTrue,
    reason: '$package does not append a non-empty address',
  );
}

void main() {
  test('Android players set the preferred device', () {
    final String justAudioPlugin = _read(
      '$_justAudioSources/JustAudioPlugin.java',
    );
    final String justAudioHandler = _read(
      '$_justAudioSources/MainMethodCallHandler.java',
    );
    final String justAudioPlayer = _read('$_justAudioSources/AudioPlayer.java');
    final String justAudioRoute = _handler(
      justAudioPlugin,
      '"field_notes/output_route/just_audio"',
      'result.notImplemented();',
    );
    expect(
      justAudioRoute,
      contains('if ("setPreferredOutputDevice".equals(call.method)) {'),
    );
    expect(
      justAudioRoute,
      contains(
        'methodCallHandler.routePlayersToOutputDevice(preferredOutputDeviceId);',
      ),
      reason: 'just_audio does not route the players it owns',
    );
    expect(
      justAudioHandler,
      contains(
        '    void routePlayersToOutputDevice(String deviceId) {\n'
        '        for (AudioPlayer player : players.values()) {\n'
        '            player.applyPreferredOutputDevice(deviceId);\n'
        '        }\n'
        '    }\n',
      ),
      reason: 'just_audio does not reach every player',
    );
    expect(
      justAudioPlayer,
      contains(
        '            player.addListener(this);\n'
        '            applyPreferredOutputDevice(JustAudioPlugin.getPreferredOutputDeviceId());\n',
      ),
      reason: 'a new just_audio ExoPlayer is not routed',
    );
    expect(
      justAudioPlayer,
      contains(
        '    @OptIn(markerClass = UnstableApi.class)\n'
        '    void applyPreferredOutputDevice(String deviceId) {\n'
        '        if (player != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {\n'
        '            player.setPreferredAudioDevice(PreferredOutputDevice.find(context, deviceId));\n'
        '        }\n'
        '    }\n',
      ),
      reason: 'just_audio does not call setPreferredAudioDevice',
    );
    _expectResolvesTheOutputId(
      _read('$_justAudioSources/PreferredOutputDevice.java'),
      'just_audio',
    );

    final String videoPlugin = _read(
      '$_videoPlayerSources/VideoPlayerPlugin.java',
    );
    final String videoRoute = _handler(
      videoPlugin,
      '"field_notes/output_route/video_player_android"',
      'result.notImplemented();',
    );
    expect(
      videoRoute,
      contains('if ("setPreferredOutputDevice".equals(call.method)) {'),
    );
    expect(
      videoRoute,
      contains('routePlayersToPreferredOutputDevice();'),
      reason: 'video_player_android does not route the players it owns',
    );
    expect(
      videoPlugin,
      contains(
        '  private void routePlayersToPreferredOutputDevice() {\n'
        '    for (int i = 0; i < videoPlayers.size(); i++) {\n'
        '      routeToPreferredOutputDevice(videoPlayers.valueAt(i));\n'
        '    }\n'
        '  }\n',
      ),
      reason: 'video_player_android does not reach every player',
    );
    expect(
      videoPlugin,
      contains(
        '    videoPlayers.put(id, player);\n'
        '    routeToPreferredOutputDevice(player);\n',
      ),
      reason: 'a new video_player_android ExoPlayer is not routed',
    );
    expect(
      RegExp(
        r'VideoPlayer videoPlayer =\s*TextureVideoPlayer\.create\([\s\S]*?\);\s*'
        r'registerPlayerInstance\(videoPlayer, id\);',
      ).hasMatch(videoPlugin),
      isTrue,
      reason: 'the texture player is not registered and routed',
    );
    expect(
      RegExp(
        r'VideoPlayer videoPlayer =\s*PlatformViewVideoPlayer\.create\([\s\S]*?\);\s*'
        r'registerPlayerInstance\(videoPlayer, id\);',
      ).hasMatch(videoPlugin),
      isTrue,
      reason: 'the platform view player is not registered and routed',
    );
    expect(
      RegExp(
        r'@OptIn\(markerClass = UnstableApi\.class\)\s*'
        r'private void routeToPreferredOutputDevice\(@NonNull VideoPlayer player\) \{[\s\S]*?'
        r'player\s*\.getExoPlayer\(\)\s*'
        r'\.setPreferredAudioDevice\(\s*'
        r'PreferredOutputDevice\.find\(flutterState\.applicationContext, preferredOutputDeviceId\)\);',
      ).hasMatch(videoPlugin),
      isTrue,
      reason: 'video_player_android does not call setPreferredAudioDevice',
    );
    _expectResolvesTheOutputId(
      _read('$_videoPlayerSources/PreferredOutputDevice.java'),
      'video_player_android',
    );

    final String audioplayersPlugin = _read(
      '$_audioplayersSources/AudioplayersPlugin.kt',
    );
    final String wrappedPlayer = _read(
      '$_audioplayersSources/player/WrappedPlayer.kt',
    );
    final String mediaPlayerWrapper = _read(
      '$_audioplayersSources/player/MediaPlayerWrapper.kt',
    );
    final String audioplayersRoute = _handler(
      audioplayersPlugin,
      '"field_notes/output_route/audioplayers_android"',
      'response.notImplemented()',
    );
    expect(
      audioplayersRoute,
      contains('if (call.method == "setPreferredOutputDevice") {'),
    );
    expect(
      audioplayersRoute,
      contains(
        '                preferredOutputDeviceId = deviceId\n'
        '                players.values.forEach { it.setPreferredOutputDevice(deviceId) }\n',
      ),
      reason: 'audioplayers_android does not route the players it owns',
    );
    expect(
      wrappedPlayer,
      contains(
        '    fun setPreferredOutputDevice(deviceId: String?) {\n'
        '        (player as? MediaPlayerWrapper)?.setPreferredOutputDevice(deviceId)\n'
        '    }\n',
      ),
      reason: 'audioplayers_android does not reach the MediaPlayer',
    );
    expect(
      mediaPlayerWrapper,
      contains(
        '        source.setForMediaPlayer(mediaPlayer)\n'
        '        setPreferredOutputDevice(AudioplayersPlugin.preferredOutputDeviceId)\n',
      ),
      reason: 'a new audioplayers_android source is not routed',
    );
    expect(
      mediaPlayerWrapper,
      contains(
        '    fun setPreferredOutputDevice(deviceId: String?) {\n'
        '        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {\n'
        '            mediaPlayer.setPreferredDevice(PreferredOutputDevice.find(wrappedPlayer.applicationContext, deviceId))\n'
        '        }\n'
        '    }\n',
      ),
      reason:
          'audioplayers_android does not call setPreferredDevice from API 28',
    );
    _expectResolvesTheOutputId(
      _read('$_audioplayersSources/player/PreferredOutputDevice.kt'),
      'audioplayers_android',
    );
  });
}
