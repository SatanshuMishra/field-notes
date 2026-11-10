import 'dart:async';

import 'package:field_notes/features/sound/output_route.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_playback.dart';
import 'video_playback.dart' show TunablePlayer;

const double _fullTrackVolume = 1.0;

class JustAudioEntryPlayer implements EntryAudioPlayer, TunablePlayer {
  JustAudioEntryPlayer({AudioPlayer? player, ValueListenable<double>? volume})
    : _player = player ?? AudioPlayer(),
      _volume = volume ?? playbackVolume {
    _applyVolume();
    _volume.addListener(_applyVolume);
  }

  final AudioPlayer _player;
  final ValueListenable<double> _volume;
  double _trackVolume = _fullTrackVolume;

  void _applyVolume() {
    unawaited(_player.setVolume(_volume.value * _trackVolume));
  }

  @override
  Future<void> setVolume(double volume) {
    _trackVolume = volume;
    return _player.setVolume(_volume.value * _trackVolume);
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> load(String filePath) async {
    await _player.setFilePath(filePath);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Duration? get duration => _player.duration;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  AudioPlaybackState get state => _map(_player.playerState);

  @override
  Stream<AudioPlaybackState> get stateStream =>
      _player.playerStateStream.map(_map);

  @override
  Future<void> dispose() {
    _volume.removeListener(_applyVolume);
    return _player.dispose();
  }

  AudioPlaybackState _map(PlayerState playerState) {
    switch (playerState.processingState) {
      case ProcessingState.idle:
        return AudioPlaybackState.idle;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return AudioPlaybackState.loading;
      case ProcessingState.ready:
        return playerState.playing
            ? AudioPlaybackState.playing
            : AudioPlaybackState.paused;
      case ProcessingState.completed:
        return AudioPlaybackState.completed;
    }
  }
}

EntryAudioPlayer createJustAudioPlayer() => JustAudioEntryPlayer();
