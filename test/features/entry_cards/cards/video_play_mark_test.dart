import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/dialog_host.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/video_body.dart';
import 'package:field_notes/features/entry_cards/cards/video_controls_overlay.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots.dart';
import 'package:field_notes/features/entry_cards/transport/transport.dart';
import 'package:field_notes/features/entry_cards/transport/transport_bar.dart'
    show PlayPauseGlyph, TransportReadout;
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/video_viewer_view.dart';

import '../support/entry_cards_harness.dart';
import '../support/fake_video_player.dart';
import '../support/video_card_harness.dart'
    show videoFixtureFile, videoResolverFor;

const Size _box = Size(800, 450);
const String _videoId = 'video-media';
const Duration _frame = Duration(milliseconds: 10);
const Duration _length = Duration(seconds: 65);

Entry _video({String mediaId = 'vid'}) => Entry(
  id: 'video-1',
  dayId: 'day-1',
  type: EntryType.video,
  mediaId: mediaId,
  durationMs: _length.inMilliseconds,
  createdAt: 0,
  updatedAt: 0,
);

Widget _bodyHost(FakeEntryVideoPlayer player, {bool reduceMotion = false}) {
  final FakeMediaResolver resolver = videoResolverFor(videoFixtureFile())
    ..memoize('vid');
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Center(
        child: SizedBox.fromSize(
          size: _box,
          child: VideoBody(
            key: ValueKey<bool>(reduceMotion),
            entry: _video(),
            resolver: resolver,
            playerFactory: () => player,
            slots: const UnlimitedVideoSlots(),
            aspectRatio: 16 / 9,
            controlModel: VideoControlModel.pointer,
            controls: (BuildContext context, VideoControlsState state) =>
                const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
}

Future<FakeEntryVideoPlayer> _playingBody(
  WidgetTester tester, {
  bool reduceMotion = false,
}) async {
  final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
  await tester.pumpWidget(_bodyHost(player, reduceMotion: reduceMotion));
  await tester.pump();
  await tester.pump();
  player.emitState(VideoPlaybackState.playing);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return player;
}

Future<void> _advance(WidgetTester tester, Duration by) async {
  Duration passed = Duration.zero;
  while (passed < by) {
    final Duration step = by - passed < _frame ? by - passed : _frame;
    await tester.pump(step);
    passed += step;
  }
}

Future<void> _click(WidgetTester tester) async {
  await tester.tapAt(
    tester.getCenter(find.byType(VideoBody)),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await tester.pump();
}

double _opacityAbove(WidgetTester tester, Finder finder) {
  double opacity = 1;
  RenderObject? node = tester.renderObject(finder);
  while (node != null) {
    if (node is RenderAnimatedOpacity) {
      opacity *= node.opacity.value;
    }
    if (node is RenderOpacity) {
      opacity *= node.opacity;
    }
    node = node.parent;
  }
  return opacity;
}

Finder get _mark => find.byKey(videoPlayMarkKey);

FakeMediaResolver _viewerResolver() {
  final Directory folder = Directory.systemTemp.createTempSync('play-mark');
  addTearDown(() => folder.deleteSync(recursive: true));
  final File clip = File('${folder.path}/clip.mp4')
    ..writeAsBytesSync(List<int>.filled(8, 0));
  return FakeMediaResolver()..set(
    _videoId,
    ResolvedMedia.available(
      blob: blobOf(id: _videoId, relPath: 'clip.mp4', kind: MediaKind.video),
      file: clip,
    ),
  );
}

LogViewerScene _scene() => LogViewerScene(
  entry: _video(mediaId: _videoId),
  date: '2025-10-02',
  dayTitle: 'Thursday 2 October',
  mood: Mood.calm,
  index: 1,
  count: 3,
  earlier: null,
  later: null,
  exit: LogViewerExit.close,
  onBack: () {},
  onEarlier: () {},
  onLater: () {},
  onDelete: () {},
  onEdit: null,
);

void main() {
  testWidgets(
    'a click on the picture pauses at once and shows the pause mark in the centre',
    (WidgetTester tester) async {
      final FakeEntryVideoPlayer player = await _playingBody(tester);
      expect(_mark, findsNothing);

      await tester.tapAt(
        tester.getCenter(find.byType(VideoBody)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();

      expect(player.pauseCalls, 1);
      expect(_mark, findsOneWidget);
      expect(tester.getSize(_mark), const Size(68, 68));
      final Offset centre = tester.getCenter(_mark);
      final Offset box = tester.getCenter(find.byType(VideoBody));
      expect(centre.dx, closeTo(box.dx, 0.5));
      expect(centre.dy, closeTo(box.dy, 0.5));
      final BoxDecoration face =
          tester.widget<Container>(_mark).decoration! as BoxDecoration;
      expect(face.shape, BoxShape.circle);
      expect(face.color!.r, 0);
      expect(face.color!.g, 0);
      expect(face.color!.b, 0);
      expect(face.color!.a * 255, closeTo(128, 1));
      final PlayPauseGlyph glyph = tester.widget<PlayPauseGlyph>(
        find.descendant(of: _mark, matching: find.byType(PlayPauseGlyph)),
      );
      expect(glyph.playing, isTrue, reason: 'the pause glyph');
      expect(glyph.color, const Color(0xFFFFFFFF));

      await tester.pump();
      await _advance(tester, const Duration(milliseconds: 560));
      expect(_mark, findsNothing);
    },
  );

  testWidgets(
    'the play mark swells as it fades and only fades with reduced motion',
    (WidgetTester tester) async {
      await _playingBody(tester);
      await _click(tester);
      final Size first = tester.getRect(_mark).size;
      await _advance(tester, const Duration(milliseconds: 280));
      final Size swollen = tester.getRect(_mark).size;
      expect(swollen.width, greaterThan(first.width));
      expect(swollen.height, greaterThan(first.height));
      final double fading = _opacityAbove(tester, _mark);
      expect(fading, greaterThan(0));
      expect(fading, lessThan(1));
      await _advance(tester, const Duration(milliseconds: 400));

      await _playingBody(tester, reduceMotion: true);
      await _click(tester);
      final Size still = tester.getRect(_mark).size;
      final double opaque = _opacityAbove(tester, _mark);
      await _advance(tester, const Duration(milliseconds: 280));
      expect(tester.getRect(_mark).size, still);
      expect(_opacityAbove(tester, _mark), lessThan(opaque));
    },
  );

  testWidgets('a keyboard skip in the full view shows its label near the top', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final LruVideoSlots slots = LruVideoSlots(cap: 2);
    addTearDown(slots.dispose);
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer()
      ..duration = _length;
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          videoAspectProvider.overrideWith((Ref ref, String mediaId) => 16 / 9),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fieldNotesTheme(
            platform: TargetPlatform.macOS,
            brightness: Brightness.dark,
          ),
          home: DialogHost(
            child: VideoViewerView(
              scene: _scene(),
              resolver: _viewerResolver(),
              playerFactory: () => player,
              slots: slots,
              focus: PlaybackFocus(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    player
      ..emitState(VideoPlaybackState.playing)
      ..emitPosition(const Duration(seconds: 20));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    final Finder label = find.byKey(videoSkipLabelKey);
    expect(label, findsOneWidget);
    expect(
      find.descendant(of: label, matching: find.text('Forward 10 seconds')),
      findsOneWidget,
    );
    expect(find.text('Forward 10 seconds'), findsOneWidget);
    expect(find.byType(TransportReadout), findsNothing);
    expect(find.text('+10 s'), findsNothing);
    final Rect box = tester.getRect(find.byType(VideoBody));
    expect(tester.getCenter(label).dy - box.top, lessThan(box.height / 4));

    await tester.pump(const Duration(seconds: 2));
    expect(label, findsNothing);
  });
}
