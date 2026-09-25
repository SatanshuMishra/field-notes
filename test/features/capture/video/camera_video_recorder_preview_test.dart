import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const String _deviceName = 'camera-back-0';
const int _cameraId = 7;
const Key _platformPreviewKey = ValueKey<String>('platform-camera-preview');

class _FakeCameraPlatform extends CameraPlatform {
  int createCalls = 0;
  int initializeCalls = 0;
  int startRecordingCalls = 0;
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
          name: _deviceName,
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
        ),
      ];

  @override
  Future<int> createCamera(
    CameraDescription cameraDescription,
    ResolutionPreset? resolutionPreset, {
    bool enableAudio = false,
  }) async {
    createCalls += 1;
    return _cameraId;
  }

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async {
    createCalls += 1;
    return _cameraId;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    initializeCalls += 1;
    scheduleMicrotask(
      () => _initialized.add(
        const CameraInitializedEvent(
          _cameraId,
          1280,
          720,
          ExposureMode.auto,
          false,
          FocusMode.auto,
          false,
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
  Future<void> startVideoRecording(
    int cameraId, {
    Duration? maxVideoDuration,
  }) async {
    startRecordingCalls += 1;
  }

  @override
  Future<void> startVideoCapturing(VideoCaptureOptions options) async {
    startRecordingCalls += 1;
  }

  @override
  Future<void> dispose(int cameraId) async {}

  @override
  Widget buildPreview(int cameraId) =>
      const SizedBox(key: _platformPreviewKey);
}

Future<Widget?> _openSession(
  WidgetTester tester,
  CameraVideoRecorder recorder,
) async {
  final List<VideoCaptureDevice> devices = await recorder.listDevices();
  final Widget? preview = recorder.openSession(devices.single.id);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: preview ?? const SizedBox.shrink(),
    ),
  );
  await tester.pump();
  return preview;
}

void main() {
  late CameraPlatform original;
  late _FakeCameraPlatform platform;

  setUp(() {
    original = CameraPlatform.instance;
    platform = _FakeCameraPlatform();
    CameraPlatform.instance = platform;
    addTearDown(() => CameraPlatform.instance = original);
  });

  testWidgets('opening a session initialises the camera before recording starts',
      (WidgetTester tester) async {
    final CameraVideoRecorder recorder = CameraVideoRecorder();

    await _openSession(tester, recorder);
    await tester.pump();

    expect(platform.initializeCalls, 1);
    expect(platform.startRecordingCalls, 0);
    expect(find.byKey(_platformPreviewKey), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await recorder.dispose();
  });

  testWidgets('starting to record reuses the initialised camera',
      (WidgetTester tester) async {
    final CameraVideoRecorder recorder = CameraVideoRecorder();

    await _openSession(tester, recorder);

    expect(platform.createCalls, 1);

    await recorder.start();

    expect(platform.createCalls, 1);
    expect(platform.startRecordingCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await recorder.dispose();
  });
}
