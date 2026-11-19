import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/dialog_host.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/video_body.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots.dart';
import 'package:field_notes/features/entry_cards/transport/transport.dart';
import 'package:field_notes/features/entry_cards/transport/transport_timeline.dart'
    show transportBubbleKey;
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/video_viewer_view.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';

import '../entry_cards/support/entry_cards_harness.dart';
import '../entry_cards/support/fake_video_player.dart';

const String _videoId = 'video-media';
const Duration _frame = Duration(milliseconds: 10);
const int _mousePointer = 43;
const int _mouseDevice = 1;

void _window(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
}

FakeMediaResolver _resolver() {
  final Directory folder = Directory.systemTemp.createTempSync('video-motion');
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

LogViewerScene _scene() {
  return LogViewerScene(
    entry: const Entry(
      id: 'video-entry',
      dayId: 'd1',
      type: EntryType.video,
      mediaId: _videoId,
      durationMs: 65000,
      createdAt: 0,
      updatedAt: 0,
    ),
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
}

Future<FakeEntryVideoPlayer> _playing(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  final LruVideoSlots slots = LruVideoSlots(cap: 2);
  addTearDown(slots.dispose);
  final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey<TargetPlatform>(platform),
      overrides: <Override>[
        videoAspectProvider.overrideWith((Ref ref, String mediaId) => 16 / 9),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform, brightness: Brightness.dark),
        home: DialogHost(
          child: VideoViewerView(
            scene: _scene(),
            resolver: _resolver(),
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
  player.emitState(VideoPlaybackState.playing);
  await tester.pump();
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

Future<void> _startFrames(WidgetTester tester) async {
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

void _expectControls(WidgetTester tester, double opacity, String when) {
  for (final Type controls in <Type>[Transport, ViewerLogBar]) {
    expect(
      _opacityAbove(tester, find.byType(controls)),
      opacity,
      reason: '$controls $when',
    );
  }
}

Rect _box(WidgetTester tester) => tester.getRect(find.byType(VideoBody));

Future<TestGesture> _mouse(WidgetTester tester, Offset at) async {
  final TestGesture mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    pointer: _mousePointer,
  );
  await mouse.addPointer(location: at);
  addTearDown(mouse.removePointer);
  return mouse;
}

MouseCursor? _cursor() =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(_mouseDevice);

double _railThickness(WidgetTester tester) {
  final Finder rails = find.descendant(
    of: find.byKey(transportVideoTimelineKey),
    matching: find.byType(CustomPaint),
  );
  double thickness = 0;
  double widest = 0;
  for (final Element element in rails.evaluate()) {
    expect(
      element.renderObject,
      paints..everything((Symbol method, List<dynamic> arguments) {
        if (method == #drawRRect) {
          final RRect rail = arguments.first as RRect;
          if (rail.width > widest) {
            widest = rail.width;
            thickness = rail.height;
          }
        }
        return true;
      }),
    );
  }
  return thickness;
}

void main() {
  testWidgets(
    'with a mouse the controls stay 3 s after the last move and on touch 4 s after a tap',
    (WidgetTester tester) async {
      _window(tester, const Size(1440, 900));
      await _playing(tester, TargetPlatform.macOS);
      final Offset picture = _box(tester).center;
      final TestGesture mouse = await _mouse(tester, picture);
      await mouse.moveTo(picture + const Offset(6, 4));
      await _startFrames(tester);

      await _advance(tester, const Duration(milliseconds: 2900));
      _expectControls(tester, 1, '2.9 s after the last move');
      await _advance(tester, const Duration(milliseconds: 420));
      _expectControls(tester, 0, '3.32 s after the last move');
      await mouse.removePointer();

      _window(tester, const Size(412, 915));
      await _playing(tester, TargetPlatform.android);
      await _advance(tester, const Duration(milliseconds: 4400));
      _expectControls(tester, 0, 'before the tap');

      await tester.tapAt(_box(tester).center);
      await _startFrames(tester);
      await _advance(tester, const Duration(milliseconds: 3900));
      _expectControls(tester, 1, '3.9 s after the tap');
      await _advance(tester, const Duration(milliseconds: 420));
      _expectControls(tester, 0, '4.32 s after the tap');
    },
  );

  testWidgets('the controls rise in 250 ms and fade over 320 ms', (
    WidgetTester tester,
  ) async {
    _window(tester, const Size(1440, 900));
    await _playing(tester, TargetPlatform.macOS);
    await _advance(tester, const Duration(milliseconds: 3400));
    _expectControls(tester, 0, 'once hidden');

    final Offset picture = _box(tester).center;
    final TestGesture mouse = await _mouse(tester, picture);
    await mouse.moveTo(picture + const Offset(8, 0));
    await _startFrames(tester);
    await _advance(tester, const Duration(milliseconds: 125));
    expect(
      _opacityAbove(tester, find.byType(Transport)),
      greaterThan(0.6),
      reason: '125 ms after the move',
    );
    await _advance(tester, const Duration(milliseconds: 125));
    _expectControls(tester, 1, '250 ms after the move');

    await _advance(tester, const Duration(milliseconds: 2750));
    _expectControls(tester, 1, 'as the fade starts');
    await _advance(tester, const Duration(milliseconds: 300));
    expect(
      _opacityAbove(tester, find.byType(Transport)),
      greaterThan(0),
      reason: '300 ms into the fade',
    );
    await _advance(tester, const Duration(milliseconds: 20));
    _expectControls(tester, 0, '320 ms into the fade');
  });

  testWidgets(
    'the controls leave 0.6 s after the pointer leaves the picture and the pointer hides with them',
    (WidgetTester tester) async {
      _window(tester, const Size(1440, 900));
      await _playing(tester, TargetPlatform.macOS);
      final Rect box = _box(tester);
      final TestGesture mouse = await _mouse(tester, box.center);
      await mouse.moveTo(box.center + const Offset(4, 4));
      await _startFrames(tester);
      final Offset outside = box.top >= 4
          ? Offset(box.center.dx, box.top - 2)
          : Offset(box.left - 2, box.top - 2);
      await mouse.moveTo(outside);
      await _startFrames(tester);

      await _advance(tester, const Duration(milliseconds: 500));
      _expectControls(tester, 1, '0.5 s after the leave');
      await _advance(tester, const Duration(milliseconds: 420));
      _expectControls(tester, 0, '0.92 s after the leave');

      await mouse.moveTo(box.center);
      await _startFrames(tester);
      await _advance(tester, const Duration(milliseconds: 3400));
      _expectControls(tester, 0, 'after resting 3 s');
      expect(_cursor(), SystemMouseCursors.none);

      await mouse.moveTo(box.center + const Offset(10, 0));
      await _startFrames(tester);
      await _advance(tester, const Duration(milliseconds: 250));
      _expectControls(tester, 1, 'after a move');
      expect(_cursor(), isNot(SystemMouseCursors.none));
    },
  );

  testWidgets(
    'the scrub bar eases its growth over 180 ms and its time bubble fades in',
    (WidgetTester tester) async {
      _window(tester, const Size(1440, 900));
      await _playing(tester, TargetPlatform.macOS);
      expect(_railThickness(tester), 4);

      final Offset rail = tester.getCenter(
        find.byKey(transportVideoTimelineKey),
      );
      final TestGesture mouse = await _mouse(
        tester,
        rail + const Offset(0, 40),
      );
      await mouse.moveTo(rail);
      await _startFrames(tester);

      await _advance(tester, const Duration(milliseconds: 60));
      final double bubble = _opacityAbove(
        tester,
        find.byKey(transportBubbleKey),
      );
      expect(bubble, greaterThan(0));
      expect(bubble, lessThan(1));

      await _advance(tester, const Duration(milliseconds: 60));
      final double grown = _railThickness(tester);
      expect(grown, greaterThan(4));
      expect(grown, lessThan(6));

      await _advance(tester, const Duration(milliseconds: 60));
      expect(_railThickness(tester), 6);
    },
  );
}
