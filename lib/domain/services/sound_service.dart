enum SoundCue {
  pageTurn('sounds/page_turn.wav'),
  pencil('sounds/pencil.wav'),
  chime('sounds/chime.wav');

  const SoundCue(this.assetKey);

  final String assetKey;
}

abstract interface class SoundService {
  Future<void> play(SoundCue cue);
}
