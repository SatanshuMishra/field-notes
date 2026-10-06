import 'dart:async';
import 'dart:math';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/video/camera_gestures.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

const Size _phone = Size(400, 844);

class _Platform extends CameraPlatform {
  final List<double> zooms = <double>[];
  final StreamController<CameraInitializedEvent> _initialized =
      StreamController<CameraInitializedEvent>.broadcast();
  final StreamController<CameraErrorEvent> _errors =
      StreamController<CameraErrorEvent>.broadcast();
  final StreamController<DeviceOrientationChangedEvent> _orientations =
      StreamController<DeviceOrientationChangedEvent>.broadcast();

  @override
  Future<List<CameraDescription>> availableCameras() async =>
      const <CameraDescription>[
        CameraDescription(
          name: '0',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
        ),
        CameraDescription(
          name: '1',
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 270,
        ),
      ];

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async => 1;

  @override
  Future<int> createCamera(
    CameraDescription cameraDescription,
    ResolutionPreset? resolutionPreset, {
    bool enableAudio = false,
  }) async => 1;

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    scheduleMicrotask(
      () => _initialized.add(
        const CameraInitializedEvent(
          1,
          1920,
          1080,
          ExposureMode.auto,
          true,
          FocusMode.auto,
          true,
        ),
      ),
    );
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _initialized.stream;

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _errors.stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      _orientations.stream;

  @override
  Future<double> getMinZoomLevel(int cameraId) async => 1;

  @override
  Future<double> getMaxZoomLevel(int cameraId) async => 8;

  @override
  Future<void> setZoomLevel(int cameraId, double zoom) async => zooms.add(zoom);

  @override
  Future<void> setFocusPoint(int cameraId, Point<double>? point) async {}

  @override
  Future<void> setExposurePoint(int cameraId, Point<double>? point) async {}

  @override
  Future<void> dispose(int cameraId) async {}

  @override
  Widget buildPreview(int cameraId) => const SizedBox.expand();
}

Future<(_Platform, CameraVideoRecorder, List<String>)> _pumpRealCamera(
  WidgetTester tester,
) async {
  final CameraPlatform original = CameraPlatform.instance;
  addTearDown(() => CameraPlatform.instance = original);
  final _Platform platform = _Platform();
  CameraPlatform.instance = platform;
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final CameraVideoRecorder recorder = CameraVideoRecorder();
  final Widget? preview = recorder.openSession('0');
  final List<String> picked = <String>[];
  await tester.pumpWidget(
    videoSheetHarness(
      SizedBox.fromSize(
        size: _phone,
        child: VideoRecorderSheet(
          phase: VideoRecorderPhase.idle,
          preview: preview,
          devices: const <VideoCaptureDevice>[
            VideoCaptureDevice(id: '0', label: 'Back camera'),
            VideoCaptureDevice(id: '1', label: 'Front camera'),
          ],
          selectedDeviceId: '0',
          onDeviceChanged: picked.add,
          controls: recorder,
          onStart: () {},
          onStop: () {},
          onLeave: () {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return (platform, recorder, picked);
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
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets(
    'the phone recorder with camera controls has no unlabelled tap target',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final (_, CameraVideoRecorder recorder, _) = await _pumpRealCamera(
        tester,
      );

      expect(find.byKey(cameraGestureLayerKey), findsOneWidget);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await recorder.dispose();
    },
  );

  testWidgets('zoom carries on after self-view is turned off and on', (
    WidgetTester tester,
  ) async {
    final (_Platform platform, CameraVideoRecorder recorder, _) =
        await _pumpRealCamera(tester);

    await _pinch(tester, 160);
    final double reached = platform.zooms.last;
    expect(reached, greaterThan(1.5));
    expect(recorder.zoom, reached);

    await tester.tap(find.byKey(videoSelfViewKey));
    await tester.pump();
    await tester.tap(find.byKey(videoSelfViewKey));
    await tester.pump();
    await _pinch(tester, 40);

    expect(platform.zooms.last, greaterThanOrEqualTo(reached));

    await tester.pumpWidget(const SizedBox.shrink());
    await recorder.dispose();
  });

  testWidgets('a pinch that ends with one finger dragging does not flip', (
    WidgetTester tester,
  ) async {
    final (_, CameraVideoRecorder recorder, List<String> picked) =
        await _pumpRealCamera(tester);
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
    for (int step = 0; step < 5; step++) {
      await first.moveBy(const Offset(-8, 0));
      await second.moveBy(const Offset(8, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await second.up();
    await tester.pump();
    for (int step = 0; step < 8; step++) {
      await first.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await first.up();
    await tester.pump();

    expect(picked, isEmpty);

    await tester.drag(find.byKey(cameraGestureLayerKey), const Offset(0, -160));
    await tester.pump();
    expect(picked, <String>['1']);

    await tester.pumpWidget(const SizedBox.shrink());
    await recorder.dispose();
  });
}
