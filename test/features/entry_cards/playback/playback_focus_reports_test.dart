import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/video_body.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/audio_playback.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots.dart';
import 'package:field_notes/features/entry_cards/playback/voice_playback.dart';

import '../support/entry_cards_harness.dart';
import '../support/fake_audio_player.dart';
import '../support/fake_video_player.dart';
import '../support/video_card_harness.dart';

const ValueKey<String> _playToggle = ValueKey<String>('video-play-toggle');

void main() {
  test('a voice reported paused then playing still answers silence', () async {
    final FakeEntryAudioPlayer player = FakeEntryAudioPlayer();
    final PlaybackFocus focus = PlaybackFocus();
    final VoicePlayback playback = VoicePlayback(
      entry: entryOf(type: EntryType.voice, mediaId: 'aud', durationMs: 65000),
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
    addTearDown(playback.dispose);
    await pumpEventQueue();
    await playback.toggle();
    player.emitState(AudioPlaybackState.playing);
    player.emitState(AudioPlaybackState.paused);
    player.emitState(AudioPlaybackState.playing);
    final int before = player.pauseCalls;

    focus.silence();
    await pumpEventQueue();

    expect(player.pauseCalls, before + 1);
  });

  testWidgets('a video reported paused then playing still answers silence', (
    WidgetTester tester,
  ) async {
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
    final PlaybackFocus focus = PlaybackFocus();
    await tester.pumpWidget(
      cardHarness(
        VideoBody(
          entry: entryOf(
            type: EntryType.video,
            mediaId: 'vid',
            durationMs: 65000,
          ),
          resolver: FakeMediaResolver()
            ..set(
              'vid',
              ResolvedMedia.available(
                blob: blobOf(
                  id: 'vid',
                  relPath: 'v.mp4',
                  kind: MediaKind.video,
                ),
                file: File('/tmp/v.mp4'),
              ),
            ),
          playerFactory: () => player,
          slots: const UnlimitedVideoSlots(),
          controls: videoTestControls,
          focus: focus,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(_playToggle));
    await tester.pump();
    expect(player.playCalls, 1);
    player.emitState(VideoPlaybackState.playing);
    player.emitState(VideoPlaybackState.paused);
    player.emitState(VideoPlaybackState.playing);
    await tester.pump();
    final int before = player.pauseCalls;

    focus.silence();
    await tester.pump();

    expect(player.pauseCalls, before + 1);
  });
}
