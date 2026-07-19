import 'package:field_notes/domain/services/sound_service.dart';

import 'sound_player.dart';

typedef SoundEnabledGetter = bool Function();

typedef SoundErrorHandler = void Function(Object error, StackTrace stackTrace);

class GatedSoundService implements SoundService {
  GatedSoundService({
    required this._player,
    required this._isEnabled,
    this._onError,
  });

  final SoundPlayer _player;
  final SoundEnabledGetter _isEnabled;
  final SoundErrorHandler? _onError;

  @override
  Future<void> play(SoundCue cue) async {
    if (!_isEnabled()) {
      return;
    }
    try {
      await _player.play(cue.assetKey);
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    }
  }
}
