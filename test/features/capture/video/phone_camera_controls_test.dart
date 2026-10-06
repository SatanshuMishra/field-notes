import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart' show CameraValue, Optional;
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const int _cameraId = 7;
const Key _platformPreviewKey = ValueKey<String>('platform-camera-preview');

const List<CameraDescription> _noteTenCameras = <CameraDescription>[
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
  CameraDescription(
    name: '2',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
  ),
  CameraDescription(
    name: '3',
    lensDirection: CameraLensDirection.front,
    sensorOrientation: 270,
  ),
];

class _FakeCameraPlatform extends CameraPlatform {
  _FakeCameraPlatform({this.stabilisation = const <VideoStabilizationMode>[]});

  final List<VideoStabilizationMode> stabilisation;
  final List<VideoStabilizationMode> stabilised = <VideoStabilizationMode>[];
  final List<double> zooms = <double>[];
  final List<Point<double>?> focusPoints = <Point<double>?>[];
  final List<Point<double>?> exposurePoints = <Point<double>?>[];
  final List<String> meteringOrder = <String>[];
  final StreamController<CameraInitializedEvent> _initialized =
      StreamController<CameraInitializedEvent>.broadcast();
  final StreamController<CameraErrorEvent> _errors =
      StreamController<CameraErrorEvent>.broadcast();
  final StreamController<DeviceOrientationChangedEvent> _orientations =
      StreamController<DeviceOrientationChangedEvent>.broadcast();

  @override
  Future<List<CameraDescription>> availableCameras() async => _noteTenCameras;

