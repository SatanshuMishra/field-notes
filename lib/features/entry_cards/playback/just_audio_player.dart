import 'package:just_audio/just_audio.dart';

import 'audio_playback.dart';

class JustAudioEntryPlayer implements EntryAudioPlayer {
  JustAudioEntryPlayer() : _player = AudioPlayer();

  final AudioPlayer _player;

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
  Future<void> dispose() => _player.dispose();

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
