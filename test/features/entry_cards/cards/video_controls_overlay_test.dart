import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/features/entry_cards/cards/video_controls_overlay.dart';
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';

import '../support/fake_video_player.dart';
import '../support/video_card_harness.dart';

const String _pauseLabel = 'Pause video';
const String _playLabel = 'Play video';

SemanticsFinder _reachable(String label) => find.semantics.byLabel(label);

const Duration _fadeMargin = Duration(milliseconds: 1);

Future<void> _settleFade(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(Motion.fade + _fadeMargin);
  await tester.pump(Motion.fade + _fadeMargin);
}

Future<void> _idlePastHideDelay(WidgetTester tester) async {
  await tester.pump(kVideoControlsHideDelay);
  await _settleFade(tester);
}

Future<TestGesture> _mouseOutsideTheCard(WidgetTester tester) async {
  final TestGesture mouse =
      await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: videoPointClearOfTheCard(tester, 0));
  addTearDown(mouse.removePointer);
  return mouse;
}

Future<List<FakeEntryVideoPlayer>> _pumpPlayingCard(
  WidgetTester tester, {
  MediaQueryData media = const MediaQueryData(),
}) async {
  final List<FakeEntryVideoPlayer> built = <FakeEntryVideoPlayer>[];
  await tester.pumpWidget(
    videoCardColumn(
      resolver: videoResolverFor(videoFixtureFile()),
      playerFactory: videoFactoryInto(built),
      slots: slotsWithCapOf(1),
      indices: <int>[0],
      media: media,
    ),
  );
  await tester.pump();
  built.single.emitState(VideoPlaybackState.playing);
  await tester.pump();
  return built;
}

bool _canAutoHide({
  bool controlsEnabled = true,
  bool isPlaying = true,
  bool focusWithin = false,
  bool accessibleNavigation = false,
}) =>
    canAutoHideVideoControls(
      controlsEnabled: controlsEnabled,
      isPlaying: isPlaying,
      focusWithin: focusWithin,
      accessibleNavigation: accessibleNavigation,
    );

