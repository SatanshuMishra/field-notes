import 'dart:async';
import 'dart:io';

import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const MethodChannel _cameraChannel = MethodChannel('camera_macos');

const Map<String, Object?> _builtInDevice = <String, Object?>{
  'deviceType': 0,
  'localizedName': 'FaceTime HD Camera',
  'manufacturer': 'Apple Inc.',
  'deviceId': 'built-in-id',
};

const Map<String, Object?> _usbDevice = <String, Object?>{
  'deviceType': 0,
  'localizedName': 'Logitech StreamCam',
  'manufacturer': 'Logitech',
  'deviceId': 'usb-id',
};

const String _stoppedVideoPath = '/tmp/field_notes_camera_macos_test.mp4';

final Uint8List _stillJpegBytes = Uint8List.fromList(<int>[
  0xFF, 0xD8, 0xFF, 0xDB, 0x00, 0x43, 0x00, 0x08, 0xFF, 0xD9,
]);

class _NativeCameraSpy {
  final List<MethodCall> calls = <MethodCall>[];
  Completer<void>? initGate;
  bool failTakePicture = false;

  List<String> get methods =>
      calls.map((MethodCall call) => call.method).toList();

  int countOf(String method) =>
      methods.where((String m) => m == method).length;

  Map<Object?, Object?> argumentsOf(String method) {
    return calls.firstWhere((MethodCall call) => call.method == method).arguments
        as Map<Object?, Object?>;
  }

