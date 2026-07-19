import 'package:field_notes/domain/services/sound_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SoundCue', () {
    test('exposes the three motion cues in order', () {
      expect(
        SoundCue.values,
        <SoundCue>[SoundCue.pageTurn, SoundCue.pencil, SoundCue.chime],
      );
    });

    test('maps each cue to its audioplayers asset key', () {
      expect(SoundCue.pageTurn.assetKey, 'sounds/page_turn.wav');
      expect(SoundCue.pencil.assetKey, 'sounds/pencil.wav');
      expect(SoundCue.chime.assetKey, 'sounds/chime.wav');
    });
  });
}
