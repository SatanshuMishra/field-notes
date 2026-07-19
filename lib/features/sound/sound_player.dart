abstract interface class SoundPlayer {
  Future<void> play(String assetKey);

  Future<void> dispose();
}