  Future<Object?> handle(MethodCall call) async {
    calls.add(call);
    switch (call.method) {
      case 'listDevices':
        return <String, Object?>{
          'devices': <Map<String, Object?>>[_builtInDevice, _usbDevice],
        };
      case 'initialize':
        final Completer<void>? gate = initGate;
        if (gate != null) {
          await gate.future;
        }
        return <String, Object?>{
          'textureId': 7,
          'size': <String, Object?>{'width': 1280.0, 'height': 720.0},
          'devices': <Map<String, Object?>>[_builtInDevice, _usbDevice],
        };
      case 'startRecording':
        return <String, Object?>{'error': null};
      case 'takePicture':
        if (failTakePicture) {
          return <String, Object?>{'error': 'still capture failed'};
        }
        return <String, Object?>{
          'imageData': _stillJpegBytes,
          'error': null,
        };
      case 'stopRecording':
        return <String, Object?>{
          'url': _stoppedVideoPath,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _NativeCameraSpy native;
  late Directory temp;

  setUp(() async {
    native = _NativeCameraSpy();
    temp = await Directory.systemTemp.createTemp('camera_macos_thumb_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_cameraChannel, native.handle);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_cameraChannel, null);
    await temp.delete(recursive: true);
  });

  test('listDevices maps the enumerated cameras to their ids and names',
      () async {
    final CameraMacosVideoRecorder recorder = CameraMacosVideoRecorder();

    final List<VideoCaptureDevice> devices = await recorder.listDevices();

    expect(devices, <VideoCaptureDevice>[
      const VideoCaptureDevice(id: 'built-in-id', label: 'FaceTime HD Camera'),
      const VideoCaptureDevice(id: 'usb-id', label: 'Logitech StreamCam'),
    ]);
  });

  testWidgets('the preview initialises the camera the caller asked for',
      (WidgetTester tester) async {
    final CameraMacosVideoRecorder recorder = CameraMacosVideoRecorder();

    await tester.pumpWidget(
      MaterialApp(home: SizedBox(child: recorder.openSession('usb-id'))),
    );
    await tester.pump();

    expect(native.methods, contains('initialize'));
    expect(native.argumentsOf('initialize')['deviceId'], 'usb-id');

    await tester.pumpWidget(const SizedBox.shrink());
    await recorder.release();
  });

  testWidgets('the preview initialises the camera in the jpeg still format',
      (WidgetTester tester) async {
    final CameraMacosVideoRecorder recorder = CameraMacosVideoRecorder();

    await tester.pumpWidget(
      MaterialApp(home: SizedBox(child: recorder.openSession('usb-id'))),
    );
    await tester.pump();

    expect(native.argumentsOf('initialize')['pformat'], 'jpg');

    await tester.pumpWidget(const SizedBox.shrink());
    await recorder.release();
  });

  testWidgets('releasing the recorder destroys the native capture session',
      (WidgetTester tester) async {
    final CameraMacosVideoRecorder recorder = CameraMacosVideoRecorder();

    await tester.pumpWidget(
      MaterialApp(home: SizedBox(child: recorder.openSession('built-in-id'))),
    );
    await tester.pump();
    expect(native.methods, isNot(contains('destroy')));

    await recorder.release();

    expect(
      native.methods.where((String method) => method == 'destroy'),
      hasLength(1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('releasing twice destroys the native session only once',
      (WidgetTester tester) async {
    final CameraMacosVideoRecorder recorder = CameraMacosVideoRecorder();

    await tester.pumpWidget(
      MaterialApp(home: SizedBox(child: recorder.openSession('built-in-id'))),
    );
    await tester.pump();

    await recorder.release();
    await recorder.release();
    await recorder.dispose();

    expect(
      native.methods.where((String method) => method == 'destroy'),
      hasLength(1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'releasing during the init warmup still destroys the session once it '
      'materialises', (WidgetTester tester) async {
    final CameraMacosVideoRecorder recorder = CameraMacosVideoRecorder();
    final Completer<void> initGate = Completer<void>();
    native.initGate = initGate;

    await tester.pumpWidget(
      MaterialApp(home: SizedBox(child: recorder.openSession('usb-id'))),
    );
    await tester.pump();

    expect(native.methods, contains('initialize'));
    expect(native.countOf('destroy'), 0);

    await recorder.release();
    expect(native.countOf('destroy'), 0);

    initGate.complete();
    await tester.pumpAndSettle();

    expect(native.countOf('destroy'), 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'a controller that arrives after release is not adopted by the next '
      'session', (WidgetTester tester) async {
    final CameraMacosVideoRecorder recorder = CameraMacosVideoRecorder();
    final Completer<void> firstInit = Completer<void>();
    native.initGate = firstInit;

    await tester.pumpWidget(
      MaterialApp(home: SizedBox(child: recorder.openSession('usb-id'))),
    );
    await tester.pump();
    await recorder.release();

    native.initGate = null;
    await tester.pumpWidget(
      MaterialApp(home: SizedBox(child: recorder.openSession('built-in-id'))),
    );
    await tester.pump();

    firstInit.complete();
    await tester.pumpAndSettle();

    expect(native.countOf('destroy'), greaterThanOrEqualTo(1));

    await recorder.release();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('stopping a recording returns a jpeg thumbnail written to disk',
      (WidgetTester tester) async {
    final CameraMacosVideoRecorder recorder =
        CameraMacosVideoRecorder(temporaryDirectory: () async => temp);

    await tester.pumpWidget(
      MaterialApp(home: SizedBox(child: recorder.openSession('built-in-id'))),
    );
    await tester.pumpAndSettle();

    late VideoRecording recording;
    await tester.runAsync(() async {
      await recorder.start();
      recording = await recorder.stop();
    });

    final CaptureMedia? thumbnail = recording.thumbnail;
    expect(thumbnail, isA<CaptureFile>());
    expect(thumbnail!.mime, videoThumbnailMime);

    final File written = (thumbnail as CaptureFile).file;
    expect(p.isWithin(temp.path, written.path), isTrue);
    expect(p.extension(written.path), '.jpg');
    expect(written.readAsBytesSync(), _stillJpegBytes);
    expect(written.readAsBytesSync().sublist(0, 2), <int>[0xFF, 0xD8]);

    expect(native.methods, contains('takePicture'));
    expect(recording.media.mime, videoRecordingMime);
    expect((recording.media as CaptureFile).file.path, _stoppedVideoPath);

    await recorder.release();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'a failed still capture degrades to a null thumbnail without losing the '
      'recording', (WidgetTester tester) async {
    final CameraMacosVideoRecorder recorder =
        CameraMacosVideoRecorder(temporaryDirectory: () async => temp);
    native.failTakePicture = true;

    await tester.pumpWidget(
      MaterialApp(home: SizedBox(child: recorder.openSession('built-in-id'))),
    );
    await tester.pumpAndSettle();

    late VideoRecording recording;
    await tester.runAsync(() async {
      await recorder.start();
      recording = await recorder.stop();
    });

    expect(recording.thumbnail, isNull);
    expect(native.methods, contains('stopRecording'));
    expect(recording.media.mime, videoRecordingMime);
    expect((recording.media as CaptureFile).file.path, _stoppedVideoPath);

    await recorder.release();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
