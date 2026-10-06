import 'package:field_notes/design/glass/glass_surface.dart';
import 'package:field_notes/features/capture/video/camera_gestures.dart';
import 'package:field_notes/features/capture/video/camera_picker.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

const Size _phone = Size(400, 844);
const double _previewHeight = 400 * 16 / 9;
const Rect _preview = Rect.fromLTWH(
  0,
  (844 - _previewHeight) / 2,
  400,
  _previewHeight,
);

const List<VideoCaptureDevice> _phoneCameras = <VideoCaptureDevice>[
  VideoCaptureDevice(id: '0', label: 'Back camera'),
  VideoCaptureDevice(id: '1', label: 'Front camera'),
];

class _FakeControls implements CameraControls {
  final List<double> zooms = <double>[];

  @override
  double zoom = 1;
  final List<Offset> focuses = <Offset>[];
  Size? area;

  @override
  Rect? previewRectIn(Size area) {
    this.area = area;
    return _preview;
  }

  @override
  Future<ZoomRange?> zoomRange() async => const ZoomRange(1, 4);

  @override
  Future<void> setZoom(double zoom) async {
    zooms.add(zoom);
    this.zoom = zoom;
  }

  @override
  Future<void> focusAt(Offset point) async => focuses.add(point);
}

Future<List<String>> _pumpSheet(
  WidgetTester tester, {
  required _FakeControls controls,
  VideoRecorderPhase phase = VideoRecorderPhase.idle,
}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final List<String> picked = <String>[];
  await tester.pumpWidget(
    videoSheetHarness(
      SizedBox.fromSize(
        size: _phone,
        child: VideoRecorderSheet(
          phase: phase,
          devices: _phoneCameras,
          selectedDeviceId: '0',
          onDeviceChanged: picked.add,
          controls: controls,
          onStart: () {},
          onStop: () {},
          onLeave: () {},
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return picked;
}

Future<void> _pinch(WidgetTester tester, double spread) async {
  final Offset centre = tester.getCenter(find.byKey(cameraGestureLayerKey));
  final TestGesture first = await tester.startGesture(
    centre - const Offset(40, 0),
    pointer: 1,
  );
  final TestGesture second = await tester.startGesture(
    centre + const Offset(40, 0),
    pointer: 2,
  );
  await tester.pump();
  for (int step = 1; step <= 10; step++) {
    await first.moveBy(Offset(-spread / 20, 0));
    await second.moveBy(Offset(spread / 20, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await first.up();
  await second.up();
  await tester.pump();
}

void main() {
  testWidgets('swiping up or down on the picture flips the camera', (
    WidgetTester tester,
  ) async {
    final List<String> picked = await _pumpSheet(
      tester,
      controls: _FakeControls(),
    );

    await tester.drag(find.byKey(cameraGestureLayerKey), const Offset(0, -160));
    await tester.pump();
    await tester.drag(find.byKey(cameraGestureLayerKey), const Offset(0, 160));
    await tester.pump();
    await tester.drag(find.byKey(cameraGestureLayerKey), const Offset(160, 20));
    await tester.pump();

    expect(picked, <String>['1', '1']);
  });

  testWidgets('a swipe while recording does not flip the camera', (
    WidgetTester tester,
  ) async {
    final List<String> picked = await _pumpSheet(
      tester,
      controls: _FakeControls(),
      phase: VideoRecorderPhase.recording,
    );

    await tester.drag(find.byKey(cameraGestureLayerKey), const Offset(0, -160));
    await tester.pump();

    expect(picked, isEmpty);
    expect(find.byKey(videoFlipCameraKey), findsNothing);
  });

  testWidgets('pinching zooms within the camera range and shows the level', (
    WidgetTester tester,
  ) async {
    final _FakeControls controls = _FakeControls();
    await _pumpSheet(tester, controls: controls);

    await _pinch(tester, 160);

    expect(controls.zooms, isNotEmpty);
    expect(controls.zooms.last, greaterThan(1.5));
    expect(controls.zooms.every((double zoom) => zoom <= 4), isTrue);
    expect(find.byKey(cameraZoomLevelKey), findsOneWidget);
    expect(find.text(cameraZoomLabel(controls.zooms.last)), findsOneWidget);

    await _pinch(tester, 2000);
    expect(controls.zooms.last, 4);

    await tester.pump(cameraZoomLevelTime + const Duration(milliseconds: 300));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: find.byKey(cameraZoomLevelKey),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity,
      0,
    );
  });

  testWidgets('tapping the picture focuses there and shows a ring', (
    WidgetTester tester,
  ) async {
    final _FakeControls controls = _FakeControls();
    await _pumpSheet(tester, controls: controls);
    final Offset origin = tester.getTopLeft(find.byKey(cameraGestureLayerKey));

    await tester.tapAt(origin + Offset(100, _preview.top + _previewHeight / 4));
    await tester.pump();

    expect(controls.area, _phone);
    expect(controls.focuses, hasLength(1));
    expect(controls.focuses.single.dx, closeTo(0.25, 0.001));
    expect(controls.focuses.single.dy, closeTo(0.25, 0.001));
    expect(find.byKey(cameraFocusRingKey), findsOneWidget);

    await tester.tapAt(origin + Offset(200, _preview.top / 2));
    await tester.pump();
    expect(controls.focuses, hasLength(1));

    await tester.pump(cameraFocusRingTime + const Duration(milliseconds: 50));
    expect(find.byKey(cameraFocusRingKey), findsNothing);
  });

  testWidgets('with self-view off the picture takes no camera gestures', (
    WidgetTester tester,
  ) async {
    final _FakeControls controls = _FakeControls();
    await _pumpSheet(tester, controls: controls);

    await tester.tap(find.byKey(videoSelfViewKey));
    await tester.pump();

    expect(find.byKey(cameraGestureLayerKey), findsNothing);
  });

  testWidgets(
    'the phone recorder has glass Leave, flip and self-view buttons and no privacy line',
    (WidgetTester tester) async {
      await _pumpSheet(tester, controls: _FakeControls());

      for (final Key key in <Key>[
        videoCloseKey,
        videoFlipCameraKey,
        videoSelfViewKey,
      ]) {
        expect(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(GlassSurface),
          ),
          findsOneWidget,
          reason: '$key',
        );
      }
      expect(find.text('Only you'), findsNothing);
      expect(find.text('Mirror on'), findsNothing);
      expect(find.bySemanticsLabel('Switch to front camera'), findsOneWidget);
    },
  );

  testWidgets(
    'the Mac recorder has the same glass Leave and self-view, no flip and no privacy line',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        videoSheetHarness(
          SizedBox(
            width: 1024,
            height: 640,
            child: VideoRecorderSheet(
              phase: VideoRecorderPhase.idle,
              devices: const <VideoCaptureDevice>[
                VideoCaptureDevice(id: 'built-in', label: 'MacBook Pro Camera'),
                VideoCaptureDevice(id: 'obs', label: 'OBS Virtual Camera'),
              ],
              selectedDeviceId: 'built-in',
              onDeviceChanged: (String _) {},
              onStart: () {},
              onStop: () {},
              onLeave: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      for (final Key key in <Key>[videoCloseKey, videoSelfViewKey]) {
        expect(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(GlassSurface),
          ),
          findsOneWidget,
          reason: '$key',
        );
      }
      expect(find.byKey(videoFlipCameraKey), findsNothing);
      expect(find.byKey(cameraGestureLayerKey), findsNothing);
      expect(find.byType(CameraPicker), findsOneWidget);
      expect(find.textContaining('only you'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
