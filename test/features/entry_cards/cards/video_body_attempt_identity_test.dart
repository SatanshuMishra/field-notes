import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/entry_cards/media/media_placeholders.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots.dart';

import '../support/fake_video_player.dart';
import '../support/video_card_harness.dart';

class TracedVideoPlayer extends FakeEntryVideoPlayer {
  TracedVideoPlayer(this.id);

  final int id;
  Completer<void>? seekGate;
  Completer<void>? playGate;
  Completer<void>? volumeGate;
  Object? playError;

  ValueKey<String> get identityKey => ValueKey<String>('traced-player-$id');

  @override
  Widget buildSurface() => SizedBox(
        key: videoSurfaceKey,
        width: 160,
        height: 90,
        child: SizedBox(key: identityKey),
      );

  @override
  Future<void> seek(Duration position) async {
    await _passGate(seekGate);
    await super.seek(position);
  }

  @override
  Future<void> play() async {
    await _passGate(playGate);
    final Object? error = playError;
    if (error != null) {
      throw error;
    }
    await super.play();
  }

  @override
  Future<void> setVolume(double volume) async {
    await _passGate(volumeGate);
    await super.setVolume(volume);
  }

  Future<void> _passGate(Completer<void>? gate) async {
    if (gate == null) {
      return;
    }
    await gate.future;
  }
}

typedef TracedPlayerSetup = void Function(TracedVideoPlayer player, int index);

EntryVideoPlayerFactory tracedFactoryInto(
  List<TracedVideoPlayer> built, {
  TracedPlayerSetup? setUpPlayer,
}) {
  return () {
    final TracedVideoPlayer player = TracedVideoPlayer(built.length);
    setUpPlayer?.call(player, built.length);
    built.add(player);
    return player;
  };
}

Completer<void> releasableGate() {
  final Completer<void> gate = Completer<void>();
  addTearDown(() {
    if (!gate.isCompleted) {
      gate.complete();
    }
  });
  return gate;
}

TracedVideoPlayer playerRenderedIn(
  WidgetTester tester,
  List<TracedVideoPlayer> built,
  int card,
) {
  for (final TracedVideoPlayer player in built) {
    final Finder rendered = find.descendant(
      of: cardAt(card),
      matching: find.byKey(player.identityKey),
    );
    if (rendered.evaluate().isNotEmpty) {
      return player;
    }
  }
  fail('no video surface is mounted in card $card');
}

Finder semanticsIn(int card, String label) => find.descendant(
      of: cardAt(card),
      matching: find.bySemanticsLabel(label),
    );