void main() {
  group('canAutoHideVideoControls', () {
    test('allows hiding only while enabled controls play unattended', () {
      expect(_canAutoHide(), isTrue);
    });

    test('refuses to hide controls that are not enabled', () {
      expect(_canAutoHide(controlsEnabled: false), isFalse);
    });

    test('refuses to hide controls that are not playing', () {
      expect(_canAutoHide(isPlaying: false), isFalse);
    });

    test('refuses to hide controls that hold keyboard focus', () {
      expect(_canAutoHide(focusWithin: true), isFalse);
    });

    test('refuses to hide controls under assistive navigation', () {
      expect(_canAutoHide(accessibleNavigation: true), isFalse);
    });
  });

  group('videoControlsVisible', () {
    test('shows controls that cannot auto hide whatever the hidden flag', () {
      expect(videoControlsVisible(canAutoHide: false, hidden: true), isTrue);
      expect(videoControlsVisible(canAutoHide: false, hidden: false), isTrue);
    });

    test('honours the hidden flag only while auto hiding is allowed', () {
      expect(videoControlsVisible(canAutoHide: true, hidden: true), isFalse);
      expect(videoControlsVisible(canAutoHide: true, hidden: false), isTrue);
    });
  });

  group('resolveVideoControlModel', () {
    test('gives macOS the pointer model', () {
      expect(
        resolveVideoControlModel(TargetPlatform.macOS),
        VideoControlModel.pointer,
      );
    });

    test('gives Android the touch model', () {
      expect(
        resolveVideoControlModel(TargetPlatform.android),
        VideoControlModel.touch,
      );
    });
  });

  group('VideoControlsOverlay on touch', () {
    testWidgets('a tap on hidden controls reveals them without toggling '
        'playback', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        final List<FakeEntryVideoPlayer> built = await _pumpPlayingCard(tester);

        expect(_reachable(_pauseLabel), findsOne);

        await _idlePastHideDelay(tester);

        expect(_reachable(_pauseLabel), findsNothing);

        await tester.tapAt(videoSurfacePoint(tester, 0));
        await _settleFade(tester);

        expect(_reachable(_pauseLabel), findsOne);
        expect(built.single.pauseCalls, 0);
        expect(built.single.playCalls, 0);
      } finally {
        handle.dispose();
      }
    }, variant: useTargetPlatform(TargetPlatform.android));
  });

  group('VideoControlsOverlay on pointer', () {
    testWidgets('hovering reveals the controls that three idle seconds hide', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        final List<FakeEntryVideoPlayer> built = await _pumpPlayingCard(tester);
        final TestGesture mouse = await _mouseOutsideTheCard(tester);
        final Offset surface = videoSurfacePoint(tester, 0);

        expect(_reachable(_pauseLabel), findsOne);

        await _idlePastHideDelay(tester);

        expect(_reachable(_pauseLabel), findsNothing);

        await mouse.moveTo(surface);
        await _settleFade(tester);

        expect(_reachable(_pauseLabel), findsOne);

        await _idlePastHideDelay(tester);

        expect(_reachable(_pauseLabel), findsNothing);

        await mouse.moveTo(surface + const Offset(12, 0));
        await _settleFade(tester);

        expect(_reachable(_pauseLabel), findsOne);

        await _idlePastHideDelay(tester);

        expect(_reachable(_pauseLabel), findsNothing);

        await tester.tapAt(tester.getCenter(inCard(0, videoMuteToggleKey)));
        await _settleFade(tester);

        expect(built.single.volumeCalls, isEmpty);

        await tester.tap(inCard(0, videoMuteToggleKey));
        await tester.pump();

        expect(built.single.volumeCalls, <double>[0.0]);
      } finally {
        handle.dispose();
      }
    }, variant: useTargetPlatform(TargetPlatform.macOS));

    testWidgets('a click on the surface toggles playback instead of only '
        'revealing', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        final List<FakeEntryVideoPlayer> built = await _pumpPlayingCard(tester);
        final TestGesture mouse = await _mouseOutsideTheCard(tester);
        final Offset surface = videoSurfacePoint(tester, 0);

        await _idlePastHideDelay(tester);

        expect(_reachable(_pauseLabel), findsNothing);

        await mouse.moveTo(surface);
        await mouse.down(surface);
        await mouse.up();
        await _settleFade(tester);

        expect(built.single.pauseCalls, 1);
        expect(_reachable(_pauseLabel), findsOne);
      } finally {
        handle.dispose();
      }
    }, variant: useTargetPlatform(TargetPlatform.macOS));
  });

  group('VideoControlsOverlay when playback stops', () {
    testWidgets('a paused card never auto hides its controls', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        final List<FakeEntryVideoPlayer> built = await _pumpPlayingCard(tester);

        expect(_reachable(_pauseLabel), findsOne);

        await _idlePastHideDelay(tester);

        expect(_reachable(_pauseLabel), findsNothing);

        built.single.emitState(VideoPlaybackState.paused);
        await _settleFade(tester);

        expect(_reachable(_playLabel), findsOne);

        await _idlePastHideDelay(tester);

        expect(_reachable(_playLabel), findsOne);
      } finally {
        handle.dispose();
      }
    }, variant: useTargetPlatform(TargetPlatform.android));

    testWidgets('a completed card never auto hides and still replays', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        final List<FakeEntryVideoPlayer> built = await _pumpPlayingCard(tester);

        expect(_reachable(_pauseLabel), findsOne);

        await _idlePastHideDelay(tester);

        expect(_reachable(_pauseLabel), findsNothing);

        built.single.emitState(VideoPlaybackState.completed);
        await _settleFade(tester);

        expect(_reachable(_playLabel), findsOne);

        await _idlePastHideDelay(tester);

        expect(_reachable(_playLabel), findsOne);

        await tester.tap(inCard(0, videoPlayToggleKey));
        await tester.pump();

        expect(built.single.playCalls, 1);
        expect(built.single.seekCalls, <Duration>[Duration.zero]);
      } finally {
        handle.dispose();
      }
    }, variant: useTargetPlatform(TargetPlatform.android));

    testWidgets('a card resumed after auto hiding shows its controls again for '
        'the whole delay', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        final List<FakeEntryVideoPlayer> built = await _pumpPlayingCard(tester);

        expect(_reachable(_pauseLabel), findsOne);

        await _idlePastHideDelay(tester);

        expect(_reachable(_pauseLabel), findsNothing);

        built.single.emitState(VideoPlaybackState.paused);
        await _settleFade(tester);

        expect(_reachable(_playLabel), findsOne);

        built.single.emitState(VideoPlaybackState.playing);
        await _settleFade(tester);

        expect(_reachable(_pauseLabel), findsOne);

        await _idlePastHideDelay(tester);

        expect(_reachable(_pauseLabel), findsNothing);
      } finally {
        handle.dispose();
      }
    }, variant: useTargetPlatform(TargetPlatform.macOS));

    testWidgets('a decoder lost while the controls are hidden leaves a '
        'reachable play affordance', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        final List<FakeEntryVideoPlayer> built = await _pumpPlayingCard(tester);

        expect(_reachable(_pauseLabel), findsOne);

        await _idlePastHideDelay(tester);

        expect(_reachable(_pauseLabel), findsNothing);

        built.single.emitStateError(StateError('decoder lost'));
        await _settleFade(tester);

        expect(find.byType(CorruptMediaPlaceholder), findsNothing);
        expect(_reachable(_playLabel), findsOne);

        await _idlePastHideDelay(tester);

        expect(find.byType(CorruptMediaPlaceholder), findsNothing);
        expect(_reachable(_playLabel), findsOne);
      } finally {
        handle.dispose();
      }
    }, variant: useTargetPlatform(TargetPlatform.android));
  });

  group('VideoControlsOverlay accessibility', () {
    testWidgets('keyboard focus inside the controls suspends the hide timer', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await _pumpPlayingCard(tester);

        expect(_reachable(_pauseLabel), findsOne);

        Focus.of(tester.element(inCard(0, videoScrubBarKey))).requestFocus();
        await tester.pump();

        await _idlePastHideDelay(tester);

        expect(_reachable(_pauseLabel), findsOne);
      } finally {
        handle.dispose();
      }
    }, variant: useTargetPlatform(TargetPlatform.macOS));

    testWidgets('assistive navigation disables the hide timeout outright', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await _pumpPlayingCard(
          tester,
          media: const MediaQueryData(accessibleNavigation: true),
        );

        expect(_reachable(_pauseLabel), findsOne);

        await _idlePastHideDelay(tester);

        expect(_reachable(_pauseLabel), findsOne);
      } finally {
        handle.dispose();
      }
    }, variant: useTargetPlatform(TargetPlatform.android));
  });
}
