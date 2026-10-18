import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _justAudioSources =
    'third_party/just_audio/darwin/just_audio/Sources/just_audio';
const String _videoPlayerSources =
    'third_party/video_player_avfoundation/darwin/video_player_avfoundation/Sources';
const String _audioplayersSources =
    'third_party/audioplayers_darwin/darwin/audioplayers_darwin/Sources/audioplayers_darwin';

String _read(String path) => File(path).readAsStringSync();

String _handler(String source, String channel) {
  final int start = source.indexOf(channel);
  expect(start, isNot(-1), reason: '$channel is not registered');
  final int end = source.indexOf('FlutterMethodNotImplemented', start);
  expect(end, isNot(-1), reason: '$channel handler has no fallback');
  return source.substring(start, end);
}

void _expectGuarded(String source, RegExp guarded, String reason) {
  expect(guarded.hasMatch(source), isTrue, reason: reason);
}

void main() {
  test('macOS players set the output device', () {
    final String justAudioPlugin = _read(
      '$_justAudioSources/JustAudioPlugin.m',
    );
    final String justAudioPlayer = _read('$_justAudioSources/AudioPlayer.m');
    final String justAudioHandler = _handler(
      justAudioPlugin,
      '@"field_notes/output_route/just_audio"',
    );
    expect(
      justAudioHandler,
      contains('[@"setPreferredOutputDevice" isEqualToString:call.method]'),
    );
    expect(
      justAudioHandler,
      contains(
        '[weakInstance routePlayersToOutputDevice:_preferredOutputDeviceId];',
      ),
      reason: 'just_audio does not route the players it owns',
    );
    expect(
      justAudioPlugin,
      contains(
        '- (void)routePlayersToOutputDevice:(NSString *)deviceId {\n'
        '    for (AudioPlayer *player in [_players allValues]) {\n'
        '        [player applyOutputDeviceUniqueID:deviceId];\n'
        '    }\n'
        '}\n',
      ),
      reason: 'just_audio does not reach every player',
    );
    expect(
      justAudioPlayer,
      contains(
        '        _player = [[AVQueuePlayer alloc] initWithItems:@[]];\n'
        '        [self applyOutputDeviceUniqueID:[JustAudioPlugin preferredOutputDeviceId]];\n',
      ),
      reason: 'a new just_audio AVQueuePlayer is not routed',
    );
    _expectGuarded(
      justAudioPlayer,
      RegExp(
        r'- \(void\)applyOutputDeviceUniqueID:\(NSString \*\)deviceId \{\s*'
        r'#if TARGET_OS_OSX\s*'
        r'_player\.audioOutputDeviceUniqueID = deviceId;\s*'
        r'#endif\s*\}',
      ),
      'just_audio does not set audioOutputDeviceUniqueID on macOS',
    );

    final String videoPlugin = _read(
      '$_videoPlayerSources/video_player_avfoundation/VideoPlayerPlugin.swift',
    );
    final String videoHandler = _handler(
      videoPlugin,
      '"field_notes/output_route/video_player_avfoundation"',
    );
    expect(videoHandler, contains('[weak instance] call, result in'));
    expect(
      videoHandler,
      contains('if call.method == "setPreferredOutputDevice" {'),
    );
    expect(
      videoHandler,
      contains(
        'FieldNotesOutputRoute.preferredDeviceId = arguments?["id"] as? String\n'
        '        instance?.routePlayersToPreferredOutputDevice()\n',
      ),
      reason: 'video_player_avfoundation does not route the players it owns',
    );
    expect(
      videoPlugin,
      contains(
        '  func routePlayersToPreferredOutputDevice() {\n'
        '    playersByIdentifier.values.forEach(routeToPreferredOutputDevice)\n'
        '  }\n',
      ),
      reason: 'video_player_avfoundation does not reach every player',
    );
    expect(
      videoPlugin,
      contains(
        '    playersByIdentifier[playerId] = player\n'
        '    routeToPreferredOutputDevice(player)\n',
      ),
      reason: 'a new video_player_avfoundation AVPlayer is not routed',
    );
    expect(
      _read(
        '$_videoPlayerSources/video_player_avfoundation_objc/FVPVideoPlayer.m',
      ),
      contains('_player = [avFactory playerWithPlayerItem:item];'),
      reason: 'the routed AVPlayer is not the one FVPAVFactory creates',
    );
    _expectGuarded(
      videoPlugin,
      RegExp(
        r'private func routeToPreferredOutputDevice\(_ player: FVPVideoPlayer\) \{\s*'
        r'#if os\(macOS\)\s*'
        r'player\.player\.audioOutputDeviceUniqueID = FieldNotesOutputRoute\.preferredDeviceId\s*'
        r'#endif\s*\}',
      ),
      'video_player_avfoundation does not set audioOutputDeviceUniqueID on macOS',
    );

    final String audioplayersPlugin = _read(
      '$_audioplayersSources/AudioplayersDarwinPlugin.swift',
    );
    final String wrappedPlayer = _read(
      '$_audioplayersSources/WrappedMediaPlayer.swift',
    );
    final String audioplayersHandler = _handler(
      audioplayersPlugin,
      '"field_notes/output_route/audioplayers_darwin"',
    );
    expect(audioplayersHandler, contains('[weak instance] call, result in'));
    expect(
      audioplayersHandler,
      contains('if call.method == "setPreferredOutputDevice" {'),
    );
    expect(
      audioplayersHandler,
      contains(
        '          FieldNotesOutputRoute.preferredDeviceId = deviceId\n'
        '          instance?.routePlayers(toOutputDevice: deviceId)\n',
      ),
      reason: 'audioplayers_darwin does not route the players it owns',
    );
    expect(
      audioplayersPlugin,
      contains(
        '  func routePlayers(toOutputDevice deviceId: String?) {\n'
        '    for player in players.values {\n'
        '      player.setOutputDevice(deviceId)\n'
        '    }\n'
        '  }\n',
      ),
      reason: 'audioplayers_darwin does not reach every player',
    );
    expect(
      wrappedPlayer,
      contains(
        '    self.url = url\n'
        '    setOutputDevice(FieldNotesOutputRoute.preferredDeviceId)\n'
        '  }\n',
      ),
      reason: 'a new audioplayers_darwin AVPlayer is not routed',
    );
    _expectGuarded(
      wrappedPlayer,
      RegExp(
        r'func setOutputDevice\(_ deviceId: String\?\) \{\s*'
        r'#if os\(macOS\)\s*'
        r'player\.audioOutputDeviceUniqueID = deviceId\s*'
        r'#endif\s*\}',
      ),
      'audioplayers_darwin does not set audioOutputDeviceUniqueID on macOS',
    );
  });
}
