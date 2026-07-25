import 'dart:async';

import 'package:field_notes/features/entry_cards/playback/audio_playback.dart';

class FakeEntryAudioPlayer implements EntryAudioPlayer {
  final StreamController<AudioPlaybackState> _stateController =
      StreamController<AudioPlaybackState>.broadcast(sync: true);
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast(sync: true);

  final List<String> loadCalls = <String>[];
  int playCalls = 0;
  int pauseCalls = 0;
  int disposeCalls = 0;
  AudioPlaybackState _state = AudioPlaybackState.idle;

  void emitState(AudioPlaybackState state) {
    _state = state;
    _stateController.add(state);
  }

  void emitPosition(Duration position) => _positionController.add(position);

  @override
  Future<void> load(String filePath) async => loadCalls.add(filePath);

  @override
  Future<void> play() async => playCalls++;

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> seek(Duration position) async {}

  @override
  Duration? get duration => null;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  AudioPlaybackState get state => _state;

  @override
  Stream<AudioPlaybackState> get stateStream => _stateController.stream;

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await _stateController.close();
    await _positionController.close();
  }
}
