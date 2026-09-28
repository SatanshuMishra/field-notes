import 'dart:async';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const MethodChannel _macosCameraChannel = MethodChannel('camera_macos');

const Map<String, Object?> _macosDevice = <String, Object?>{
  'deviceType': 0,
  'localizedName': 'FaceTime HD Camera',
  'manufacturer': 'Apple Inc.',
  'deviceId': 'built-in-id',
};

final Uint8List _stillJpegBytes =
    Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xD9]);

class _NativeMacosCamera {
  _NativeMacosCamera(this.moviePath);

  final String moviePath;

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'listDevices':
        return <String, Object?>{
          'devices': <Map<String, Object?>>[_macosDevice],
        };
      case 'initialize':
        return <String, Object?>{
          'textureId': 7,
          'size': <String, Object?>{'width': 1280.0, 'height': 720.0},
          'devices': <Map<String, Object?>>[_macosDevice],
        };
      case 'startRecording':
        return <String, Object?>{'error': null};
      case 'takePicture':
        return <String, Object?>{
          'imageData': _stillJpegBytes,
          'error': null,
        };
      case 'stopRecording':
        File(moviePath).writeAsBytesSync(<int>[0, 0, 0, 24]);
        return <String, Object?>{
          'url': moviePath,
          'videoData': null,
          'error': null,
        };
      case 'destroy':
        return true;
      default:
        return null;
    }
  }
}

class _FakeAndroidCamera extends CameraPlatform {
  _FakeAndroidCamera(this.directory);

  final String directory;
  final List<String> stoppedTakes = <String>[];
  int _written = 0;
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
  Future<int> createCamera(
    CameraDescription cameraDescription,
    ResolutionPreset? resolutionPreset, {
    bool enableAudio = false,
  }) async =>
      7;

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async =>
      7;

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    scheduleMicrotask(
      () => _initialized.add(
        const CameraInitializedEvent(
          7,
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
  }) async {}

  @override
  Future<void> startVideoCapturing(VideoCaptureOptions options) async {}

  @override
  Future<XFile> takePicture(int cameraId) async => XFile(_write('CAP', 'jpg'));

  @override
  Future<XFile> stopVideoRecording(int cameraId) async {
    final String take = _write('REC', 'mp4');
    stoppedTakes.add(take);
    return XFile(take);
  }

  @override
  Future<void> dispose(int cameraId) async {}

  @override
  Widget buildPreview(int cameraId) => const SizedBox.shrink();

  String _write(String prefix, String extension) {
    _written += 1;
    final String path = p.join(directory, '$prefix$_written.$extension');
    File(path).writeAsBytesSync(<int>[1, 2]);
    return path;
  }
}

Future<void> _openMacosSession(
  WidgetTester tester,
  CameraMacosVideoRecorder recorder,
) async {
  await tester.pumpWidget(
    MaterialApp(home: SizedBox(child: recorder.openSession('built-in-id'))),
  );
  await tester.pumpAndSettle();
}

File _captureFile(CaptureMedia? media) => (media! as CaptureFile).file;

void main() {
  group('video media formats', () {
    test('records mp4 video and captures a jpeg thumbnail', () {
      expect(videoRecordingMime, 'video/mp4');
      expect(videoRecordingExtension, 'mp4');
      expect(videoThumbnailMime, 'image/jpeg');
      expect(videoThumbnailExtension, 'jpg');
    });
  });

  group('videoRecordingFileName', () {
    test('builds a timestamped video file name with the recording extension', () {
      expect(videoRecordingFileName(1720000000000), 'video_1720000000000.mp4');
    });

    test('produces distinct names for distinct timestamps', () {
      expect(videoRecordingFileName(1) == videoRecordingFileName(2), isFalse);
    });
  });

  group('videoThumbnailFileName', () {
    test('builds a timestamped thumbnail file name with the jpeg extension', () {
      expect(videoThumbnailFileName(1720000000000), 'video_thumb_1720000000000.jpg');
    });

    test('is distinct from the video file name for the same timestamp', () {
      expect(videoThumbnailFileName(5) == videoRecordingFileName(5), isFalse);
    });
  });

  group('resolveVideoThumbnailPath', () {
    test('creates the target directory when it does not exist', () async {
      final Directory base =
          await Directory.systemTemp.createTemp('video_thumb_test_');
      addTearDown(() => base.delete(recursive: true));
      final Directory missing =
          Directory(p.join(base.path, 'nested', 'caches', 'bundle'));
      expect(missing.existsSync(), isFalse);

      final String path = await resolveVideoThumbnailPath(missing, 1720000000000);

      expect(missing.existsSync(), isTrue);
      expect(path, p.join(missing.path, 'video_thumb_1720000000000.jpg'));
    });

    test('returns a path inside an already-existing directory', () async {
      final Directory base =
          await Directory.systemTemp.createTemp('video_thumb_test_');
      addTearDown(() => base.delete(recursive: true));

      final String path = await resolveVideoThumbnailPath(base, 42);

      expect(base.existsSync(), isTrue);
      expect(path, p.join(base.path, 'video_thumb_42.jpg'));
    });
  });

  group('releasing and discarding captures', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('video_release_test_');
    });

