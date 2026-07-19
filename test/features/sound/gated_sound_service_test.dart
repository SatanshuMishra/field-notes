import 'package:field_notes/domain/services/sound_service.dart';
import 'package:field_notes/features/sound/gated_sound_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_sound_player.dart';

void main() {
  group('GatedSoundService', () {
    test('plays the cue asset when sound is enabled', () async {
      final player = FakeSoundPlayer();
      final service = GatedSoundService(player: player, isEnabled: () => true);

      await service.play(SoundCue.pencil);

      expect(player.played, <String>['sounds/pencil.wav']);
    });

    test('is silent when sound is disabled', () async {
      final player = FakeSoundPlayer();
      final service = GatedSoundService(player: player, isEnabled: () => false);

      await service.play(SoundCue.chime);

      expect(player.played, isEmpty);
    });

    test('re-reads the toggle on every call', () async {
      var enabled = false;
      final player = FakeSoundPlayer();
      final service =
          GatedSoundService(player: player, isEnabled: () => enabled);

      await service.play(SoundCue.pageTurn);
      expect(player.played, isEmpty);

      enabled = true;
      await service.play(SoundCue.pageTurn);
      expect(player.played, <String>['sounds/page_turn.wav']);
    });

    test('forwards playback errors to onError instead of throwing', () async {
      final player = FakeSoundPlayer(throwOnPlay: true);
      Object? captured;
      final service = GatedSoundService(
        player: player,
        isEnabled: () => true,
        onError: (error, _) => captured = error,
      );

      await service.play(SoundCue.chime);

      expect(captured, isA<StateError>());
    });

    test('never throws to the caller even without an onError handler',
        () async {
      final player = FakeSoundPlayer(throwOnPlay: true);
      final service = GatedSoundService(player: player, isEnabled: () => true);

      await expectLater(service.play(SoundCue.pencil), completes);
    });
  });
}
