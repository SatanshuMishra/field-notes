import 'package:field_notes/domain/services/sound_service.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'audioplayers_sound_player.dart';
import 'gated_sound_service.dart';
import 'sound_player.dart';

part 'sound_providers.g.dart';

@Riverpod(keepAlive: true)
bool soundEnabled(Ref ref) {
  final settings = ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
  return settings.soundEnabled;
}

@Riverpod(keepAlive: true)
SoundPlayer soundPlayer(Ref ref) {
  final player = AudioPlayersSoundPlayer();
  ref.onDispose(player.dispose);
  return player;
}

@Riverpod(keepAlive: true)
SoundService soundService(Ref ref) {
  final player = ref.watch(soundPlayerProvider);
  return GatedSoundService(
    player: player,
    isEnabled: () => ref.read(soundEnabledProvider),
    onError: (error, _) => debugPrint('SoundService playback failed: $error'),
  );
}
