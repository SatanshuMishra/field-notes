import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/entry_cards/media/media_image.dart';
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots.dart';

import '../support/entry_cards_harness.dart';
import '../support/fake_video_player.dart';
import '../support/video_card_harness.dart';

void main() {
  group('VideoBody under cap pressure', () {
    testWidgets('three cards contending for two slots stay neutral or loaded', (
      WidgetTester tester,
    ) async {
      final LruVideoSlots slots = slotsWithCapOf(2);
      final Completer<void> gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) {
          gate.complete();
        }
      });
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(videoFixtureFile()),
          playerFactory: videoFactoryInto(
            built,
            setUpPlayer: (FakeEntryVideoPlayer player, int index) =>
                player.loadGate = gate,
          ),
          slots: slots,
          indices: <int>[0, 1, 2],
        ),
      );
      await tester.pump();

      expect(built, hasLength(2));
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);

      gate.complete();
      await tester.pump();
      await tester.pump();

      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
      expect(built, hasLength(2));
      for (final FakeEntryVideoPlayer player in built) {
        expect(player.disposeCalls, 0);
      }
      for (int index = 0; index < 3; index += 1) {
        expect(
          readyControlsEnabled(tester, index) && !surfaceMounted(tester, index),
          isFalse,
          reason: 'card $index enabled its controls with no video surface',
        );
      }
    });

    testWidgets('a card evicted mid load never reports itself loaded', (
      WidgetTester tester,
    ) async {
      final LruVideoSlots slots = slotsWithCapOf(1);
      final Completer<void> gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) {
          gate.complete();
        }
      });
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(videoFixtureFile()),
          playerFactory: videoFactoryInto(
            built,
            setUpPlayer: (FakeEntryVideoPlayer player, int index) =>
                player.loadGate = gate,
          ),
          slots: slots,
          indices: <int>[0],
        ),
      );
      await tester.pump();
      expect(built, hasLength(1));

      final VideoSlotToken? intruder = slots.acquire(
        onEvicted: () {},
        evictionRights: VideoSlotEvictionRights.evictUnpinned,
      );
      expect(intruder, isNotNull);
      await tester.pump();

      gate.complete();
      await tester.pump();
      await tester.pump();

      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
      expect(surfaceMounted(tester, 0), isFalse);
      expect(readyControlsEnabled(tester, 0), isFalse);
    });

    testWidgets('a stale load failure leaves the live attempt untouched', (
      WidgetTester tester,
    ) async {
      final LruVideoSlots slots = slotsWithCapOf(1);
      final Completer<void> gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) {
          gate.complete();
        }
      });
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(videoFixtureFile()),
          playerFactory: videoFactoryInto(
            built,
            setUpPlayer: (FakeEntryVideoPlayer player, int index) {
              if (index == 0) {
                player.loadGate = gate;
                player.loadError = StateError('decoder busy');
              }
            },
          ),
          slots: slots,
          indices: <int>[0],
        ),
      );
      await tester.pump();
      expect(built, hasLength(1));

      final VideoSlotToken? intruder = slots.acquire(
        onEvicted: () {},
        evictionRights: VideoSlotEvictionRights.evictUnpinned,
      );
      await tester.pump();
      slots.release(intruder);
      await tester.pump();
      await tester.pump();

      expect(built, hasLength(2));
      expect(surfaceMounted(tester, 0), isTrue);

      gate.complete();
      await tester.pump();
      await tester.pump(pastAllBackoff);
      await tester.pump();

      expect(built, hasLength(2));
      expect(built[1].disposeCalls, 0);
      expect(surfaceMounted(tester, 0), isTrue);
      expect(readyControlsEnabled(tester, 0), isTrue);
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
    });

    testWidgets('disposing a slot holding card promotes a waiting sibling', (
      WidgetTester tester,
    ) async {
      final LruVideoSlots slots = slotsWithCapOf(1);
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];
      final File file = videoFixtureFile();
      final FakeMediaResolver resolver = videoResolverFor(file);
      final EntryVideoPlayerFactory factory = videoFactoryInto(built);

      await tester.pumpWidget(
        videoCardColumn(
          resolver: resolver,
          playerFactory: factory,
          slots: slots,
          indices: <int>[0, 1],
        ),
      );
      await tester.pump();

      expect(built, hasLength(1));
      expect(surfaceMounted(tester, 0), isTrue);
      expect(surfaceMounted(tester, 1), isFalse);

      await tester.pumpWidget(
        videoCardColumn(
          resolver: resolver,
          playerFactory: factory,
          slots: slots,
          indices: <int>[1],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(built, hasLength(2));
      expect(built[1].loadCalls, <String>[file.path]);
      expect(surfaceMounted(tester, 1), isTrue);
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
    });

    testWidgets('tapping a waiting card claims a slot from a healthy holder', (
      WidgetTester tester,
    ) async {
      final LruVideoSlots slots = slotsWithCapOf(1);
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(videoFixtureFile()),
          playerFactory: videoFactoryInto(built),
          slots: slots,
          indices: <int>[0, 1],
        ),
      );
      await tester.pump();
      expect(built, hasLength(1));

      await tester.tap(inCard(1, videoPlayToggleKey));
      await tester.pump();
      await tester.pump();

      expect(built, hasLength(2));
      expect(built[1].playCalls, 1);
      expect(built[0].disposeCalls, 1);
      expect(surfaceMounted(tester, 1), isTrue);
      expect(surfaceMounted(tester, 0), isFalse);
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
    });

    testWidgets('a permanently denying registry leaves a tappable neutral card',
        (WidgetTester tester) async {
      final LruVideoSlots slots = LruVideoSlots(cap: 1);
      slots.dispose();
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(videoFixtureFile()),
          playerFactory: videoFactoryInto(built),
          slots: slots,
          indices: <int>[0],
        ),
      );
      await tester.pump();

      expect(built, isEmpty);
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
      expect(find.byType(NeutralMediaPlaceholder), findsOneWidget);
      expect(tapEnabled(tester, inCard(0, videoPlayToggleKey)), isTrue);
    });
  });

  group('VideoBody failure routing', () {
    testWidgets('a state stream error reloads instead of latching red', (
      WidgetTester tester,
    ) async {
      final LruVideoSlots slots = slotsWithCapOf(1);
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(videoFixtureFile()),
          playerFactory: videoFactoryInto(built),
          slots: slots,
          indices: <int>[0],
        ),
      );
      await tester.pump();
      expect(built, hasLength(1));

      built.single.emitStateError(StateError('state stream broke'));
      await tester.pump();
      await tester.pump(pastFirstBackoff);
      await tester.pump();

      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
      expect(built, hasLength(2));
      expect(built[0].disposeCalls, 1);
      expect(surfaceMounted(tester, 0), isTrue);
    });

    testWidgets('a position stream error reloads instead of latching red', (
      WidgetTester tester,
    ) async {
      final LruVideoSlots slots = slotsWithCapOf(1);
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(videoFixtureFile()),
          playerFactory: videoFactoryInto(built),
          slots: slots,
          indices: <int>[0],
        ),
      );
      await tester.pump();

      built.single.emitPositionError(StateError('position stream broke'));
      await tester.pump();
      await tester.pump(pastFirstBackoff);
      await tester.pump();

      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
      expect(built, hasLength(2));
      expect(built[0].disposeCalls, 1);
      expect(surfaceMounted(tester, 0), isTrue);
    });

    testWidgets('a playback error before ready releases the slot and retries', (
      WidgetTester tester,
    ) async {
      final LruVideoSlots slots = slotsWithCapOf(1);
      final Completer<void> gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) {
          gate.complete();
        }
      });
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(videoFixtureFile()),
          playerFactory: videoFactoryInto(
            built,
            setUpPlayer: (FakeEntryVideoPlayer player, int index) {
              if (index == 0) {
                player.loadGate = gate;
              }
            },
          ),
          slots: slots,
          indices: <int>[0],
        ),
      );
      await tester.pump();
      expect(built, hasLength(1));

      built.single.emitState(VideoPlaybackState.error);
      await tester.pump();

      expect(built[0].disposeCalls, 1);

      await tester.pump(pastFirstBackoff);
      await tester.pump();

      expect(built, hasLength(2));

      gate.complete();
      await tester.pump();
      await tester.pump();

      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
      expect(surfaceMounted(tester, 0), isTrue);
    });

    testWidgets('a mid playback error reclaims a slot from an unpinned sibling',
        (WidgetTester tester) async {
      final LruVideoSlots slots = slotsWithCapOf(2);
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(videoFixtureFile()),
          playerFactory: videoFactoryInto(built),
          slots: slots,
          indices: <int>[0, 1, 2],
        ),
      );
      await tester.pump();

      expect(built, hasLength(2));
      expect(surfaceMounted(tester, 2), isFalse);

      built[0].emitState(VideoPlaybackState.playing);
      built[0].emitPosition(const Duration(seconds: 5));
      await tester.pump();

      built[0].emitState(VideoPlaybackState.error);
      await tester.pump();
      await tester.pump();

      expect(built, hasLength(3));
      expect(surfaceMounted(tester, 2), isTrue);

      await tester.pump(pastFirstBackoff);
      await tester.pump();

      expect(built, hasLength(4));
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
      expect(surfaceMounted(tester, 0), isTrue);
      expect(readyControlsEnabled(tester, 0), isTrue);
      expect(built[0].disposeCalls, 1);
      expect(built[1].disposeCalls, 1);
      expect(built[3].seekCalls, <Duration>[const Duration(seconds: 5)]);
    });
  });

  group('VideoBody recovery of the control surface', () {
    testWidgets('the readout resumes after a reload interrupts a drag', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final LruVideoSlots slots = slotsWithCapOf(1);
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(videoFixtureFile()),
          playerFactory: videoFactoryInto(built),
          slots: slots,
          indices: <int>[0],
        ),
      );
      await tester.pump();

      final Rect bar = tester.getRect(inCard(0, videoScrubBarKey));
      final TestGesture gesture = await tester.startGesture(
        Offset(bar.center.dx - 40, bar.center.dy),
      );
      await gesture.moveTo(Offset(bar.center.dx, bar.center.dy));
      await tester.pump();

      expect(find.text('0:32 / 1:05'), findsOneWidget);

      final VideoSlotToken? intruder = slots.acquire(
        onEvicted: () {},
        evictionRights: VideoSlotEvictionRights.evictUnpinned,
      );
      await tester.pump();
      await tester.pump();
      await gesture.up();
      await tester.pump();

      slots.release(intruder);
      await tester.pump();
      await tester.pump();

      expect(built, hasLength(2));
      built[1].emitPosition(const Duration(seconds: 40));
      await tester.pump();

      expect(find.text('0:40 / 1:05'), findsOneWidget);
      expect(find.bySemanticsLabel('Video position'), findsOneWidget);
      expect(
        tester
            .getSemantics(inCard(0, videoScrubBarKey))
            .getSemanticsData()
            .value,
        '0:40 of 1:05',
      );
      handle.dispose();
    });

    testWidgets('an evicted card shows its captured poster again', (
      WidgetTester tester,
    ) async {
      final LruVideoSlots slots = slotsWithCapOf(1);
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

      expect(find.byType(MediaImage), findsOneWidget);

      built.single.emitState(VideoPlaybackState.playing);
      await tester.pump();

      expect(find.byType(MediaImage), findsNothing);

      built.single.emitState(VideoPlaybackState.paused);
      await tester.pump();

      final VideoSlotToken? intruder = slots.acquire(
        onEvicted: () {},
        evictionRights: VideoSlotEvictionRights.evictUnpinned,
      );
      expect(intruder, isNotNull);
      await tester.pump();
      await tester.pump();

      expect(find.byType(MediaImage), findsOneWidget);
      expect(surfaceMounted(tester, 0), isFalse);
    });
  });

  group('VideoBody resolver changes', () {
    testWidgets('a new resolver identity re-prepares an unavailable card', (
      WidgetTester tester,
    ) async {
      final LruVideoSlots slots = slotsWithCapOf(1);
      final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];
      final File file = videoFixtureFile();

      await tester.pumpWidget(
        videoCardColumn(
          resolver: FakeMediaResolver(),
          playerFactory: videoFactoryInto(built),
          slots: slots,
          indices: <int>[0],
        ),
      );
      await tester.pump();

      expect(find.byType(CorruptMediaPlaceholder), findsOneWidget);
      expect(built, isEmpty);

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(file),
          playerFactory: videoFactoryInto(built),
          slots: slots,
          indices: <int>[0],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
      expect(built, hasLength(1));
      expect(built.single.loadCalls, <String>[file.path]);
      expect(surfaceMounted(tester, 0), isTrue);
    });

    testWidgets('a new resolver identity returns the slot before re-preparing',
        (WidgetTester tester) async {
      final LruVideoSlots slots = slotsWithCapOf(1);
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
      expect(built, hasLength(1));

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(file),
          playerFactory: videoFactoryInto(built),
          slots: slots,
          indices: <int>[0],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(built, hasLength(2));
      expect(built[0].disposeCalls, 1);
      expect(surfaceMounted(tester, 0), isTrue);
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
    });
  });
}
