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
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/video_body.dart';
import 'package:field_notes/features/entry_cards/compact/log_actions_pill.dart';
import 'package:field_notes/features/entry_cards/media/media_image.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots.dart';
import 'package:field_notes/features/entry_cards/transport/transport.dart';
import 'package:field_notes/features/entry_cards/transport/transport_bar.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/video_viewer_view.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';
import 'package:field_notes/state/media_provider.dart';

import '../entry_cards/support/entry_cards_harness.dart';
import '../entry_cards/support/fake_video_player.dart';

const Color _black = Color(0xFF0E0B09);

const double _statusBar = 34;
const double _gestureBar = 24;
const double _titleBar = 42;
const int _durationMs = 65000;
const String _videoId = 'video-media';
const String _posterId = 'video-poster';
const String _dayTitle = 'Thursday 2 October';
const Size _portrait = Size(1080, 1920);
const Size _landscape = Size(1920, 1080);
const Offset _phonePicture = Offset(192, 416);
const Duration _pastDoubleTap = Duration(milliseconds: 301);

final class _Calls {
  int back = 0;
  int earlier = 0;
  int later = 0;
  int delete = 0;
  final List<String?> titles = <String?>[];

  Future<bool> rename(String? title) async {
    titles.add(title);
    return true;
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(384, 832);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  tester.view.viewPadding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  addTearDown(tester.view.reset);
}

void _mac(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
}

FakeMediaResolver _resolver({bool poster = false}) {
  final Directory folder = Directory.systemTemp.createTempSync(
    'video-viewer-view',
  );
  addTearDown(() => folder.deleteSync(recursive: true));
  final File clip = File('${folder.path}/clip.mp4')
    ..writeAsBytesSync(List<int>.filled(8, 0));
  final FakeMediaResolver resolver = FakeMediaResolver()
    ..set(
      _videoId,
      ResolvedMedia.available(
        blob: blobOf(id: _videoId, relPath: 'clip.mp4', kind: MediaKind.video),
        file: clip,
      ),
    );
  if (poster) {
    final File still = File('${folder.path}/poster.png')
      ..writeAsBytesSync(onePixelPngBytes());
    resolver.set(
      _posterId,
      ResolvedMedia.available(
        blob: blobOf(id: _posterId, relPath: 'poster.png'),
        file: still,
      ),
    );
  }
  return resolver;
}

LruVideoSlots _slots() {
  final LruVideoSlots slots = LruVideoSlots(cap: 2);
  addTearDown(slots.dispose);
  return slots;
}

LogViewerScene _scene(
  _Calls calls, {
  bool poster = false,
  LogViewerExit exit = LogViewerExit.close,
  bool earlier = true,
  bool later = true,
  String? title,
}) {
  return LogViewerScene(
    entry: Entry(
      id: 'video-entry',
      dayId: 'd1',
      type: EntryType.video,
      title: title,
      mediaId: _videoId,
      thumbnailMediaId: poster ? _posterId : null,
      durationMs: _durationMs,
      createdAt: 0,
      updatedAt: 0,
    ),
    date: '2025-10-02',
    dayTitle: _dayTitle,
    mood: Mood.calm,
    index: 1,
    count: 3,
    earlier: null,
    later: null,
    exit: exit,
    onBack: () => calls.back++,
    onEarlier: earlier ? () => calls.earlier++ : null,
    onLater: later ? () => calls.later++ : null,
    onDelete: () => calls.delete++,
    onEdit: null,
    onRename: calls.rename,
  );
}

Widget _host(
  LogViewerScene scene, {
  required MediaResolver resolver,
  required FakeEntryVideoPlayer player,
  required VideoSlots slots,
  required TargetPlatform platform,
  required Size? recorded,
  Brightness brightness = Brightness.dark,
}) {
  return ProviderScope(
    key: ValueKey<String>('$platform-$brightness'),
    overrides: <Override>[
      videoAspectProvider.overrideWith(
        (Ref ref, String mediaId) =>
            recorded == null ? null : recorded.width / recorded.height,
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform, brightness: brightness),
      home: DialogHost(
        child: VideoViewerView(
          scene: scene,
          resolver: resolver,
          playerFactory: () => player,
          slots: slots,
          focus: PlaybackFocus(),
        ),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Finder get _frame => find.byKey(videoFrameKey);

void _expectUnclipped(WidgetTester tester) {
  final Rect frame = tester.getRect(_frame);
  RenderObject? node = tester.renderObject(_frame).parent;
  while (node != null) {
    if (node is RenderClipRect ||
        node is RenderClipRRect ||
        node is RenderClipPath ||
        node is RenderClipOval) {
      final RenderBox box = node as RenderBox;
      final Rect clip = box.localToGlobal(Offset.zero) & box.size;
      expect(clip.left, lessThanOrEqualTo(frame.left + 0.01));
      expect(clip.top, lessThanOrEqualTo(frame.top + 0.01));
      expect(clip.right, greaterThanOrEqualTo(frame.right - 0.01));
      expect(clip.bottom, greaterThanOrEqualTo(frame.bottom - 0.01));
    }
    node = node.parent;
  }
}

void _expectRect(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, 0.01));
  expect(actual.top, closeTo(expected.top, 0.01));
  expect(actual.width, closeTo(expected.width, 0.01));
  expect(actual.height, closeTo(expected.height, 0.01));
}

Finder _groundBox() {
  return find
      .descendant(
        of: find.byType(ViewerStage),
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is ColoredBox &&
              widget.color.toARGB32() == _black.toARGB32(),
        ),
      )
      .first;
}

Finder get _play => find.byType(TransportPlayButton);

bool _controlsShown(WidgetTester tester) {
  final AnimatedOpacity fade = tester.widget<AnimatedOpacity>(
    find
        .ancestor(
          of: find.byType(ViewerLogBar),
          matching: find.byType(AnimatedOpacity),
        )
        .first,
  );
  return fade.opacity == 1;
}

Future<void> _openOn(
  WidgetTester tester,
  LogViewerScene scene,
  FakeEntryVideoPlayer player,
  TargetPlatform platform, {
  Brightness brightness = Brightness.dark,
}) async {
  await tester.pumpWidget(
    _host(
      scene,
      resolver: _resolver(),
      player: player,
      slots: _slots(),
      platform: platform,
      recorded: platform == TargetPlatform.android ? _portrait : _landscape,
      brightness: brightness,
    ),
  );
  await _settle(tester);
}

Future<void> _startPlaying(
  WidgetTester tester,
  FakeEntryVideoPlayer player,
) async {
  await tester.tap(_play);
  await tester.pump();
  player.emitState(VideoPlaybackState.playing);
  await tester.pump();
}

void main() {
  testWidgets('a portrait video is never cropped on the phone', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    const double height = 384 * 1920 / 1080;
    const Rect fitted = Rect.fromLTWH(0, (832 - height) / 2, 384, height);

    for (final Brightness brightness in Brightness.values) {
      final FakeEntryVideoPlayer player = FakeEntryVideoPlayer()
        ..uprightSize = _portrait;
      await tester.pumpWidget(
        _host(
          _scene(_Calls(), poster: true),
          resolver: _resolver(poster: true),
          player: player,
          slots: _slots(),
          platform: TargetPlatform.android,
          recorded: _portrait,
          brightness: brightness,
        ),
      );
      await _settle(tester);

      expect(player.loadCalls, isEmpty);
      expect(tester.getRect(_groundBox()), const Rect.fromLTWH(0, 0, 384, 832));
      final Rect frame = tester.getRect(_frame);
      _expectRect(frame, fitted);
      expect(frame.height, closeTo(682.7, 0.05));
      expect(frame.center.dy, closeTo(832 / 2, 0.01));
      _expectUnclipped(tester);

      final MediaImage poster = tester.widget<MediaImage>(
        find.descendant(of: _frame, matching: find.byType(MediaImage)),
      );
      expect(poster.mediaId, _posterId);
      expect(poster.fit, BoxFit.contain);
    }

    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer()
      ..uprightSize = _portrait;
    await tester.pumpWidget(
      _host(
        _scene(_Calls(), poster: true),
        resolver: _resolver(poster: true),
        player: player,
        slots: _slots(),
        platform: TargetPlatform.android,
        recorded: null,
      ),
    );
    await _settle(tester);
    _expectRect(
      tester.getRect(_frame),
      const Rect.fromLTWH(0, (832 - 216) / 2, 384, 216),
    );

    await tester.tap(_play);
    await _settle(tester);
    expect(player.loadCalls, hasLength(1));
    expect(player.playCalls, 1);

    player.emitState(VideoPlaybackState.playing);
    await tester.pump();

    expect(find.byType(MediaImage), findsNothing);
    _expectRect(tester.getRect(_frame), fitted);
    _expectUnclipped(tester);
  });

  testWidgets("a landscape video fills the Mac window's width", (
    WidgetTester tester,
  ) async {
    _mac(tester);
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
    await tester.pumpWidget(
      _host(
        _scene(_Calls(), exit: LogViewerExit.back),
        resolver: _resolver(),
        player: player,
        slots: _slots(),
        platform: TargetPlatform.macOS,
        recorded: _landscape,
      ),
    );
    await _settle(tester);

    expect(
      tester.getRect(_groundBox()),
      const Rect.fromLTWH(0, _titleBar, 1440, 900 - _titleBar),
    );
    _expectRect(
      tester.getRect(_frame),
      const Rect.fromLTWH(0, _titleBar + (858 - 810) / 2, 1440, 810),
    );
    _expectUnclipped(tester);
  });

  testWidgets("a portrait video fills the Mac window's height", (
    WidgetTester tester,
  ) async {
    _mac(tester);
    const double width = 858 * 1080 / 1920;
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
    await tester.pumpWidget(
      _host(
        _scene(_Calls(), exit: LogViewerExit.back),
        resolver: _resolver(),
        player: player,
        slots: _slots(),
        platform: TargetPlatform.macOS,
        recorded: _portrait,
      ),
    );
    await _settle(tester);

    final Rect frame = tester.getRect(_frame);
    _expectRect(
      frame,
      const Rect.fromLTWH((1440 - width) / 2, _titleBar, width, 858),
    );
    expect(frame.width, closeTo(482.6, 0.05));
    expect(frame.center.dx, closeTo(720, 0.01));
    _expectUnclipped(tester);
  });

  testWidgets('controls fade after 3 seconds of playing and return on play', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
    await _openOn(tester, _scene(_Calls()), player, TargetPlatform.android);
    expect(player.loadCalls, hasLength(1));
    expect(_controlsShown(tester), isTrue);

    await _startPlaying(tester, player);
    expect(player.playCalls, 1);

    await tester.pump(const Duration(milliseconds: 2900));
    expect(_controlsShown(tester), isTrue);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_controlsShown(tester), isFalse);
    expect(find.byKey(logViewerEarlierKey).hitTestable(), findsNothing);

    await tester.tapAt(_phonePicture);
    await tester.pump(_pastDoubleTap);
    expect(_controlsShown(tester), isTrue);
    await tester.tapAt(_phonePicture);
    await tester.pump(_pastDoubleTap);
    expect(_controlsShown(tester), isFalse);
    await tester.tapAt(_phonePicture);
    await tester.pump(_pastDoubleTap);
    expect(_controlsShown(tester), isTrue);

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.tap(_play);
    await tester.pump();
    expect(player.pauseCalls, 1);
    player.emitState(VideoPlaybackState.paused);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(_controlsShown(tester), isTrue);

    await _startPlaying(tester, player);
    expect(player.playCalls, 2);
    await tester.pump(const Duration(milliseconds: 2900));
    expect(_controlsShown(tester), isTrue);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_controlsShown(tester), isFalse);
  });

  testWidgets('a double tap on the picture skips and leaves controls shown', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
    await _openOn(tester, _scene(_Calls()), player, TargetPlatform.android);
    player.emitState(VideoPlaybackState.paused);
    await tester.pump();
    await _startPlaying(tester, player);

    await tester.tapAt(_phonePicture + const Offset(100, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(_phonePicture + const Offset(100, 0));
    await tester.pump(_pastDoubleTap);

    expect(player.seekCalls, hasLength(1));
    expect(_controlsShown(tester), isTrue);
  });

  testWidgets('Mac controls return on hover and Tab and hold during a press', (
    WidgetTester tester,
  ) async {
    _mac(tester);
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
    await _openOn(tester, _scene(_Calls()), player, TargetPlatform.macOS);
    player.emitState(VideoPlaybackState.paused);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    player.emitState(VideoPlaybackState.playing);
    await tester.pump();
    await tester.pump(viewerControlsIdle);
    expect(_controlsShown(tester), isFalse);

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: const Offset(720, 450));
    addTearDown(mouse.removePointer);
    await tester.pump();
    await mouse.moveTo(const Offset(740, 460));
    await tester.pump();
    expect(_controlsShown(tester), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump(const Duration(milliseconds: 2900));
    expect(_controlsShown(tester), isTrue);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_controlsShown(tester), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_controlsShown(tester), isTrue);
    await tester.pump(viewerControlsIdle + const Duration(milliseconds: 200));
    expect(_controlsShown(tester), isTrue);
  });

  testWidgets('the phone video viewer follows the shared dock', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
    final _Calls calls = _Calls();
    await _openOn(tester, _scene(calls), player, TargetPlatform.android);

    expect(find.byType(TransportDock), findsOneWidget);
    expect(find.byType(ViewerDock), findsNothing);
    expect(find.byType(ViewerTopBar), findsNothing);
    expect(find.byKey(logActionsDeleteKey), findsNothing);
    expect(find.byKey(viewerTitleFieldKey), findsNothing);

    final List<Rect> dock = <Rect>[
      tester.getRect(find.byKey(transportDockBackKey)),
      tester.getRect(find.byKey(transportBack10Key)),
      tester.getRect(_play),
      tester.getRect(find.byKey(transportForward10Key)),
      tester.getRect(find.byKey(transportDockMoreKey)),
    ];
    for (int index = 1; index < dock.length; index++) {
      expect(dock[index].left, greaterThan(dock[index - 1].right - 0.01));
    }
    for (final Rect control in dock) {
      expect(control.width, greaterThanOrEqualTo(48));
      expect(control.height, greaterThanOrEqualTo(48));
    }
    expect(832 - dock[2].top, inInclusiveRange(70, 150));

    await tester.tap(find.byKey(transportDockBackKey));
    await tester.pump();
    expect(calls.back, 1);

    final Rect scrubber = tester.getRect(find.byKey(transportVideoTimelineKey));
    await tester.dragFrom(
      Offset(scrubber.right - 20, scrubber.center.dy),
      const Offset(-150, 0),
    );
    await tester.pump();
    expect(player.seekCalls, isNotEmpty);
    expect(calls.later, 0);
    expect(calls.earlier, 0);
  });

  testWidgets('Android keeps the edge arrows and swipes still step', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
    final _Calls calls = _Calls();
    await _openOn(tester, _scene(calls), player, TargetPlatform.android);

    final Rect earlier = tester.getRect(find.byKey(logViewerEarlierKey));
    final Rect later = tester.getRect(find.byKey(logViewerLaterKey));
    expect(earlier, const Rect.fromLTWH(4, 392, 48, 48));
    expect(later, const Rect.fromLTWH(384 - 4 - 48, 392, 48, 48));

    await tester.tap(find.byKey(logViewerEarlierKey));
    await tester.pump();
    await tester.tap(find.byKey(logViewerLaterKey));
    await tester.pump();
    expect(calls.earlier, 1);
    expect(calls.later, 1);

    await tester.flingFrom(const Offset(300, 300), const Offset(-200, 0), 1000);
    await tester.pump();
    expect(calls.later, 2);
    await tester.flingFrom(const Offset(80, 300), const Offset(200, 0), 1000);
    await tester.pump();
    expect(calls.earlier, 2);

    await tester.flingFrom(earlier.center, const Offset(200, 0), 1000);
    await tester.pump();
    expect(calls.earlier, 2);
  });

  testWidgets('the Mac video viewer steps at the window edges', (
    WidgetTester tester,
  ) async {
    _mac(tester);
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
    final _Calls calls = _Calls();
    await _openOn(tester, _scene(calls), player, TargetPlatform.macOS);

    expect(find.byType(TransportBar), findsOneWidget);
    expect(find.byType(ViewerCapsule), findsNothing);
    final Rect earlier = tester.getRect(find.byKey(logViewerEarlierKey));
    final Rect later = tester.getRect(find.byKey(logViewerLaterKey));
    const double middle = _titleBar + (900 - _titleBar) / 2;
    expect(earlier, Rect.fromLTWH(16, middle - 24, 48, 48));
    expect(later, Rect.fromLTWH(1440 - 16 - 48, middle - 24, 48, 48));
    for (final Key key in <Key>[logViewerEarlierKey, logViewerLaterKey]) {
      expect(
        find.descendant(
          of: find.byType(TransportBar),
          matching: find.byKey(key),
        ),
        findsNothing,
      );
    }

    final Finder bar = find.byType(ViewerLogBar);
    await tester.tap(
      find.descendant(of: bar, matching: find.byKey(logViewerBackKey)),
    );
    await tester.tap(
      find.descendant(of: bar, matching: find.byKey(logActionsDeleteKey)),
    );
    await tester.pump();
    expect(calls.back, 1);
    expect(calls.delete, 1);
    expect(
      find.descendant(of: bar, matching: find.text('2 of 3')),
      findsOneWidget,
    );
    expect(find.textContaining(_dayTitle), findsOneWidget);
  });

  for (final TargetPlatform platform in <TargetPlatform>[
    TargetPlatform.macOS,
    TargetPlatform.android,
  ]) {
    testWidgets(
      'no gap is reserved beside play with any neighbours on ${platform.name}',
      (WidgetTester tester) async {
        platform == TargetPlatform.macOS ? _mac(tester) : _phone(tester);
        final List<Rect> plays = <Rect>[];
        for (final (bool earlier, bool later) in <(bool, bool)>[
          (false, false),
          (true, false),
          (false, true),
          (true, true),
        ]) {
          await _openOn(
            tester,
            _scene(_Calls(), earlier: earlier, later: later),
            FakeEntryVideoPlayer(),
            platform,
          );
          expect(
            find.byKey(logViewerEarlierKey),
            earlier ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(logViewerLaterKey),
            later ? findsOneWidget : findsNothing,
          );
          plays.add(tester.getRect(_play));
        }
        expect(plays.toSet(), hasLength(1));
        if (platform == TargetPlatform.macOS) {
          expect(
            tester.getRect(find.byKey(transportBack10Key)).left -
                plays.first.right,
            lessThan(16),
          );
        }
      },
    );
  }

  testWidgets('Page keys step, arrow keys seek and Esc leaves on Mac', (
    WidgetTester tester,
  ) async {
    _mac(tester);
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer()
      ..duration = const Duration(milliseconds: _durationMs);
    final _Calls calls = _Calls();
    await _openOn(tester, _scene(calls), player, TargetPlatform.macOS);
    player
      ..emitState(VideoPlaybackState.paused)
      ..emitPosition(const Duration(seconds: 20));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(player.playCalls, 1);
    player.emitState(VideoPlaybackState.playing);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(player.pauseCalls, 1);
    player.emitState(VideoPlaybackState.paused);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(player.seekCalls.last, const Duration(seconds: 15));
    player.emitPosition(const Duration(seconds: 20));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(player.seekCalls.last, const Duration(seconds: 25));
    expect(calls.earlier, 0);
    expect(calls.later, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pump();
    expect(calls.earlier, 1);
    expect(calls.later, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    expect(calls.later, 1);
    expect(calls.earlier, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(calls.back, 1);
    expect(calls.delete, 0);
  });

  testWidgets('the top bar and edge arrows read the tokens of each theme', (
    WidgetTester tester,
  ) async {
    _mac(tester);
    for (final (Brightness brightness, FieldNotesColors colors)
        in <(Brightness, FieldNotesColors)>[
          (Brightness.light, FieldNotesColors.light),
          (Brightness.dark, FieldNotesColors.dark),
        ]) {
      await _openOn(
        tester,
        _scene(_Calls(), title: 'Harbour'),
        FakeEntryVideoPlayer(),
        TargetPlatform.macOS,
        brightness: brightness,
      );

      final Finder inBar = find.descendant(
        of: find.byType(ViewerLogBar),
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).gradient is LinearGradient,
        ),
      );
      final LinearGradient fade =
          (tester.widget<DecoratedBox>(inBar).decoration as BoxDecoration)
                  .gradient!
              as LinearGradient;
      expect(fade.colors, <Color>[
        colors.viewerFadeEnd,
        colors.viewerFadeStart,
      ]);
      expect(
        tester
            .widget<ColoredBox>(
              find
                  .descendant(
                    of: find.byType(ViewerLogBar),
                    matching: find.byType(ColoredBox),
                  )
                  .first,
            )
            .color,
        colors.viewerFadeEnd,
      );

      final Container arrow = tester.widget<Container>(
        find.descendant(
          of: find.byKey(logViewerEarlierKey),
          matching: find.byType(Container),
        ),
      );
      final BoxDecoration face = arrow.decoration! as BoxDecoration;
      expect(
        face.color!.withValues(alpha: 1),
        brightness == Brightness.dark
            ? colors.viewerFadeEnd.withValues(alpha: 1)
            : colors.cardBright.withValues(alpha: 1),
      );
      final EditableText field = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(ViewerLogBar),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.style.color, colors.ink);
      expect(
        tester.widget<Text>(find.text('2 of 3')).style!.color,
        colors.inkSoft,
      );
    }
  });

  testWidgets('the Mac title field saves on Enter and on losing focus', (
    WidgetTester tester,
  ) async {
    _mac(tester);
    final _Calls calls = _Calls();
    await _openOn(
      tester,
      _scene(calls, title: 'Harbour'),
      FakeEntryVideoPlayer(),
      TargetPlatform.macOS,
    );
    final Finder field = find.byKey(viewerTitleFieldKey);
    expect(find.text('Harbour'), findsOneWidget);

    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, 'Fog over the harbour');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(calls.back, 0);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(calls.titles, <String?>['Fog over the harbour']);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    expect(calls.later, 1);

    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, '   ');
    await tester.tapAt(const Offset(720, 450));
    await tester.pump();
    expect(calls.titles, <String?>['Fog over the harbour', null]);
  });

  testWidgets('Escape in the title field puts the old title back', (
    WidgetTester tester,
  ) async {
    _mac(tester);
    final _Calls calls = _Calls();
    await _openOn(
      tester,
      _scene(calls, title: 'Harbour'),
      FakeEntryVideoPlayer(),
      TargetPlatform.macOS,
    );
    final Finder field = find.byKey(viewerTitleFieldKey);

    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, 'Discarded');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.text('Harbour'), findsOneWidget);
    expect(calls.titles, isEmpty);
    expect(calls.back, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(calls.back, 1);
  });

  testWidgets('a title typed before leaving is still saved', (
    WidgetTester tester,
  ) async {
    _mac(tester);
    final _Calls calls = _Calls();
    await _openOn(
      tester,
      _scene(calls),
      FakeEntryVideoPlayer(),
      TargetPlatform.macOS,
    );
    expect(find.text(viewerTitleHint), findsOneWidget);
    final Finder field = find.byKey(viewerTitleFieldKey);
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, 'Last light');

    await tester.pumpWidget(const SizedBox());
    expect(calls.titles, <String?>['Last light']);
  });

  testWidgets('the phone shows a title read-only and renames in the sheet', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final _Calls calls = _Calls();
    await _openOn(
      tester,
      _scene(calls, title: 'Harbour'),
      FakeEntryVideoPlayer(),
      TargetPlatform.android,
    );
    expect(find.text('Harbour'), findsOneWidget);
    expect(find.byKey(viewerTitleFieldKey), findsNothing);

    await tester.tap(find.byKey(transportDockMoreKey));
    await tester.pumpAndSettle();
    expect(find.text(viewerRenameLabel), findsOneWidget);
    expect(find.text(viewerDeleteLogLabel), findsOneWidget);
    expect(
      tester.getSize(find.byKey(viewerRenameRowKey)).height,
      greaterThanOrEqualTo(52),
    );

    await tester.tap(find.byKey(viewerRenameRowKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(viewerTitleFieldKey), 'Fog');
    await tester.tap(find.byKey(viewerSaveTitleKey));
    await tester.pumpAndSettle();
    expect(calls.titles, <String?>['Fog']);

    await tester.tap(find.byKey(transportDockMoreKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(logActionsDeleteKey));
    await tester.pumpAndSettle();
    expect(calls.delete, 1);
    expect(find.text(viewerDeleteLogLabel), findsNothing);
  });

  testWidgets('a phone log with no title offers Add a title in the sheet', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    await _openOn(
      tester,
      _scene(_Calls()),
      FakeEntryVideoPlayer(),
      TargetPlatform.android,
    );
    expect(find.text(viewerTitleHint), findsNothing);

    await tester.tap(find.byKey(transportDockMoreKey));
    await tester.pumpAndSettle();
    expect(find.text(viewerTitleHint), findsOneWidget);
    expect(find.text(viewerRenameLabel), findsNothing);
  });

  test(
    'a video size that is missing is read again once the record has one',
    () async {
      MediaBlob videoBlob({int? width, int? height}) => MediaBlob(
        id: _videoId,
        relPath: 'v.mp4',
        mime: 'video/mp4',
        kind: MediaKind.video,
        bytes: 0,
        createdAt: 0,
        width: width,
        height: height,
      );
      final FakeMediaStore store = FakeMediaStore(Directory.systemTemp)
        ..register(videoBlob());
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          mediaStoreProvider.overrideWith((Ref ref) async => store),
        ],
      );
      addTearDown(container.dispose);

      final ProviderSubscription<AsyncValue<double?>> before = container.listen(
        videoAspectProvider(_videoId),
        (AsyncValue<double?>? previous, AsyncValue<double?> next) {},
      );
      expect(
        await container.read(videoAspectProvider(_videoId).future),
        isNull,
      );
      before.close();
      await container.pump();

      store.register(
        videoBlob(
          width: _portrait.width.round(),
          height: _portrait.height.round(),
        ),
      );
      final ProviderSubscription<AsyncValue<double?>> after = container.listen(
        videoAspectProvider(_videoId),
        (AsyncValue<double?>? previous, AsyncValue<double?> next) {},
      );
      addTearDown(after.close);
      expect(
        await container.read(videoAspectProvider(_videoId).future),
        _portrait.width / _portrait.height,
      );
    },
  );
}