    tearDown(() => temp.delete(recursive: true));

    group('on macOS', () {
      late _NativeMacosCamera native;

      setUp(() {
        native = _NativeMacosCamera(p.join(temp.path, 'output.mp4'));
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_macosCameraChannel, native.handle);
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_macosCameraChannel, null);
      });

      testWidgets(
          'releasing a saved video deletes the movie and thumbnail the '
          'recorder created', (WidgetTester tester) async {
        final CameraMacosVideoRecorder recorder =
            CameraMacosVideoRecorder(temporaryDirectory: () async => temp);
        final File picked = File(p.join(temp.path, 'picked.mp4'))
          ..writeAsBytesSync(<int>[4, 4]);

        await _openMacosSession(tester, recorder);

        late VideoRecording recording;
        await tester.runAsync(() async {
          await recorder.start();
          recording = await recorder.stop();
        });
        final File movie = _captureFile(recording.media);
        final File thumbnail = _captureFile(recording.thumbnail);

        expect(movie.existsSync(), isTrue);
        expect(thumbnail.existsSync(), isTrue);
        expect(p.isWithin(temp.path, thumbnail.path), isTrue);

        await tester.runAsync(() async {
          await recorder.releaseSaved(
            VideoRecording(
              media: CaptureFile(file: picked, mime: videoRecordingMime),
              durationMs: 1,
            ),
          );
        });

        expect(picked.existsSync(), isTrue);
        expect(movie.existsSync(), isTrue);

        await tester.runAsync(() => recorder.releaseSaved(recording));

        expect(movie.existsSync(), isFalse);
        expect(thumbnail.existsSync(), isFalse);
        expect(picked.existsSync(), isTrue);

        await recorder.release();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'releasing an earlier video keeps the movie a newer recording is '
          'writing', (WidgetTester tester) async {
        final CameraMacosVideoRecorder recorder =
            CameraMacosVideoRecorder(temporaryDirectory: () async => temp);

        await _openMacosSession(tester, recorder);

        late VideoRecording earlier;
        await tester.runAsync(() async {
          await recorder.start();
          earlier = await recorder.stop();
          await recorder.start();
        });
        final File movie = _captureFile(earlier.media);
        final File earlierThumbnail = _captureFile(earlier.thumbnail);

        await tester.runAsync(() => recorder.releaseSaved(earlier));

        expect(movie.existsSync(), isTrue);
        expect(earlierThumbnail.existsSync(), isFalse);

        await recorder.release();
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });

    group('on Android', () {
      late CameraPlatform original;
      late _FakeAndroidCamera platform;
      late CameraVideoRecorder recorder;

      setUp(() async {
        original = CameraPlatform.instance;
        platform = _FakeAndroidCamera(temp.path);
        CameraPlatform.instance = platform;
        recorder = CameraVideoRecorder();
        final List<VideoCaptureDevice> devices = await recorder.listDevices();
        recorder.openSession(devices.single.id);
        await recorder.start();
      });

      tearDown(() async {
        await recorder.dispose();
        CameraPlatform.instance = original;
      });

      test('cancelling on Android deletes the stopped take', () async {
        await recorder.cancel();

        expect(platform.stoppedTakes, hasLength(1));
        expect(File(platform.stoppedTakes.single).existsSync(), isFalse);
      });

      test(
          'releasing a saved Android video deletes the take and still the '
          'recorder created', () async {
        final VideoRecording recording = await recorder.stop();
        final File take = _captureFile(recording.media);
        final File still = _captureFile(recording.thumbnail);

        expect(take.existsSync(), isTrue);
        expect(still.existsSync(), isTrue);

        await recorder.releaseSaved(recording);

        expect(take.existsSync(), isFalse);
        expect(still.existsSync(), isFalse);
      });
    });
  });
}
