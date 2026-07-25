import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/voice_body.dart';
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/audio_playback.dart';

import '../support/entry_cards_harness.dart';
import '../support/fake_audio_player.dart';

void main() {
  group('VoiceBody', () {
    testWidgets('loads the resolved audio and toggles play/pause',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final FakeEntryAudioPlayer player = FakeEntryAudioPlayer();
      final FakeMediaResolver resolver = FakeMediaResolver()
        ..set(
          'aud',
          ResolvedMedia.available(
            blob: blobOf(id: 'aud', relPath: 'a.m4a', kind: MediaKind.audio),
            file: File('/tmp/a.m4a'),
          ),
        );

      await tester.pumpWidget(
        cardHarness(
          VoiceBody(
            entry:
                entryOf(type: EntryType.voice, mediaId: 'aud', durationMs: 65000),
            resolver: resolver,
            playerFactory: () => player,
          ),
        ),
      );
      await tester.pump();

      expect(player.loadCalls, <String>['/tmp/a.m4a']);
      expect(find.bySemanticsLabel('Play'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('voice-play-toggle')));
      await tester.pump();
      expect(player.playCalls, 1);

      player.emitState(AudioPlaybackState.playing);
      await tester.pump();
      expect(find.bySemanticsLabel('Pause'), findsOneWidget);
      expect(find.bySemanticsLabel('Play'), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('voice-play-toggle')));
      await tester.pump();
      expect(player.pauseCalls, 1);

      handle.dispose();
    });

    testWidgets('renders the total duration and updates the position',
        (WidgetTester tester) async {
      final FakeEntryAudioPlayer player = FakeEntryAudioPlayer();
      final FakeMediaResolver resolver = FakeMediaResolver()
        ..set(
          'aud',
          ResolvedMedia.available(
            blob: blobOf(id: 'aud', relPath: 'a.m4a', kind: MediaKind.audio),
            file: File('/tmp/a.m4a'),
          ),
        );

      await tester.pumpWidget(
        cardHarness(
          VoiceBody(
            entry:
                entryOf(type: EntryType.voice, mediaId: 'aud', durationMs: 65000),
            resolver: resolver,
            playerFactory: () => player,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('0:00 / 1:05'), findsOneWidget);

      player.emitPosition(const Duration(seconds: 12));
      await tester.pump();
      expect(find.text('0:12 / 1:05'), findsOneWidget);
    });

    testWidgets('shows a non-destructive placeholder for missing audio',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        cardHarness(
          VoiceBody(
            entry:
                entryOf(type: EntryType.voice, mediaId: 'gone', durationMs: 1000),
            resolver: FakeMediaResolver(),
            playerFactory: () => FakeEntryAudioPlayer(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CorruptMediaPlaceholder), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('voice-play-toggle')),
        findsNothing,
      );
    });

    testWidgets('a new resolver identity re-prepares an unavailable card',
        (WidgetTester tester) async {
      final List<FakeEntryAudioPlayer> built = <FakeEntryAudioPlayer>[];
      final FakeMediaResolver settled = FakeMediaResolver()
        ..set(
          'aud',
          ResolvedMedia.available(
            blob: blobOf(id: 'aud', relPath: 'a.m4a', kind: MediaKind.audio),
            file: File('/tmp/a.m4a'),
          ),
        );

      Widget card(MediaResolver resolver) => cardHarness(
            VoiceBody(
              entry: entryOf(
                type: EntryType.voice,
                mediaId: 'aud',
                durationMs: 65000,
              ),
              resolver: resolver,
              playerFactory: () {
                final FakeEntryAudioPlayer player = FakeEntryAudioPlayer();
                built.add(player);
                return player;
              },
            ),
          );

      await tester.pumpWidget(card(FakeMediaResolver()));
      await tester.pump();

      expect(find.byType(CorruptMediaPlaceholder), findsOneWidget);
      expect(built, isEmpty);

      await tester.pumpWidget(card(settled));
      await tester.pump();
      await tester.pump();

      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
      expect(built, hasLength(1));
      expect(built.single.loadCalls, <String>['/tmp/a.m4a']);
      expect(
        find.byKey(const ValueKey<String>('voice-play-toggle')),
        findsOneWidget,
      );
    });

    testWidgets('a new resolver identity leaves in-progress playback alone',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<FakeEntryAudioPlayer> built = <FakeEntryAudioPlayer>[];

      Widget card(MediaResolver resolver) => cardHarness(
            VoiceBody(
              entry: entryOf(
                type: EntryType.voice,
                mediaId: 'aud',
                durationMs: 65000,
              ),
              resolver: resolver,
              playerFactory: () {
                final FakeEntryAudioPlayer player = FakeEntryAudioPlayer();
                built.add(player);
                return player;
              },
            ),
          );

      await tester.pumpWidget(card(audioResolver()));
      await tester.pump();
      expect(built, hasLength(1));

      await tester.tap(find.byKey(const ValueKey<String>('voice-play-toggle')));
      await tester.pump();
      expect(built.single.playCalls, 1);

      built.single.emitState(AudioPlaybackState.playing);
      built.single.emitPosition(const Duration(seconds: 12));
      await tester.pump();
      expect(find.bySemanticsLabel('Pause'), findsOneWidget);
      expect(find.text('0:12 / 1:05'), findsOneWidget);

      await tester.pumpWidget(card(audioResolver()));
      await tester.pump();
      await tester.pump();

      expect(built, hasLength(1));
      expect(built.single.disposeCalls, 0);
      expect(built.single.loadCalls, <String>['/tmp/a.m4a']);
      expect(find.bySemanticsLabel('Pause'), findsOneWidget);
      expect(find.text('0:12 / 1:05'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('voice-play-toggle')));
      await tester.pump();
      expect(built.single.pauseCalls, 1);

      handle.dispose();
    });

    testWidgets('a changed media id re-prepares and disposes the old player',
        (WidgetTester tester) async {
      final List<FakeEntryAudioPlayer> built = <FakeEntryAudioPlayer>[];

      Widget card(MediaResolver resolver, String mediaId) => cardHarness(
            VoiceBody(
              entry: entryOf(
                type: EntryType.voice,
                mediaId: mediaId,
                durationMs: 65000,
              ),
              resolver: resolver,
              playerFactory: () {
                final FakeEntryAudioPlayer player = FakeEntryAudioPlayer();
                built.add(player);
                return player;
              },
            ),
          );

      await tester.pumpWidget(card(audioResolver(), 'aud'));
      await tester.pump();
      expect(built, hasLength(1));
      expect(built.single.loadCalls, <String>['/tmp/a.m4a']);

      await tester.pumpWidget(card(audioResolver(), 'aud2'));
      await tester.pump();
      await tester.pump();

      expect(built, hasLength(2));
      expect(built[0].disposeCalls, 1);
      expect(built[1].loadCalls, <String>['/tmp/b.m4a']);
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
    });

    testWidgets('a changed media id re-prepares under the same resolver',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<FakeEntryAudioPlayer> built = <FakeEntryAudioPlayer>[];
      final FakeMediaResolver resolver = audioResolver();

      Widget card(String mediaId) => cardHarness(
            VoiceBody(
              entry: entryOf(
                type: EntryType.voice,
                mediaId: mediaId,
                durationMs: 65000,
              ),
              resolver: resolver,
              playerFactory: () {
                final FakeEntryAudioPlayer player = FakeEntryAudioPlayer();
                built.add(player);
                return player;
              },
            ),
          );

      await tester.pumpWidget(card('aud'));
      await tester.pump();
      expect(built, hasLength(1));
      expect(built.single.loadCalls, <String>['/tmp/a.m4a']);

      await tester.tap(find.byKey(const ValueKey<String>('voice-play-toggle')));
      await tester.pump();
      built.single.emitState(AudioPlaybackState.playing);
      built.single.emitPosition(const Duration(seconds: 12));
      await tester.pump();
      expect(find.bySemanticsLabel('Pause'), findsOneWidget);
      expect(find.text('0:12 / 1:05'), findsOneWidget);

      await tester.pumpWidget(card('aud2'));
      await tester.pump();
      await tester.pump();

      expect(built, hasLength(2));
      expect(built[0].disposeCalls, 1);
      expect(built[1].loadCalls, <String>['/tmp/b.m4a']);
      expect(find.bySemanticsLabel('Play'), findsOneWidget);
      expect(find.text('0:00 / 1:05'), findsOneWidget);

      handle.dispose();
    });
  });
}

FakeMediaResolver audioResolver() => FakeMediaResolver()
  ..set(
    'aud',
    ResolvedMedia.available(
      blob: blobOf(id: 'aud', relPath: 'a.m4a', kind: MediaKind.audio),
      file: File('/tmp/a.m4a'),
    ),
  )
  ..set(
    'aud2',
    ResolvedMedia.available(
      blob: blobOf(id: 'aud2', relPath: 'b.m4a', kind: MediaKind.audio),
      file: File('/tmp/b.m4a'),
    ),
  );
