import 'package:field_notes/features/sound/sound_player.dart';

class FakeSoundPlayer implements SoundPlayer {
  FakeSoundPlayer({this.throwOnPlay = false});

  final bool throwOnPlay;
  final List<String> played = <String>[];

  @override
  Future<void> play(String assetKey) async {
    played.add(assetKey);
    if (throwOnPlay) {
      throw StateError('playback failed for $assetKey');
    }
  }

  @override
  Future<void> dispose() async {}
}
