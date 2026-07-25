import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/video_body.dart';
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';

import '../support/entry_cards_harness.dart';
import '../support/fake_video_player.dart';

void main() {
  group('VideoBody', () {
    testWidgets('shows the thumbnail and duration before playback', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        cardHarness(
          VideoBody(
            entry: entryOf(
              type: EntryType.video,
              mediaId: 'vid',
              thumbnailMediaId: 'thumb',
              durationMs: 65000,
            ),
            resolver: FakeMediaResolver(),
            playerFactory: () => FakeEntryVideoPlayer(),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('video-play-toggle')),
        findsOneWidget,
      );
      expect(find.text('1:05'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('fake-video-surface')),
        findsNothing,
      );
    });

    testWidgets('loads and mounts the player surface on play', (
      WidgetTester tester,
    ) async {
      final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
      final FakeMediaResolver resolver = FakeMediaResolver()
        ..set(
          'vid',
          ResolvedMedia.available(
            blob: blobOf(id: 'vid', relPath: 'v.mp4', kind: MediaKind.video),
            file: File('/tmp/v.mp4'),
          ),
        );

      await tester.pumpWidget(
        cardHarness(
          VideoBody(
            entry: entryOf(
              type: EntryType.video,
              mediaId: 'vid',
              thumbnailMediaId: 'thumb',
              durationMs: 65000,
            ),
            resolver: resolver,
            playerFactory: () => player,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey<String>('video-play-toggle')));
      await tester.pump();

      expect(player.loadCalls, <String>['/tmp/v.mp4']);
      expect(player.playCalls, 1);

      player.emitState(VideoPlaybackState.playing);
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('fake-video-surface')),
        findsOneWidget,
      );
    });

    testWidgets('shows a non-destructive placeholder for missing video', (
      WidgetTester tester,
    ) async {
      final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
      await tester.pumpWidget(
        cardHarness(
          VideoBody(
            entry: entryOf(
              type: EntryType.video,
              mediaId: 'gone',
              thumbnailMediaId: 'thumb',
              durationMs: 1000,
            ),
            resolver: FakeMediaResolver(),
            playerFactory: () => player,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey<String>('video-play-toggle')));
      await tester.pump();

      expect(find.byType(CorruptMediaPlaceholder), findsOneWidget);
      expect(player.loadCalls, isEmpty);
    });

    testWidgets(
      'shows the play affordance instead of a corrupt placeholder when no poster was captured',
      (WidgetTester tester) async {
        final FakeMediaResolver resolver = FakeMediaResolver()
          ..set(
            'vid',
            ResolvedMedia.available(
              blob: blobOf(id: 'vid', relPath: 'v.mp4', kind: MediaKind.video),
              file: File('/tmp/v.mp4'),
            ),
          );

        await tester.pumpWidget(
          cardHarness(
            VideoBody(
              entry: entryOf(
                type: EntryType.video,
                mediaId: 'vid',
                thumbnailMediaId: null,
                durationMs: 65000,
              ),
              resolver: resolver,
              playerFactory: () => FakeEntryVideoPlayer(),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(CorruptMediaPlaceholder), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('video-play-toggle')),
          findsOneWidget,
        );
      },
    );

    testWidgets('keeps a working play/pause control reachable while playing', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
        final FakeMediaResolver resolver = FakeMediaResolver()
          ..set(
            'vid',
            ResolvedMedia.available(
              blob: blobOf(id: 'vid', relPath: 'v.mp4', kind: MediaKind.video),
              file: File('/tmp/v.mp4'),
            ),
          );

        await tester.pumpWidget(
          cardHarness(
            VideoBody(
              entry: entryOf(
                type: EntryType.video,
                mediaId: 'vid',
                thumbnailMediaId: 'thumb',
                durationMs: 65000,
              ),
              resolver: resolver,
              playerFactory: () => player,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(
          find.byKey(const ValueKey<String>('video-play-toggle')),
        );
        await tester.pump();

        player.emitState(VideoPlaybackState.playing);
        await tester.pump();

        expect(
          find.byKey(const ValueKey<String>('video-play-toggle')),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Pause video'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey<String>('video-play-toggle')),
        );
        await tester.pump();

        expect(player.pauseCalls, 1);
      } finally {
        handle.dispose();
      }
    });
  });
}
