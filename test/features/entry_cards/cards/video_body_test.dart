import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/video_body.dart';
import 'package:field_notes/features/entry_cards/cards/video_scrubber.dart';
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots.dart';

import '../support/entry_cards_harness.dart';
import '../support/fake_video_player.dart';

const ValueKey<String> _playToggle = ValueKey<String>('video-play-toggle');
const ValueKey<String> _scrubBar = ValueKey<String>('video-scrub-bar');
const ValueKey<String> _muteToggle = ValueKey<String>('video-mute-toggle');

FakeMediaResolver _resolverWithVideo() => FakeMediaResolver()
  ..set(
    'vid',
    ResolvedMedia.available(
      blob: blobOf(id: 'vid', relPath: 'v.mp4', kind: MediaKind.video),
      file: File('/tmp/v.mp4'),
    ),
  );

Widget _videoCard({
  required MediaResolver resolver,
  required FakeEntryVideoPlayer player,
  int? durationMs = 65000,
  String? thumbnailMediaId,
  String mediaId = 'vid',
}) {
  return cardHarness(
    VideoBody(
      entry: entryOf(
        type: EntryType.video,
        mediaId: mediaId,
        thumbnailMediaId: thumbnailMediaId,
        durationMs: durationMs,
      ),
      resolver: resolver,
      playerFactory: () => player,
      slots: const UnlimitedVideoSlots(),
    ),
  );
}