  @override
  Future<int> createCamera(
    CameraDescription cameraDescription,
    ResolutionPreset? resolutionPreset, {
    bool enableAudio = false,
  }) async => _cameraId;

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async => _cameraId;

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    scheduleMicrotask(
      () => _initialized.add(
        const CameraInitializedEvent(
          _cameraId,
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
  Future<Iterable<VideoStabilizationMode>> getSupportedVideoStabilizationModes(
    int cameraId,
  ) async => stabilisation;

  @override
  Future<void> setVideoStabilizationMode(
    int cameraId,
    VideoStabilizationMode mode,
  ) async {
    stabilised.add(mode);
  }

  @override
  Future<double> getMinZoomLevel(int cameraId) async => 1;

  @override
  Future<double> getMaxZoomLevel(int cameraId) async => 8;

  @override
  Future<void> setZoomLevel(int cameraId, double zoom) async {
    zooms.add(zoom);
  }

  @override
  Future<void> setFocusPoint(int cameraId, Point<double>? point) async {
    focusPoints.add(point);
    meteringOrder.add('focus');
  }

  @override
  Future<void> setExposurePoint(int cameraId, Point<double>? point) async {
    exposurePoints.add(point);
    meteringOrder.add('exposure');
  }

  @override
  Future<void> startVideoCapturing(VideoCaptureOptions options) async {}

  @override
  Future<void> dispose(int cameraId) async {}

  @override
  Widget buildPreview(int cameraId) =>
      const SizedBox.expand(key: _platformPreviewKey);
}

Future<void> _openSession(
  WidgetTester tester,
  CameraVideoRecorder recorder,
  Size area,
) async {
  tester.view.physicalSize = area;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final List<VideoCaptureDevice> devices = await recorder.listDevices();
  final Widget? preview = recorder.openSession(devices.first.id);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: area,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[preview ?? const SizedBox.shrink()],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  late CameraPlatform original;

  setUp(() => original = CameraPlatform.instance);
  tearDown(() => CameraPlatform.instance = original);

  test('a phone offers one back camera and one front camera', () async {
    CameraPlatform.instance = _FakeCameraPlatform();

    final List<VideoCaptureDevice> devices = await CameraVideoRecorder()
        .listDevices();

    expect(devices, const <VideoCaptureDevice>[
      VideoCaptureDevice(id: '0', label: 'Back camera'),
      VideoCaptureDevice(id: '1', label: 'Front camera'),
    ]);
  });

  testWidgets(
    'the preview keeps the camera picture shape on a tall phone screen',
    (WidgetTester tester) async {
      CameraPlatform.instance = _FakeCameraPlatform();
      final CameraVideoRecorder recorder = CameraVideoRecorder();
      const Size screen = Size(400, 844);

      await _openSession(tester, recorder, screen);

      final Size shown = tester.getSize(find.byKey(_platformPreviewKey));
      expect(shown.width, closeTo(400, 0.01));
      expect(shown.height, closeTo(400 * 1920 / 1080, 0.01));
      final Rect? rect = recorder.previewRectIn(screen);
      expect(
        rect,
        Rect.fromLTWH(0, (844 - 400 * 1920 / 1080) / 2, 400, 400 * 1920 / 1080),
      );
      expect(tester.getRect(find.byKey(_platformPreviewKey)), rect);

      await tester.pumpWidget(const SizedBox.shrink());
      await recorder.dispose();
    },
  );

  testWidgets('the camera turns on video stabilisation where it can', (
    WidgetTester tester,
  ) async {
    final _FakeCameraPlatform platform = _FakeCameraPlatform(
      stabilisation: const <VideoStabilizationMode>[
        VideoStabilizationMode.off,
        VideoStabilizationMode.level1,
      ],
    );
    CameraPlatform.instance = platform;
    final CameraVideoRecorder recorder = CameraVideoRecorder();

    await _openSession(tester, recorder, const Size(400, 844));
    await recorder.start();

    expect(platform.stabilised, <VideoStabilizationMode>[
      VideoStabilizationMode.level1,
      VideoStabilizationMode.level1,
    ]);

    await tester.pumpWidget(const SizedBox.shrink());
    await recorder.dispose();
  });

  testWidgets('zoom and focus reach the camera', (WidgetTester tester) async {
    final _FakeCameraPlatform platform = _FakeCameraPlatform();
    CameraPlatform.instance = platform;
    final CameraVideoRecorder recorder = CameraVideoRecorder();

    await _openSession(tester, recorder, const Size(400, 844));

    expect(await recorder.zoomRange(), const ZoomRange(1, 8));
    await recorder.setZoom(2.5);
    await recorder.focusAt(const Offset(0.25, 0.75));

    expect(platform.zooms, <double>[2.5]);
    expect(recorder.zoom, 2.5);
    expect(platform.meteringOrder, <String>['exposure', 'focus']);
    expect(platform.focusPoints, <Point<double>>[
      const Point<double>(0.25, 0.75),
    ]);
    expect(platform.exposurePoints, <Point<double>>[
      const Point<double>(0.25, 0.75),
    ]);

    await tester.pumpWidget(const SizedBox.shrink());
    await recorder.dispose();
  });

  test('the preview shape follows the orientation the camera draws in', () {
    final CameraValue portrait = const CameraValue.uninitialized(
      CameraDescription(
        name: '0',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
    ).copyWith(isInitialized: true, previewSize: const Size(1920, 1080));

    expect(previewAspectRatio(portrait), closeTo(1080 / 1920, 0.0001));
    expect(
      previewAspectRatio(
        portrait.copyWith(deviceOrientation: DeviceOrientation.landscapeLeft),
      ),
      closeTo(1920 / 1080, 0.0001),
    );
    expect(
      previewAspectRatio(
        portrait.copyWith(
          deviceOrientation: DeviceOrientation.landscapeRight,
          isRecordingVideo: true,
          recordingOrientation: const Optional<DeviceOrientation>.of(
            DeviceOrientation.portraitUp,
          ),
        ),
      ),
      closeTo(1080 / 1920, 0.0001),
    );
    expect(
      previewAspectRatio(
        portrait.copyWith(
          lockedCaptureOrientation: const Optional<DeviceOrientation>.of(
            DeviceOrientation.landscapeLeft,
          ),
        ),
      ),
      closeTo(1920 / 1080, 0.0001),
    );
  });

  test('controls do nothing before the camera is ready', () async {
    final _FakeCameraPlatform platform = _FakeCameraPlatform();
    CameraPlatform.instance = platform;
    final CameraVideoRecorder recorder = CameraVideoRecorder();

    expect(recorder.previewRectIn(const Size(400, 844)), isNull);
    expect(await recorder.zoomRange(), isNull);
    await recorder.setZoom(3);
    await recorder.focusAt(const Offset(0.5, 0.5));

    expect(platform.zooms, isEmpty);
    expect(platform.focusPoints, isEmpty);
  });
}