void main() {
  group('VideoBody attempt identity across awaits', () {
    testWidgets('a recovery during the resume seek still plays what was asked',
        (WidgetTester tester) async {
      final LruVideoSlots slots = slotsWithCapOf(1);
      final Completer<void> seekGate = releasableGate();
      final List<TracedVideoPlayer> built = <TracedVideoPlayer>[];

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(videoFixtureFile()),
          playerFactory: tracedFactoryInto(
            built,
            setUpPlayer: (TracedVideoPlayer player, int index) {
              if (index == 2) {
                player.seekGate = seekGate;
              }
            },
          ),
          slots: slots,
          indices: <int>[0, 1],
        ),
      );
      await tester.pump();

      expect(built, hasLength(1));

      built[0].emitPosition(const Duration(seconds: 5));
      await tester.pump();

      await tester.tap(inCard(1, videoPlayToggleKey));
      await tester.pump();
      await tester.pump();

      expect(built, hasLength(2));
      expect(surfaceMounted(tester, 0), isFalse);

      built[1].emitState(VideoPlaybackState.paused);
      await tester.pump();

      await tester.tap(inCard(0, videoPlayToggleKey));
      await tester.pump();
      await tester.pump();

      expect(built, hasLength(3));
      expect(built[2].seekCalls, isEmpty);

      built[2].emitState(VideoPlaybackState.error);
      await tester.pump();

      seekGate.complete();
      await tester.pump();
      await tester.pump(pastFirstBackoff);
      await tester.pump();
      await tester.pump();

      final TracedVideoPlayer live = playerRenderedIn(tester, built, 0);
      expect(live.playCalls, 1);
      expect(live.seekCalls, <Duration>[const Duration(seconds: 5)]);
      expect(readyControlsEnabled(tester, 0), isTrue);
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
    });

    testWidgets('a stale play rejection leaves the fresh attempt loading', (
      WidgetTester tester,
    ) async {
      final LruVideoSlots slots = slotsWithCapOf(2);
      final Completer<void> playGate = releasableGate();
      final Completer<void> loadGate = releasableGate();
      final List<TracedVideoPlayer> built = <TracedVideoPlayer>[];
      final File file = videoFixtureFile();
      final EntryVideoPlayerFactory factory = tracedFactoryInto(
        built,
        setUpPlayer: (TracedVideoPlayer player, int index) {
          if (index == 0) {
            player.playGate = playGate;
            player.playError = StateError('decoder rejected play');
          }
          if (index >= 2) {
            player.loadGate = loadGate;
          }
        },
      );

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(file),
          playerFactory: factory,
          slots: slots,
          indices: <int>[0, 1],
        ),
      );
      await tester.pump();

      expect(built, hasLength(2));
      expect(readyControlsEnabled(tester, 0), isTrue);

      await tester.tap(inCard(0, videoPlayToggleKey));
      await tester.pump();

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(file),
          playerFactory: factory,
          slots: slots,
          indices: <int>[0, 1],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(built, hasLength(4));
      expect(built[2].loadCalls, <String>[file.path]);
      expect(readyControlsEnabled(tester, 0), isFalse);

      playGate.complete();
      await tester.pump();
      await tester.pump();

      expect(built[2].disposeCalls, 0);

      loadGate.complete();
      await tester.pump();
      await tester.pump();

      expect(playerRenderedIn(tester, built, 0).id, 2);
      expect(readyControlsEnabled(tester, 0), isTrue);
      expect(built, hasLength(4));
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
    });

    testWidgets('a reloaded card mutes the player the user muted', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final LruVideoSlots slots = slotsWithCapOf(1);
      final List<TracedVideoPlayer> built = <TracedVideoPlayer>[];

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(videoFixtureFile()),
          playerFactory: tracedFactoryInto(built),
          slots: slots,
          indices: <int>[0, 1],
        ),
      );
      await tester.pump();

      await tester.tap(inCard(0, videoMuteToggleKey));
      await tester.pump();

      expect(built[0].volumeCalls, <double>[0.0]);
      expect(semanticsIn(0, 'Unmute video'), findsOneWidget);

      await tester.tap(inCard(1, videoPlayToggleKey));
      await tester.pump();
      await tester.pump();

      expect(built, hasLength(2));
      expect(surfaceMounted(tester, 0), isFalse);

      built[1].emitState(VideoPlaybackState.paused);
      await tester.pump();

      await tester.tap(inCard(0, videoPlayToggleKey));
      await tester.pump();
      await tester.pump();

      final TracedVideoPlayer live = playerRenderedIn(tester, built, 0);
      expect(live.volumeCalls, <double>[0.0]);
      expect(live.playCalls, 1);
      expect(semanticsIn(0, 'Unmute video'), findsOneWidget);
      expect(semanticsIn(0, 'Mute video'), findsNothing);
      handle.dispose();
    });

    testWidgets('a mute resolving after an eviction never paints a false mute',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final LruVideoSlots slots = slotsWithCapOf(1);
      final Completer<void> volumeGate = releasableGate();
      final List<TracedVideoPlayer> built = <TracedVideoPlayer>[];

      await tester.pumpWidget(
        videoCardColumn(
          resolver: videoResolverFor(videoFixtureFile()),
          playerFactory: tracedFactoryInto(
            built,
            setUpPlayer: (TracedVideoPlayer player, int index) {
              if (index == 0) {
                player.volumeGate = volumeGate;
              }
            },
          ),
          slots: slots,
          indices: <int>[0, 1],
        ),
      );
      await tester.pump();

      await tester.tap(inCard(0, videoMuteToggleKey));
      await tester.pump();

      expect(built[0].volumeCalls, isEmpty);

      await tester.tap(inCard(1, videoPlayToggleKey));
      await tester.pump();
      await tester.pump();

      expect(built, hasLength(2));

      built[1].emitState(VideoPlaybackState.paused);
      await tester.pump();

      await tester.tap(inCard(0, videoPlayToggleKey));
      await tester.pump();
      await tester.pump();

      final TracedVideoPlayer live = playerRenderedIn(tester, built, 0);

      volumeGate.complete();
      await tester.pump();
      await tester.pump();

      expect(semanticsIn(0, 'Unmute video'), findsNothing);
      expect(semanticsIn(0, 'Mute video'), findsOneWidget);
      expect(live.volumeCalls, isEmpty);
      handle.dispose();
    });
  });
}
