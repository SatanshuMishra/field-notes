import 'package:field_notes/domain/services/sound_service.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/sound/sound_player.dart';
import 'package:field_notes/features/sound/sound_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_sound_player.dart';

ProviderContainer _containerWith({
  required bool soundEnabled,
  required SoundPlayer player,
}) {
  final container = ProviderContainer(
    overrides: [
      appSettingsProvider.overrideWith(
        (ref) => Stream<AppSettings>.value(
          AppSettings.defaults.copyWith(soundEnabled: soundEnabled),
        ),
      ),
      soundPlayerProvider.overrideWithValue(player),
    ],
  );
  addTearDown(container.dispose);
  container.listen(soundEnabledProvider, (_, _) {});
  return container;
}

void main() {
  group('sound providers', () {
    test('soundEnabledProvider reflects the settings toggle', () async {
      final container =
          _containerWith(soundEnabled: false, player: FakeSoundPlayer());
      await pumpEventQueue();

      expect(container.read(soundEnabledProvider), isFalse);
    });

    test('soundServiceProvider plays through the player when enabled',
        () async {
      final player = FakeSoundPlayer();
      final container = _containerWith(soundEnabled: true, player: player);
      await pumpEventQueue();

      await container.read(soundServiceProvider).play(SoundCue.pencil);

      expect(player.played, <String>['sounds/pencil.wav']);
    });

    test('soundServiceProvider is silent when the toggle is off', () async {
      final player = FakeSoundPlayer();
      final container = _containerWith(soundEnabled: false, player: player);
      await pumpEventQueue();

      await container.read(soundServiceProvider).play(SoundCue.pencil);

      expect(player.played, isEmpty);
    });
  });
}
