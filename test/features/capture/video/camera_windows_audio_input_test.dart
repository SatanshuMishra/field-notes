import 'dart:async';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const String _integratedCamera = r'Integrated Camera <\\?\usb#vid_04f2>';
const int _cameraId = 5;

class _FakeWindowsCamera extends CameraPlatform {
  _FakeWindowsCamera(this.events);

  final List<String> events;
  final Completer<void> created = Completer<void>();
  final StreamController<CameraInitializedEvent> _initialized =
      StreamController<CameraInitializedEvent>.broadcast();
  final StreamController<CameraErrorEvent> _errors =
      StreamController<CameraErrorEvent>.broadcast();

  @override
  Future<List<CameraDescription>> availableCameras() async =>
      const <CameraDescription>[
        CameraDescription(
          name: _integratedCamera,
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 0,
        ),
      ];

  @override
  Future<int> createCamera(
    CameraDescription cameraDescription,
    ResolutionPreset? resolutionPreset, {
    bool enableAudio = false,
  }) => createCameraWithSettings(
    cameraDescription,
    MediaSettings(resolutionPreset: resolutionPreset, enableAudio: enableAudio),
  );

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async {
    events.add('createCamera');
    if (!created.isCompleted) {
      created.complete();
    }
    return _cameraId;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
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
      const Stream<DeviceOrientationChangedEvent>.empty();

  @override
  Future<Iterable<VideoStabilizationMode>> getSupportedVideoStabilizationModes(
    int cameraId,
  ) async => const <VideoStabilizationMode>[];

  @override
  Future<void> dispose(int cameraId) async {
    events.add('dispose');
  }

  @override
  Widget buildPreview(int cameraId) => const SizedBox.shrink();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late CameraPlatform original;
  late List<String> events;
  late _FakeWindowsCamera camera;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('windows_audio_input_test_');
    original = CameraPlatform.instance;
    events = <String>[];
    camera = _FakeWindowsCamera(events);
    CameraPlatform.instance = camera;
  });

  tearDown(() async {
    CameraPlatform.instance = original;
    await root.delete(recursive: true);
  });

  CameraWindowsVideoRecorder windowsRecorder() => CameraWindowsVideoRecorder(
    temporaryDirectory: () async => root,
    setAudioInputDevice: (String? endpointId) async {
      events.add('setAudioInputDevice($endpointId)');
    },
  );

  Future<void> openSessionOnTheCamera(
    CameraWindowsVideoRecorder recorder,
  ) async {
    final List<VideoCaptureDevice> devices = await recorder.listDevices();
    recorder.openSession(devices.single.id);
    await camera.created.future.timeout(const Duration(seconds: 5));
  }

  test('a Windows video session records from the chosen microphone', () async {
    const AudioInput input = AudioInput(id: 'ep-2', label: 'Headset');
    final CameraWindowsVideoRecorder recorder = windowsRecorder();

    recorder.useAudioInput(input.id);
    await openSessionOnTheCamera(recorder);

    expect(events.take(2), <String>[
      'setAudioInputDevice(ep-2)',
      'createCamera',
    ]);
    expect(
      events.where((String event) => event.startsWith('setAudioInputDevice')),
      hasLength(1),
    );

    await recorder.dispose();
  });

  test(
    'a Windows video session with no choice uses the default microphone',
    () async {
      const AudioInput systemDefault = AudioInput(
        id: null,
        label: 'System default',
      );
      final CameraWindowsVideoRecorder recorder = windowsRecorder();

      recorder.useAudioInput(systemDefault.id);
      await openSessionOnTheCamera(recorder);

      expect(events.take(2), <String>[
        'setAudioInputDevice(null)',
        'createCamera',
      ]);
      expect(
        events.where((String event) => event.startsWith('setAudioInputDevice')),
        hasLength(1),
      );

      await recorder.dispose();
    },
  );
}
