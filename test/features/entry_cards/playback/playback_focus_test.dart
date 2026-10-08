import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/voice_body.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/audio_playback.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';

import '../support/entry_cards_harness.dart';
import '../support/fake_audio_player.dart';

const ValueKey<String> _firstCard = ValueKey<String>('first-voice-card');
const ValueKey<String> _secondCard = ValueKey<String>('second-voice-card');

void main() {
  testWidgets('starting one player pauses the one that was playing', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(384, 832);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 34, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 34, bottom: 24);
    addTearDown(tester.view.reset);

    final PlaybackFocus focus = PlaybackFocus();
    final FakeEntryAudioPlayer first = FakeEntryAudioPlayer();
    final FakeEntryAudioPlayer second = FakeEntryAudioPlayer();
    final FakeMediaResolver resolver = FakeMediaResolver()
      ..set('aud-first', _available('aud-first', 'first.m4a'))
      ..set('aud-second', _available('aud-second', 'second.m4a'));

    await tester.pumpWidget(
      cardHarness(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            VoiceBody(
              key: _firstCard,
              entry: entryOf(
                type: EntryType.voice,
                id: 'e-first',
                mediaId: 'aud-first',
                durationMs: 65000,
              ),
              resolver: resolver,
              playerFactory: () => first,
              focus: focus,
            ),
            VoiceBody(
              key: _secondCard,
              entry: entryOf(
                type: EntryType.voice,
                id: 'e-second',
                mediaId: 'aud-second',
                durationMs: 42000,
              ),
              resolver: resolver,
              playerFactory: () => second,
              focus: focus,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(first.loadCalls, <String>['/tmp/first.m4a']);
    expect(second.loadCalls, <String>['/tmp/second.m4a']);

    await tester.tap(_toggleIn(_firstCard));
    await tester.pump();
    first.emitState(AudioPlaybackState.playing);
    await tester.pump();

    expect(first.playCalls, 1);
    expect(first.pauseCalls, 0);

    await tester.tap(_toggleIn(_secondCard));
    await tester.pump();
    second.emitState(AudioPlaybackState.playing);
    await tester.pump();

    expect(first.pauseCalls, 1);
    expect(second.playCalls, 1);
    expect(second.pauseCalls, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  group('PlaybackFocus', () {
    test('a pause that throws still hands the focus over', () {
      final PlaybackFocus focus = PlaybackFocus();
      final List<String> paused = <String>[];
      final Object first = Object();
      final Object second = Object();

      focus.claim(first, () => throw StateError('player already gone'));
      focus.claim(second, () => paused.add('second'));
      focus.silence();

      expect(paused, <String>['second']);
    });

    test('claiming again keeps the owner playing', () {
      final PlaybackFocus focus = PlaybackFocus();
      final List<String> paused = <String>[];
      final Object owner = Object();

      focus.claim(owner, () => paused.add('owner'));
      focus.claim(owner, () => paused.add('owner'));

      expect(paused, isEmpty);
    });

    test('a release from an earlier owner keeps the current one', () {
      final PlaybackFocus focus = PlaybackFocus();
      final List<String> paused = <String>[];
      final Object first = Object();
      final Object second = Object();

      focus.claim(first, () => paused.add('first'));
      focus.claim(second, () => paused.add('second'));
      focus.release(first);
      focus.silence();

      expect(paused, <String>['first', 'second']);
    });
  });
}

Finder _toggleIn(Key card) => find.descendant(
  of: find.byKey(card),
  matching: find.byKey(const ValueKey<String>('voice-play-toggle')),
);

ResolvedMedia _available(String id, String file) => ResolvedMedia.available(
  blob: blobOf(id: id, relPath: file, kind: MediaKind.audio),
  file: File('/tmp/$file'),
);
