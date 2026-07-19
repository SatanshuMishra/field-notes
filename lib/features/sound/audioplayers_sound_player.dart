import 'package:audioplayers/audioplayers.dart';

import 'sound_player.dart';

class AudioPlayersSoundPlayer implements SoundPlayer {
  AudioPlayersSoundPlayer({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play(String assetKey) => _player.play(AssetSource(assetKey));

  @override
  Future<void> dispose() => _player.dispose();
}
