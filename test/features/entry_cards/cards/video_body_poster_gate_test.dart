import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/video_body.dart';
import 'package:field_notes/features/entry_cards/media/media_image.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots.dart';

import '../support/entry_cards_harness.dart';
import '../support/fake_video_player.dart';
import '../support/video_card_harness.dart';

FakeMediaResolver _posterOnlyResolver() => FakeMediaResolver()
  ..set(
    'thumb',
    ResolvedMedia.available(
      blob: blobOf(id: 'thumb', relPath: 'p.png'),
      file: posterFixtureFile(),
    ),
  );

Widget _posterCardOfMediaId({
  required MediaResolver resolver,
  required EntryVideoPlayerFactory playerFactory,
  required VideoSlots slots,
  required String mediaId,
}) {
  return cardHarness(
    VideoBody(
      key: const ValueKey<String>('card-0'),
      entry: entryOf(
        id: 'e0',
        type: EntryType.video,
        mediaId: mediaId,
        thumbnailMediaId: 'thumb',
        durationMs: 65000,
      ),
      resolver: resolver,
      playerFactory: playerFactory,
      slots: slots,
      loadTimeout: videoLoadTimeout,
      retryBackoff: videoBackoff,
    ),
  );
}

void main() {
  group('VideoBody poster-first decode gate', () {
    testWidgets('a poster-bearing card claims no decoder slot at mount', (
      WidgetTester tester,
    ) async {
      final RecordingVideoSlots slots = recordingSlotsWithCapOf(1);
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(
            videoFixtureFile(),
            poster: posterFixtureFile(),
          ),
          playerFactory: videoFactoryInto(built),
          slots: slots,
          indices: <int>[0],
          thumbnailMediaId: 'thumb',
        ),
      );
      await tester.pump();

      expect(slots.acquireCalls, isEmpty);
      expect(built, isEmpty);
      expect(surfaceMounted(tester, 0), isFalse);
      expect(find.byType(MediaImage), findsOneWidget);
      expect(tapEnabled(tester, inCard(0, videoPlayToggleKey)), isTrue);
    });

    testWidgets('the transport tap is what claims the slot and loads', (
      WidgetTester tester,
    ) async {
      final RecordingVideoSlots slots = recordingSlotsWithCapOf(1);
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];
      final File file = videoFixtureFile();

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(file, poster: posterFixtureFile()),
          playerFactory: videoFactoryInto(built),
          slots: slots,
          indices: <int>[0],
          thumbnailMediaId: 'thumb',
        ),
      );
      await tester.pump();

      await tester.tap(inCard(0, videoPlayToggleKey));
      await tester.pump();
      await tester.pump();

      expect(
        slots.acquireCalls,
        <VideoSlotEvictionRights>[VideoSlotEvictionRights.evictUnpinned],
      );
      expect(built, hasLength(1));
      expect(built.single.loadCalls, <String>[file.path]);
      expect(built.single.playCalls, 1);
      expect(surfaceMounted(tester, 0), isTrue);
    });

    testWidgets('a posterless card still claims its slot at mount', (
      WidgetTester tester,
    ) async {
      final RecordingVideoSlots slots = recordingSlotsWithCapOf(1);
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];
      final File file = videoFixtureFile();

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(file),
          playerFactory: videoFactoryInto(built),
          slots: slots,
          indices: <int>[0],
        ),
      );
      await tester.pump();

      expect(
        slots.acquireCalls,
        <VideoSlotEvictionRights>[VideoSlotEvictionRights.none],
      );
      expect(built, hasLength(1));
      expect(built.single.loadCalls, <String>[file.path]);
      expect(built.single.playCalls, 0);
    });

    testWidgets(
      'a resolver identity change on a still-gated card claims no slot',
      (WidgetTester tester) async {
        final RecordingVideoSlots slots = recordingSlotsWithCapOf(1);
        final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];
        final File file = videoFixtureFile();
        final File poster = posterFixtureFile();
        final EntryVideoPlayerFactory playerFactory = videoFactoryInto(built);

        await tester.pumpWidget(
          videoCardColumn(
            resolver: videoResolverFor(file, poster: poster),
            playerFactory: playerFactory,
            slots: slots,
            indices: <int>[0],
            thumbnailMediaId: 'thumb',
          ),
        );
        await tester.pump();

        expect(slots.acquireCalls, isEmpty);

        await tester.pumpWidget(
          videoCardColumn(
            resolver: videoResolverFor(file, poster: poster),
            playerFactory: playerFactory,
            slots: slots,
            indices: <int>[0],
            thumbnailMediaId: 'thumb',
          ),
        );
        await tester.pump();

        expect(slots.acquireCalls, isEmpty);
        expect(built, isEmpty);
        expect(tapEnabled(tester, inCard(0, videoPlayToggleKey)), isTrue);

        await tester.tap(inCard(0, videoPlayToggleKey));
        await tester.pump();
        await tester.pump();

        expect(
          slots.acquireCalls,
          <VideoSlotEvictionRights>[VideoSlotEvictionRights.evictUnpinned],
        );
        expect(built, hasLength(1));
        expect(built.single.loadCalls, <String>[file.path]);
      },
    );

    testWidgets('a missing clip behind a poster is reported only at the tap', (
      WidgetTester tester,
    ) async {
      final RecordingVideoSlots slots = recordingSlotsWithCapOf(1);
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        _posterCardOfMediaId(
          resolver: _posterOnlyResolver(),
          playerFactory: videoFactoryInto(built),
          slots: slots,
          mediaId: 'gone',
        ),
      );
      await tester.pump();

      expect(inCard(0, videoPlayToggleKey), findsOneWidget);
      expect(find.byKey(mediaRetryKey), findsNothing);
      expect(slots.acquireCalls, isEmpty);

      await tester.tap(inCard(0, videoPlayToggleKey));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(mediaRetryKey), findsOneWidget);
      expect(inCard(0, videoPlayToggleKey), findsNothing);
      expect(slots.acquireCalls, isEmpty);
      expect(built, isEmpty);
    });
  });
}
