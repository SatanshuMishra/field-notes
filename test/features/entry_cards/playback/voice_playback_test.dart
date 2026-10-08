import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/audio_playback.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/entry_cards/playback/voice_playback.dart';

import '../support/entry_cards_harness.dart';
import '../support/fake_audio_player.dart';

class _SeekRecordingPlayer extends FakeEntryAudioPlayer {
  final List<Duration> seekCalls = <Duration>[];

  @override
  Future<void> seek(Duration position) async => seekCalls.add(position);
}

class _UnreadableResolver implements MediaResolver {
  @override
  Future<ResolvedMedia> resolve(String? mediaId) async =>
      throw const FileSystemException('media store unreadable');

  @override
  ResolvedMedia? resolved(String? mediaId) => null;
}

void main() {
  group('VoicePlayback', () {
    test('toggle plays then pauses', () async {
      final FakeEntryAudioPlayer player = FakeEntryAudioPlayer();
      final VoicePlayback playback = _playback(player, PlaybackFocus());
      addTearDown(playback.dispose);
      await pumpEventQueue();

      expect(playback.ready, isTrue);
      expect(player.loadCalls, <String>['/tmp/a.m4a']);

      await playback.toggle();
      expect(player.playCalls, 1);
      expect(player.pauseCalls, 0);

      player.emitState(AudioPlaybackState.playing);
      expect(playback.isPlaying, isTrue);

      await playback.toggle();
      expect(player.playCalls, 1);
      expect(player.pauseCalls, 1);
    });

    test(
      'seekToFraction(0.75) seeks to 75% of the recorded duration',
      () async {
        final _SeekRecordingPlayer player = _SeekRecordingPlayer();
        final VoicePlayback playback = _playback(player, PlaybackFocus());
        addTearDown(playback.dispose);
        await pumpEventQueue();

        playback.seekToFraction(0.75);
        await pumpEventQueue();

        expect(player.seekCalls, <Duration>[
          const Duration(milliseconds: 48750),
        ]);
        expect(playback.position, const Duration(milliseconds: 48750));
        expect(player.playCalls, 1);
      },
    );

    test('a resolve failure marks the recording unavailable', () async {
      int built = 0;
      final VoicePlayback playback = VoicePlayback(
        entry: _voiceEntry(),
        resolver: _UnreadableResolver(),
        playerFactory: () {
          built += 1;
          return FakeEntryAudioPlayer();
        },
        focus: PlaybackFocus(),
      );
      addTearDown(playback.dispose);
      await pumpEventQueue();

      expect(playback.unavailable, isTrue);
      expect(playback.ready, isFalse);
      expect(built, 0);
    });

    test('dispose disposes the player and releases the focus', () async {
      final FakeEntryAudioPlayer player = FakeEntryAudioPlayer();
      final PlaybackFocus focus = PlaybackFocus();
      final VoicePlayback playback = _playback(player, focus);
      await pumpEventQueue();
      await playback.toggle();
      player.emitState(AudioPlaybackState.playing);

      playback.dispose();
      focus.silence();

      expect(player.disposeCalls, 1);
      expect(player.pauseCalls, 0);
    });

    test('pausing gives the focus back', () async {
      final FakeEntryAudioPlayer player = FakeEntryAudioPlayer();
      final PlaybackFocus focus = PlaybackFocus();
      final VoicePlayback playback = _playback(player, focus);
      addTearDown(playback.dispose);
      await pumpEventQueue();
      await playback.toggle();
      player.emitState(AudioPlaybackState.playing);
      await playback.toggle();

      focus.silence();

      expect(player.pauseCalls, 1);
    });

    test('finishing gives the focus back', () async {
      final FakeEntryAudioPlayer player = FakeEntryAudioPlayer();
      final PlaybackFocus focus = PlaybackFocus();
      final VoicePlayback playback = _playback(player, focus);
      addTearDown(playback.dispose);
      await pumpEventQueue();
      await playback.toggle();
      player.emitState(AudioPlaybackState.playing);
      player.emitState(AudioPlaybackState.completed);

      focus.silence();

      expect(player.pauseCalls, 0);
    });

    test(
      'a paused report that arrives before playing keeps the focus',
      () async {
        final FakeEntryAudioPlayer player = FakeEntryAudioPlayer();
        final PlaybackFocus focus = PlaybackFocus();
        final VoicePlayback playback = _playback(player, focus);
        addTearDown(playback.dispose);
        await pumpEventQueue();
        await playback.toggle();
        player.emitState(AudioPlaybackState.paused);

        focus.silence();
        await pumpEventQueue();

        expect(player.pauseCalls, 1);
      },
    );
  });
}

Entry _voiceEntry() =>
    entryOf(type: EntryType.voice, mediaId: 'aud', durationMs: 65000);

VoicePlayback _playback(FakeEntryAudioPlayer player, PlaybackFocus focus) =>
    VoicePlayback(
      entry: _voiceEntry(),
      resolver: FakeMediaResolver()
        ..set(
          'aud',
          ResolvedMedia.available(
            blob: blobOf(id: 'aud', relPath: 'a.m4a', kind: MediaKind.audio),
            file: File('/tmp/a.m4a'),
          ),
        ),
      playerFactory: () => player,
      focus: focus,
    );
