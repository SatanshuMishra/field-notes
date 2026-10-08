import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/dialog_host.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/video_body.dart';
import 'package:field_notes/features/entry_cards/cards/video_scrubber.dart';
import 'package:field_notes/features/entry_cards/compact/log_actions_pill.dart';
import 'package:field_notes/features/entry_cards/media/media_image.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/video_viewer_view.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';
import 'package:field_notes/state/media_provider.dart';

import '../entry_cards/support/entry_cards_harness.dart';
import '../entry_cards/support/fake_video_player.dart';

const Color _rose = Color(0xFFB8566A);
const Color _played = Color(0xFFE3889A);
const Color _ink = Color(0xFFF3E6D1);
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
const ValueKey<String> _scrubBar = ValueKey<String>('video-scrub-bar');

final class _Calls {
  int back = 0;
  int earlier = 0;
  int later = 0;
  int delete = 0;
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
}) {
  return LogViewerScene(
    entry: entryOf(
      type: EntryType.video,
      id: 'video-entry',
      mediaId: _videoId,
      thumbnailMediaId: poster ? _posterId : null,
      durationMs: _durationMs,
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
    onEarlier: () => calls.earlier++,
    onLater: () => calls.later++,
    onDelete: () => calls.delete++,
    onEdit: null,
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

bool _overlayShown(WidgetTester tester) {
  final AnimatedOpacity fade = tester.widget<AnimatedOpacity>(
    find
        .ancestor(
          of: find.byType(ViewerPrimaryButton),
          matching: find.byType(AnimatedOpacity),
        )
        .first,
  );
  return fade.opacity == 1;
}

Finder _playCircle(Finder within) {
  return find.descendant(
    of: within,
    matching: find.byWidgetPredicate((Widget widget) {
      if (widget is! DecoratedBox) {
        return false;
      }
      final Decoration decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.shape == BoxShape.circle &&
          decoration.color != null;
    }),
  );
}

List<RecordedInvocation> _scrubberPaint(WidgetTester tester) {
  final Finder paint = find.descendant(
    of: find.byType(VideoScrubber),
    matching: find.byType(CustomPaint),
  );
  final CustomPaint custom = tester.widget<CustomPaint>(paint);
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  custom.painter!.paint(canvas, tester.getSize(paint));
  return canvas.invocations.toList();
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

    await tester.tap(find.byType(ViewerPrimaryButton));
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

  testWidgets('overlays fade after 2.6 seconds of playing and return on play', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
    await tester.pumpWidget(
      _host(
        _scene(_Calls()),
        resolver: _resolver(),
        player: player,
        slots: _slots(),
        platform: TargetPlatform.android,
        recorded: _portrait,
      ),
    );
    await _settle(tester);
    expect(player.loadCalls, hasLength(1));
    expect(_overlayShown(tester), isTrue);

    await tester.tap(find.byType(ViewerPrimaryButton));
    await tester.pump();
    expect(player.playCalls, 1);
    player.emitState(VideoPlaybackState.playing);
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 2500));
    expect(_overlayShown(tester), isTrue);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_overlayShown(tester), isFalse);

    const Offset video = Offset(192, 416);
    await tester.tapAt(video);
    await tester.pump();
    expect(_overlayShown(tester), isTrue);
    await tester.tapAt(video);
    await tester.pump();
    expect(_overlayShown(tester), isFalse);
    await tester.tapAt(video);
    await tester.pump();
    expect(_overlayShown(tester), isTrue);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.tap(find.byType(ViewerPrimaryButton));
    await tester.pump();
    expect(player.pauseCalls, 1);
    player.emitState(VideoPlaybackState.paused);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(_overlayShown(tester), isTrue);

    await tester.tap(find.byType(ViewerPrimaryButton));
    await tester.pump();
    expect(player.playCalls, 2);
    player.emitState(VideoPlaybackState.playing);
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 2500));
    expect(_overlayShown(tester), isTrue);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_overlayShown(tester), isFalse);
  });

  testWidgets('the phone video viewer has a glass scrubber above the dock', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
    final _Calls calls = _Calls();
    await tester.pumpWidget(
      _host(
        _scene(calls),
        resolver: _resolver(),
        player: player,
        slots: _slots(),
        platform: TargetPlatform.android,
        recorded: _portrait,
      ),
    );
    await _settle(tester);

    final Finder bar = find.byKey(videoScrubberBarKey);
    expect(bar, findsOneWidget);
    final GlassSurface glass = tester.widget<GlassSurface>(bar);
    expect(glass.tone, GlassTone.media);
    expect(glass.borderRadius, BorderRadius.circular(22));
    final Rect rect = tester.getRect(bar);
    expect(rect.height, 44);
    expect(rect.left, 16);
    expect(rect.right, 384 - 16);
    expect(rect.bottom, 832 - _gestureBar - 116);
    expect(
      tester.getRect(find.byType(ViewerPrimaryButton)).top,
      greaterThan(rect.bottom),
    );
    expect(find.byType(ViewerDock), findsOneWidget);
    expect(
      tester.widget<ViewerDock>(find.byType(ViewerDock)).slots,
      hasLength(5),
    );

    final Rect slider = tester.getRect(find.byKey(_scrubBar));
    expect(slider.height, greaterThanOrEqualTo(44));
    expect(slider.center.dy, closeTo(rect.center.dy, 0.01));
    expect(slider.left, greaterThan(rect.left));
    expect(slider.right, lessThan(rect.right));
    final Rect elapsedRect = tester.getRect(find.text('0:00'));
    final Rect totalRect = tester.getRect(find.text('1:05'));
    expect(elapsedRect.left, greaterThan(rect.left));
    expect(elapsedRect.right, lessThan(slider.left));
    expect(totalRect.left, greaterThan(slider.right));
    expect(totalRect.right, lessThan(rect.right));
    expect(elapsedRect.center.dy, closeTo(rect.center.dy, 0.5));
    final Text elapsed = tester.widget<Text>(find.text('0:00'));
    expect(elapsed.style!.color!.toARGB32(), _ink.toARGB32());
    expect(
      elapsed.style!.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );

    final List<RecordedInvocation> painted = _scrubberPaint(tester);
    final RecordedInvocation track = painted.firstWhere(
      (RecordedInvocation call) => call.invocation.memberName == #drawRRect,
    );
    final RRect trackShape = track.invocation.positionalArguments[0] as RRect;
    final Paint trackPaint = track.invocation.positionalArguments[1] as Paint;
    expect(trackShape.height, 4);
    expect(
      trackPaint.color.toARGB32(),
      _ink.withValues(alpha: 0.24).toARGB32(),
    );
    final List<RecordedInvocation> knobs = painted
        .where(
          (RecordedInvocation call) =>
              call.invocation.memberName == #drawCircle &&
              (call.invocation.positionalArguments[2] as Paint).color
                      .toARGB32() ==
                  _ink.toARGB32(),
        )
        .toList();
    expect(knobs, hasLength(1));
    expect(knobs.single.invocation.positionalArguments[1], 7);

    player.emitPosition(const Duration(seconds: 30));
    await tester.pump();
    final Set<int> fills = <int>{
      for (final RecordedInvocation call in _scrubberPaint(tester))
        if (call.invocation.memberName == #drawRRect)
          (call.invocation.positionalArguments[1] as Paint).color.toARGB32(),
    };
    expect(fills, contains(_played.toARGB32()));

    final Rect scrubber = tester.getRect(find.byKey(_scrubBar));
    await tester.dragFrom(
      Offset(scrubber.right - 20, scrubber.center.dy),
      const Offset(-150, 0),
    );
    await tester.pump();
    expect(player.seekCalls, hasLength(1));
    expect(calls.later, 0);
    expect(calls.earlier, 0);

    await tester.flingFrom(const Offset(300, 416), const Offset(-200, 0), 1000);
    await tester.pump();
    expect(calls.later, 1);
    expect(calls.earlier, 0);
    expect(player.seekCalls, hasLength(1));
  });

  testWidgets('the Mac video viewer has one bottom capsule', (
    WidgetTester tester,
  ) async {
    _mac(tester);
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
    await tester.pumpWidget(
      _host(
        _scene(_Calls()),
        resolver: _resolver(),
        player: player,
        slots: _slots(),
        platform: TargetPlatform.macOS,
        recorded: _landscape,
      ),
    );
    await _settle(tester);

    expect(find.byType(ViewerDock), findsNothing);
    final Finder capsule = find.byType(ViewerCapsule);
    expect(capsule, findsOneWidget);
    final Rect rect = tester.getRect(capsule);
    expect(rect.width, lessThanOrEqualTo(780));
    expect(rect.bottom, 900 - 24);
    expect(rect.center.dx, closeTo(720, 0.5));

    expect(
      find.descendant(of: capsule, matching: find.byType(ViewerPrimaryButton)),
      findsOneWidget,
    );
    final Finder play = _playCircle(
      find.descendant(of: capsule, matching: find.byType(ViewerPrimaryButton)),
    );
    expect(play, findsOneWidget);
    expect(tester.getSize(play), const Size(48, 48));
    final DecoratedBox circle = tester.widget<DecoratedBox>(play);
    expect(
      (circle.decoration as BoxDecoration).color!.toARGB32(),
      _rose.toARGB32(),
    );
    expect(
      find.descendant(of: capsule, matching: find.byKey(logViewerEarlierKey)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: capsule, matching: find.byKey(logViewerLaterKey)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: capsule, matching: find.byType(VideoScrubber)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: capsule, matching: find.text('0:00')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: capsule, matching: find.text('1:05')),
      findsOneWidget,
    );

    final Finder topBar = find.byType(ViewerTopBar);
    expect(topBar, findsOneWidget);
    expect(
      find.descendant(of: topBar, matching: find.byKey(logViewerBackKey)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: topBar, matching: find.text(logViewerCloseLabel)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: topBar, matching: find.byKey(logActionsDeleteKey)),
      findsOneWidget,
    );
  });

  testWidgets('Space, arrows and Esc drive the Mac video viewer', (
    WidgetTester tester,
  ) async {
    _mac(tester);
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
    final _Calls calls = _Calls();
    await tester.pumpWidget(
      _host(
        _scene(calls),
        resolver: _resolver(),
        player: player,
        slots: _slots(),
        platform: TargetPlatform.macOS,
        recorded: _landscape,
      ),
    );
    await _settle(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(player.playCalls, 1);

    player.emitState(VideoPlaybackState.playing);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(player.pauseCalls, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(calls.earlier, 1);
    expect(calls.later, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(calls.later, 1);
    expect(calls.earlier, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(calls.back, 1);
    expect(calls.delete, 0);
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
