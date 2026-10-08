import 'dart:async';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const String _integratedCamera = r'Integrated Camera <\\?\usb#vid_04f2>';
const String _usbCamera = r'USB Camera <\\?\usb#vid_046d>';
const int _cameraId = 3;
const Key _platformPreviewKey = ValueKey<String>('windows-platform-preview');
const List<int> _movieBytes = <int>[0, 0, 0, 24];
const List<int> _stillBytes = <int>[0xFF, 0xD8, 0xFF, 0xD9];

class _FakeWindowsCamera extends CameraPlatform {
  _FakeWindowsCamera({required this.names, required this.root});

  final List<String> names;
  final String root;
  final List<String> stoppedTakes = <String>[];
  final List<String> stills = <String>[];
  bool holdInitialisation = false;
  int recordingStarts = 0;
  int stabilisationQueries = 0;
  int _written = 0;
  final StreamController<CameraInitializedEvent> _initialized =
      StreamController<CameraInitializedEvent>.broadcast();
  final StreamController<CameraErrorEvent> _errors =
      StreamController<CameraErrorEvent>.broadcast();

  String get videos => p.join(root, 'Videos');

  String get pictures => p.join(root, 'Pictures');

  @override
  Future<List<CameraDescription>> availableCameras() async =>
      <CameraDescription>[
        for (final String name in names)
          CameraDescription(
            name: name,
            lensDirection: CameraLensDirection.front,
            sensorOrientation: 0,
          ),
      ];

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
    if (!holdInitialisation) {
      scheduleMicrotask(finishInitialisation);
    }
  }

  void finishInitialisation() {
    _initialized.add(
      const CameraInitializedEvent(
        _cameraId,
        1280,
        720,
        ExposureMode.auto,
        false,
        FocusMode.auto,
        false,
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
  ) async {
    stabilisationQueries += 1;
    return const <VideoStabilizationMode>[VideoStabilizationMode.level1];
  }

  @override
  Future<void> startVideoRecording(
    int cameraId, {
    Duration? maxVideoDuration,
  }) async {
    recordingStarts += 1;
  }

  @override
  Future<void> startVideoCapturing(VideoCaptureOptions options) async {
    recordingStarts += 1;
  }

  @override
  Future<XFile> takePicture(int cameraId) async {
    final String still = _write(pictures, 'jpg', _stillBytes);
    stills.add(still);
    return XFile(still);
  }

  @override
  Future<XFile> stopVideoRecording(int cameraId) async {
    final String take = _write(videos, 'mp4', _movieBytes);
    stoppedTakes.add(take);
    return XFile(take);
  }

  @override
  Future<void> dispose(int cameraId) async {}

  @override
  Widget buildPreview(int cameraId) => const SizedBox(key: _platformPreviewKey);

  String _write(String folder, String extension, List<int> bytes) {
    _written += 1;
    Directory(folder).createSync(recursive: true);
    final String path = p.join(folder, 'WindowsCapture$_written.$extension');
    File(path).writeAsBytesSync(bytes);
    return path;
  }
}

File _captureFile(CaptureMedia? media) => (media! as CaptureFile).file;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late CameraPlatform original;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('windows_camera_test_');
    original = CameraPlatform.instance;
  });

  tearDown(() async {
    CameraPlatform.instance = original;
    await root.delete(recursive: true);
  });

  _FakeWindowsCamera installCamera(List<String> names) {
    final _FakeWindowsCamera camera = _FakeWindowsCamera(
      names: names,
      root: root.path,
    );
    CameraPlatform.instance = camera;
    return camera;
  }

  Future<CameraWindowsVideoRecorder> recordingRecorder(
    Directory temporary,
  ) async {
    final CameraWindowsVideoRecorder recorder = CameraWindowsVideoRecorder(
      temporaryDirectory: () async => temporary,
    );
    final List<VideoCaptureDevice> devices = await recorder.listDevices();
    recorder.openSession(devices.first.id);
    await recorder.start();
    return recorder;
  }

  test('Windows lists every camera by name and cannot pause', () async {
    installCamera(const <String>[_integratedCamera, _usbCamera]);
    final CameraWindowsVideoRecorder recorder = CameraWindowsVideoRecorder(
      temporaryDirectory: () async => root,
    );

    expect(await recorder.listDevices(), const <VideoCaptureDevice>[
      VideoCaptureDevice(id: _integratedCamera, label: 'Integrated Camera'),
      VideoCaptureDevice(id: _usbCamera, label: 'USB Camera'),
    ]);
    expect(recorder.supportsPause, isFalse);
    expect(recorder, isNot(isA<CameraControls>()));
    await expectLater(recorder.pause(), throwsUnsupportedError);
    await expectLater(recorder.resume(), throwsUnsupportedError);
  });

  test("Windows moves the finished recording and its still out of the user's "
      'folders', () async {
    final _FakeWindowsCamera camera = installCamera(const <String>[_usbCamera]);
    final Directory temporary = Directory(p.join(root.path, 'Temp'));
    final CameraWindowsVideoRecorder recorder = await recordingRecorder(
      temporary,
    );

    final VideoRecording recording = await recorder.stop();
    final File movie = _captureFile(recording.media);
    final File still = _captureFile(recording.thumbnail);
    final String captures = p.join(temporary.path, 'captures');

    expect(p.dirname(camera.stoppedTakes.single), camera.videos);
    expect(p.dirname(camera.stills.single), camera.pictures);
    expect(p.dirname(movie.path), captures);
    expect(p.dirname(still.path), captures);
    expect(p.basename(movie.path), matches(RegExp(r'^video_\d+\.mp4$')));
    expect(p.basename(still.path), matches(RegExp(r'^video_thumb_\d+\.jpg$')));
    expect(movie.readAsBytesSync(), _movieBytes);
    expect(still.readAsBytesSync(), _stillBytes);
    expect(File(camera.stoppedTakes.single).existsSync(), isFalse);
    expect(File(camera.stills.single).existsSync(), isFalse);
    expect(recording.media.mime, videoRecordingMime);
    expect(recording.thumbnail!.mime, videoThumbnailMime);

    await recorder.dispose();
  });

  test('each platform gets its own recorder', () {
    expect(
      createPlatformVideoRecorder(platform: TargetPlatform.windows),
      isA<CameraWindowsVideoRecorder>(),
    );
    expect(
      createPlatformVideoRecorder(platform: TargetPlatform.macOS),
      isA<CameraMacosVideoRecorder>(),
    );
    expect(
      createPlatformVideoRecorder(platform: TargetPlatform.android),
      isA<CameraVideoRecorder>(),
    );
  });

  test('two Windows cameras with one name are told apart', () async {
    installCamera(const <String>['Cam <a>', 'Cam <b>']);
    final CameraWindowsVideoRecorder recorder = CameraWindowsVideoRecorder(
      temporaryDirectory: () async => root,
    );

    expect(await recorder.listDevices(), const <VideoCaptureDevice>[
      VideoCaptureDevice(id: 'Cam <a>', label: 'Cam'),
      VideoCaptureDevice(id: 'Cam <b>', label: 'Cam (2)'),
    ]);
    expect(windowsCameraLabel('Plain'), 'Plain');
  });

  test(
    'a third camera with a repeated name is numbered in list order',
    () async {
      installCamera(const <String>[
        'Cam <a>',
        'Desk <d>',
        'Cam <b>',
        'Cam <c>',
      ]);
      final CameraWindowsVideoRecorder recorder = CameraWindowsVideoRecorder(
        temporaryDirectory: () async => root,
      );

      expect(
        (await recorder.listDevices()).map(
          (VideoCaptureDevice device) => device.label,
        ),
        <String>['Cam', 'Desk', 'Cam (2)', 'Cam (3)'],
      );
      expect(windowsCameraLabel(_integratedCamera), 'Integrated Camera');
    },
  );

  test('the running platform picks the recorder', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(createPlatformVideoRecorder(), isA<CameraWindowsVideoRecorder>());
  });

  test('Windows records without asking the camera to stabilise', () async {
    final _FakeWindowsCamera camera = installCamera(const <String>[_usbCamera]);
    final CameraWindowsVideoRecorder recorder = await recordingRecorder(root);

    expect(camera.recordingStarts, 1);
    expect(camera.stabilisationQueries, 0);

    await recorder.cancel();
  });

  test(
    'releasing a saved Windows video deletes the moved recording and still',
    () async {
      installCamera(const <String>[_usbCamera]);
      final CameraWindowsVideoRecorder recorder = await recordingRecorder(root);
      final VideoRecording recording = await recorder.stop();
      final File movie = _captureFile(recording.media);
      final File still = _captureFile(recording.thumbnail);

      expect(movie.existsSync(), isTrue);
      expect(still.existsSync(), isTrue);

      await recorder.releaseSaved(recording);

      expect(movie.existsSync(), isFalse);
      expect(still.existsSync(), isFalse);

      await recorder.dispose();
    },
  );

  test('cancelling on Windows deletes the stopped take', () async {
    final _FakeWindowsCamera camera = installCamera(const <String>[_usbCamera]);
    final CameraWindowsVideoRecorder recorder = await recordingRecorder(root);

    await recorder.cancel();

    expect(camera.stoppedTakes, hasLength(1));
    expect(File(camera.stoppedTakes.single).existsSync(), isFalse);
  });

  testWidgets(
    'Windows previews the camera at its own aspect ratio without turning it',
    (WidgetTester tester) async {
      installCamera(const <String>[_integratedCamera]);
      final CameraWindowsVideoRecorder recorder = CameraWindowsVideoRecorder(
        temporaryDirectory: () async => root,
      );
      final List<VideoCaptureDevice> devices = await recorder.listDevices();
      final Widget? preview = recorder.openSession(devices.single.id);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: preview ?? const SizedBox.shrink(),
        ),
      );
      await tester.pump();
      await tester.pump();

      final AspectRatio ratio = tester.widget<AspectRatio>(
        find.ancestor(
          of: find.byKey(_platformPreviewKey),
          matching: find.byType(AspectRatio),
        ),
      );
      expect(ratio.aspectRatio, 1280 / 720);
      expect(find.byType(RotatedBox), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await recorder.dispose();
    },
  );

  testWidgets(
    'a Windows camera that never answers points at its privacy page',
    (WidgetTester tester) async {
      final _FakeWindowsCamera camera = installCamera(const <String>[
        _usbCamera,
      ])..holdInitialisation = true;
      final CameraWindowsVideoRecorder recorder = CameraWindowsVideoRecorder(
        temporaryDirectory: () async => root,
      );
      final List<VideoCaptureDevice> devices = await recorder.listDevices();
      recorder.openSession(devices.single.id);

      Object? refusal;
      bool answered = false;
      unawaited(
        recorder
            .start()
            .catchError((Object error) {
              refusal = error;
            })
            .whenComplete(() => answered = true),
      );

      await tester.pump(cameraStartTimeout - const Duration(seconds: 1));
      expect(answered, isFalse);

      await tester.pump(const Duration(seconds: 2));
      expect(answered, isTrue);
      expect(
        refusal,
        isA<VideoRecorderException>().having(
          (VideoRecorderException error) => error.message,
          'message',
          videoStartTimeoutMessageWindows,
        ),
      );

      camera.finishInitialisation();
      await tester.pump();
      await recorder.dispose();
    },
  );
}
