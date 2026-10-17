import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'output_route.dart';
import 'sound_player.dart';

class AudioPlayersSoundPlayer implements SoundPlayer {
  AudioPlayersSoundPlayer({
    AudioPlayer? player,
    ValueListenable<double>? volume,
  }) : _player = player ?? AudioPlayer(),
       _volume = volume ?? playbackVolume {
    _applyVolume();
    _volume.addListener(_applyVolume);
  }

  final AudioPlayer _player;
  final ValueListenable<double> _volume;

  void _applyVolume() {
    unawaited(_player.setVolume(_volume.value));
  }

  @override
  Future<void> play(String assetKey) => _player.play(AssetSource(assetKey));

  @override
  Future<void> dispose() {
    _volume.removeListener(_applyVolume);
    return _player.dispose();
  }
}
