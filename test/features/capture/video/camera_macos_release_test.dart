import 'dart:async';

import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _NativeCameraSpy {
  final List<MethodCall> calls = <MethodCall>[];
  Completer<void>? initGate;

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

  setUp(() {
    native = _NativeCameraSpy();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_cameraChannel, native.handle);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_cameraChannel, null);
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
}
