enum AudioPlaybackState { idle, loading, playing, paused, completed, error }

abstract interface class EntryAudioPlayer {
  Future<void> load(String filePath);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Duration? get duration;
  Stream<Duration> get positionStream;
  AudioPlaybackState get state;
  Stream<AudioPlaybackState> get stateStream;
  Future<void> dispose();
}

typedef EntryAudioPlayerFactory = EntryAudioPlayer Function();