void main() {
  group('VideoBody', () {
    testWidgets('shows the elapsed and total readout before playback', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _videoCard(
          resolver: _resolverWithVideo(),
          player: FakeEntryVideoPlayer(),
        ),
      );
      await tester.pump();

      expect(find.byKey(_playToggle), findsOneWidget);
      expect(find.byKey(_scrubBar), findsOneWidget);
      expect(find.byKey(_muteToggle), findsOneWidget);
      expect(find.text('0:00 / 1:05'), findsOneWidget);
    });

    testWidgets('seeks to the tapped position on the scrub bar', (
      WidgetTester tester,
    ) async {
      final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
      await tester.pumpWidget(
        _videoCard(resolver: _resolverWithVideo(), player: player),
      );
      await tester.pump();

      final Rect bar = tester.getRect(find.byKey(_scrubBar));
      await tester.tapAt(Offset(bar.left + bar.width * 0.5, bar.center.dy));
      await tester.pump();

      expect(player.seekCalls, hasLength(1));
      expect(
        player.seekCalls.single.inMilliseconds,
        closeTo(32500, 2000),
      );
    });

    testWidgets('maps a tap to the inset track the handle is painted on', (
      WidgetTester tester,
    ) async {
      final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
      await tester.pumpWidget(
        _videoCard(resolver: _resolverWithVideo(), player: player),
      );
      await tester.pump();

      final Rect bar = tester.getRect(find.byKey(_scrubBar));
      await tester.tapAt(Offset(bar.left + scrubberHandleRadius, bar.center.dy));
      await tester.pump();

      expect(player.seekCalls, <Duration>[Duration.zero]);

      await tester.tapAt(
        Offset(bar.right - scrubberHandleRadius, bar.center.dy),
      );
      await tester.pump();

      expect(player.seekCalls.last, const Duration(milliseconds: 65000));
    });

    testWidgets('coalesces a drag into a single seek at the released offset', (
      WidgetTester tester,
    ) async {
      final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
      await tester.pumpWidget(
        _videoCard(resolver: _resolverWithVideo(), player: player),
      );
      await tester.pump();

      final Rect bar = tester.getRect(find.byKey(_scrubBar));
      final TestGesture gesture = await tester.startGesture(
        Offset(bar.left + 1, bar.center.dy),
      );
      await gesture.moveTo(Offset(bar.center.dx, bar.center.dy));
      await tester.pump();

      expect(player.seekCalls, isEmpty);
      expect(find.text('0:32 / 1:05'), findsOneWidget);

      await gesture.moveTo(Offset(bar.right + 40, bar.center.dy));
      await gesture.up();
      await tester.pump();

      expect(player.seekCalls, <Duration>[const Duration(milliseconds: 65000)]);
    });

    testWidgets('ignores polled positions while the handle is being dragged', (
      WidgetTester tester,
    ) async {
      final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
      await tester.pumpWidget(
        _videoCard(resolver: _resolverWithVideo(), player: player),
      );
      await tester.pump();

      final Rect bar = tester.getRect(find.byKey(_scrubBar));
      final TestGesture gesture = await tester.startGesture(
        Offset(bar.center.dx - 40, bar.center.dy),
      );
      await gesture.moveTo(Offset(bar.center.dx, bar.center.dy));
      await tester.pump();

      player.emitPosition(const Duration(seconds: 3));
      await tester.pump();

      expect(find.text('0:32 / 1:05'), findsOneWidget);

      await gesture.up();
      await tester.pump();

      player.emitPosition(const Duration(seconds: 40));
      await tester.pump();

      expect(find.text('0:40 / 1:05'), findsOneWidget);
    });

    testWidgets('restores the previous position when a seek fails', (
      WidgetTester tester,
    ) async {
      final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
      await tester.pumpWidget(
        _videoCard(resolver: _resolverWithVideo(), player: player),
      );
      await tester.pump();

      player.emitPosition(const Duration(seconds: 12));
      await tester.pump();

      expect(find.text('0:12 / 1:05'), findsOneWidget);

      player.seekError = StateError('seek rejected');
      final Rect bar = tester.getRect(find.byKey(_scrubBar));
      await tester.tapAt(Offset(bar.center.dx, bar.center.dy));
      await tester.pump();

      expect(player.seekCalls, isEmpty);
      expect(find.text('0:12 / 1:05'), findsOneWidget);
    });

    testWidgets('seeks with the keyboard while the scrub bar holds focus', (
      WidgetTester tester,
    ) async {
      final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
      await tester.pumpWidget(
        _videoCard(resolver: _resolverWithVideo(), player: player),
      );
      await tester.pump();

      Focus.of(tester.element(find.byKey(_scrubBar))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(player.seekCalls, <Duration>[const Duration(seconds: 5)]);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(player.seekCalls.last, Duration.zero);
    });

    testWidgets('updates the readout as the position advances', (
      WidgetTester tester,
    ) async {
      final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
      await tester.pumpWidget(
        _videoCard(resolver: _resolverWithVideo(), player: player),
      );
      await tester.pump();

      player.emitPosition(const Duration(seconds: 12));
      await tester.pump();

      expect(find.text('0:12 / 1:05'), findsOneWidget);
    });

    testWidgets('mutes and restores the previous volume', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
        await tester.pumpWidget(
          _videoCard(resolver: _resolverWithVideo(), player: player),
        );
        await tester.pump();

        expect(find.bySemanticsLabel('Mute video'), findsOneWidget);

        await tester.tap(find.byKey(_muteToggle));
        await tester.pump();

        expect(player.volumeCalls, <double>[0.0]);
        expect(find.bySemanticsLabel('Unmute video'), findsOneWidget);

        await tester.tap(find.byKey(_muteToggle));
        await tester.pump();

        expect(player.volumeCalls, <double>[0.0, 1.0]);
        expect(find.bySemanticsLabel('Mute video'), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('does not seek when the total duration is unknown', (
      WidgetTester tester,
    ) async {
      final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
      await tester.pumpWidget(
        _videoCard(
          resolver: _resolverWithVideo(),
          player: player,
          durationMs: null,
        ),
      );
      await tester.pump();

      final Rect bar = tester.getRect(find.byKey(_scrubBar));
      await tester.tapAt(Offset(bar.left + bar.width * 0.5, bar.center.dy));
      await tester.pump();

      expect(player.seekCalls, isEmpty);
      expect(find.text('0:00 / 0:00'), findsOneWidget);
    });

    testWidgets('keeps every control at the 48 logical pixel target floor', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _videoCard(
          resolver: _resolverWithVideo(),
          player: FakeEntryVideoPlayer(),
        ),
      );
      await tester.pump();

      expect(tester.getSize(find.byKey(_playToggle)).height, greaterThan(47.9));
      expect(tester.getSize(find.byKey(_muteToggle)).height, greaterThan(47.9));
      expect(tester.getSize(find.byKey(_muteToggle)).width, greaterThan(47.9));
      expect(tester.getSize(find.byKey(_scrubBar)).height, greaterThan(47.9));
    });

    testWidgets('loads and mounts the player surface without autoplaying', (
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
            slots: const UnlimitedVideoSlots(),
          ),
        ),
      );
      await tester.pump();

      expect(player.loadCalls, <String>['/tmp/v.mp4']);
      expect(player.playCalls, 0);
      expect(
        find.byKey(const ValueKey<String>('fake-video-surface')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('video-play-toggle')));
      await tester.pump();

      expect(player.playCalls, 1);
      expect(player.loadCalls, <String>['/tmp/v.mp4']);
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
            slots: const UnlimitedVideoSlots(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CorruptMediaPlaceholder), findsOneWidget);
      expect(player.loadCalls, isEmpty);
      expect(find.byKey(_playToggle), findsNothing);
      expect(find.byKey(_scrubBar), findsNothing);
      expect(find.byKey(_muteToggle), findsNothing);
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
              slots: const UnlimitedVideoSlots(),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(CorruptMediaPlaceholder), findsNothing);
        expect(find.byType(NeutralMediaPlaceholder), findsOneWidget);
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
              slots: const UnlimitedVideoSlots(),
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

    testWidgets('replays from the start once playback has completed', (
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
            slots: const UnlimitedVideoSlots(),
          ),
        ),
      );
      await tester.pump();

      player.emitState(VideoPlaybackState.completed);
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('video-play-toggle')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('video-play-toggle')));
      await tester.pump();

      expect(player.seekCalls, <Duration>[Duration.zero]);
      expect(player.playCalls, 1);
    });
  });
}
