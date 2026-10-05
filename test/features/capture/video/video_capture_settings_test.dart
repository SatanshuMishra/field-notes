import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _macosCameraChannel = MethodChannel('camera_macos');

const Map<String, Object?> _macosDevice = <String, Object?>{
  'deviceType': 0,
  'localizedName': 'FaceTime HD Camera',
  'manufacturer': 'Apple Inc.',
  'deviceId': 'built-in-id',
};

class _SettingsRecordingCamera extends CameraPlatform {
  final Completer<MediaSettings> created = Completer<MediaSettings>();
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
          name: 'camera-back-0',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
        ),
      ];

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async {
    if (!created.isCompleted) {
      created.complete(mediaSettings);
    }
    return 7;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    scheduleMicrotask(
      () => _initialized.add(
        const CameraInitializedEvent(
          7,
          1920,
          1080,
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
  Future<void> dispose(int cameraId) async {}

  @override
  Widget buildPreview(int cameraId) => const SizedBox.shrink();
}

Future<Object?> _nativeMacosCamera(
  MethodCall call,
  List<MethodCall> calls,
) async {
  calls.add(call);
  switch (call.method) {
    case 'initialize':
      return <String, Object?>{
        'textureId': 7,
        'size': <String, Object?>{'width': 1920.0, 'height': 1080.0},
        'devices': <Map<String, Object?>>[_macosDevice],
      };
    case 'destroy':
      return true;
    default:
      return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('android records 1080p at 4 Mbps with 96 kbps audio', () async {
    final CameraPlatform original = CameraPlatform.instance;
    final _SettingsRecordingCamera camera = _SettingsRecordingCamera();
    CameraPlatform.instance = camera;
    addTearDown(() {
      CameraPlatform.instance = original;
    });
    final CameraVideoRecorder recorder = CameraVideoRecorder();

    recorder.openSession('camera-back-0');
    final MediaSettings settings = await camera.created.future;
    await recorder.release();

    expect(settings.resolutionPreset, ResolutionPreset.veryHigh);
    expect(settings.videoBitrate, 4000000);
    expect(settings.audioBitrate, 96000);
    expect(settings.enableAudio, isTrue);
  });

  testWidgets('macOS passes 1080p, AAC audio and 4 Mbps to the plugin', (
    WidgetTester tester,
  ) async {
    final List<MethodCall> calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _macosCameraChannel,
          (MethodCall call) => _nativeMacosCamera(call, calls),
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_macosCameraChannel, null);
    });
    final CameraMacosVideoRecorder recorder = CameraMacosVideoRecorder();

    await tester.pumpWidget(
      MaterialApp(home: SizedBox(child: recorder.openSession('built-in-id'))),
    );
    await tester.pump();
    final Map<Object?, Object?> arguments =
        calls
                .firstWhere((MethodCall call) => call.method == 'initialize')
                .arguments
            as Map<Object?, Object?>;
    await tester.pumpWidget(const SizedBox.shrink());
    await recorder.release();

    expect(arguments['useMovieFileOutput'], isTrue);
    expect(arguments['movieResolution'], 'veryHigh');
    expect(arguments['audioBitrate'], 96000);
    expect(arguments['videoBitrate'], 4000000);
  });
}
