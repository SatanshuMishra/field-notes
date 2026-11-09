import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/video/camera_picture_fill.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../audio/live_audio_test_support.dart';
import 'video_test_support.dart';

const int _cameraId = 21;
const int _macTexture = 3;
const int _settleTurns = 12;
const Key _platformPreviewKey = ValueKey<String>('platforms-platform-preview');
const Size _phoneArea = Size(412, 915);
const Size _wideArea = Size(2560, 800);
const Size _laptopArea = Size(1440, 900);
const Color _black = Color(0xFF000000);

const List<CameraDescription> _cameras = <CameraDescription>[
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

const Map<String, Object?> _macBuiltIn = <String, Object?>{
  'deviceType': 0,
  'localizedName': 'FaceTime HD Camera',
  'manufacturer': 'Apple Inc.',
  'deviceId': 'built-in-id',
};

class _FakeCameraPlatform extends CameraPlatform {
  final StreamController<CameraInitializedEvent> _initialized =
      StreamController<CameraInitializedEvent>.broadcast();
  final StreamController<CameraResolutionChangedEvent> _resolutions =
      StreamController<CameraResolutionChangedEvent>.broadcast();
  final StreamController<CameraClosingEvent> _closings =
      StreamController<CameraClosingEvent>.broadcast();
  final StreamController<CameraErrorEvent> _errors =
      StreamController<CameraErrorEvent>.broadcast();
  final StreamController<VideoRecordedEvent> _recorded =
      StreamController<VideoRecordedEvent>.broadcast();
  final StreamController<DeviceOrientationChangedEvent> _orientations =
      StreamController<DeviceOrientationChangedEvent>.broadcast();
  final StreamController<CameraImageData> _frames =
      StreamController<CameraImageData>.broadcast();

  @override
  Future<List<CameraDescription>> availableCameras() async => _cameras;

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
  Stream<CameraResolutionChangedEvent> onCameraResolutionChanged(
    int cameraId,
  ) => _resolutions.stream;

  @override
  Stream<CameraClosingEvent> onCameraClosing(int cameraId) => _closings.stream;

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _errors.stream;

  @override
  Stream<VideoRecordedEvent> onVideoRecordedEvent(int cameraId) =>
      _recorded.stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      _orientations.stream;

  @override
  Future<void> lockCaptureOrientation(
    int cameraId,
    DeviceOrientation orientation,
  ) async {}

  @override
  Future<void> unlockCaptureOrientation(int cameraId) async {}

  @override
  Future<XFile> takePicture(int cameraId) async =>
      throw CameraException('takePicture', 'No still in this test.');

  @override
  Future<void> prepareForVideoRecording() async {}

  @override
  Future<void> startVideoRecording(
    int cameraId, {
    Duration? maxVideoDuration,
  }) async {}

  @override
  Future<void> startVideoCapturing(VideoCaptureOptions options) async {}

  @override
  Future<XFile> stopVideoRecording(int cameraId) async =>
      throw CameraException('stopVideoRecording', 'No take in this test.');

  @override
  Future<void> pauseVideoRecording(int cameraId) async {}

  @override
  Future<void> resumeVideoRecording(int cameraId) async {}

  @override
  bool supportsImageStreaming() => false;

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    CameraImageStreamOptions? options,
  }) => _frames.stream;

  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {}

  @override
  Future<void> setExposureMode(int cameraId, ExposureMode mode) async {}

  @override
  Future<void> setExposurePoint(int cameraId, Point<double>? point) async {}

  @override
  Future<double> getMinExposureOffset(int cameraId) async => 0;

  @override
  Future<double> getMaxExposureOffset(int cameraId) async => 0;

  @override
  Future<double> getExposureOffsetStepSize(int cameraId) async => 0;

  @override
  Future<double> setExposureOffset(int cameraId, double offset) async => offset;

  @override
  Future<void> setFocusMode(int cameraId, FocusMode mode) async {}

  @override
  Future<void> setFocusPoint(int cameraId, Point<double>? point) async {}

  @override
  Future<double> getMaxZoomLevel(int cameraId) async => 8;

  @override
  Future<double> getMinZoomLevel(int cameraId) async => 1;

  @override
  Future<void> setZoomLevel(int cameraId, double zoom) async {}

  @override
  Future<Iterable<VideoStabilizationMode>> getSupportedVideoStabilizationModes(
    int cameraId,
  ) async => const <VideoStabilizationMode>[VideoStabilizationMode.off];

  @override
  Future<void> setVideoStabilizationMode(
    int cameraId,
    VideoStabilizationMode mode,
  ) async {}

  @override
  Future<void> pausePreview(int cameraId) async {}

  @override
  Future<void> resumePreview(int cameraId) async {}

  @override
  Future<void> setDescriptionWhileRecording(
    CameraDescription description,
  ) async {}

  @override
  Widget buildPreview(int cameraId) =>
      const SizedBox.expand(key: _platformPreviewKey);

  @override
  Future<void> dispose(int cameraId) async {}

  @override
  Future<void> setImageFileFormat(int cameraId, ImageFileFormat format) async {}

  @override
  Future<void> setJpegImageQuality(int cameraId, int quality) async {}
}

class _MacChannel {
  _MacChannel({this.answers = true});

  final bool answers;
  final List<String> methods = <String>[];
  final Completer<Object?> _never = Completer<Object?>();

  int countOf(String method) => methods.where((String m) => m == method).length;

  Future<Object?> handle(MethodCall call) async {
    methods.add(call.method);
    switch (call.method) {
      case 'listDevices':
        return <String, Object?>{
          'devices': <Map<String, Object?>>[_macBuiltIn],
        };
      case 'initialize':
        if (!answers) {
          return _never.future;
        }
        return <String, Object?>{
          'textureId': _macTexture,
          'size': <String, Object?>{'width': 1920.0, 'height': 1080.0},
          'devices': <Map<String, Object?>>[_macBuiltIn],
        };
      case 'destroy':
        return true;
      default:
        return null;
    }
  }
}

Directory _tempRoot() {
  final Directory root = Directory.systemTemp.createTempSync(
    'picture_platforms_',
  );
  addTearDown(() => root.deleteSync(recursive: true));
  return root;
}

void _useFakeCamera() {
  final CameraPlatform original = CameraPlatform.instance;
  CameraPlatform.instance = _FakeCameraPlatform();
  addTearDown(() => CameraPlatform.instance = original);
}

_MacChannel _useMacChannel({bool answers = true}) {
  final _MacChannel channel = _MacChannel(answers: answers);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(cameraMacosChannel, channel.handle);
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraMacosChannel, null),
  );
  return channel;
}

CameraVideoRecorder _phoneRecorder() {
  final Directory root = _tempRoot();
  final FakeLiveAudio liveAudio = FakeLiveAudio();
  final FakeMicrophone mic = FakeMicrophone();
  return CameraVideoRecorder(
    temporaryDirectory: () async => root,
    encoder: liveAudio,
    audioJoiner: liveAudio,
    audioRecorderFactory: () => mic,
    chainRunner: passThroughChain,
  );
}

CameraWindowsVideoRecorder _windowsRecorder() {
  final Directory root = _tempRoot();
  final FakeLiveAudio liveAudio = FakeLiveAudio();
  final FakeMicrophone mic = FakeMicrophone();
  return CameraWindowsVideoRecorder(
    temporaryDirectory: () async => root,
    setAudioInputDevice: (String? endpointId) async {},
    encoder: liveAudio,
    audioJoiner: liveAudio,
    audioRecorderFactory: () => mic,
    chainRunner: passThroughChain,
  );
}

CameraMacosVideoRecorder _macRecorder() {
  final Directory root = _tempRoot();
  final FakeLiveAudio liveAudio = FakeLiveAudio();
  final FakeMicrophone mic = FakeMicrophone();
  return CameraMacosVideoRecorder(
    temporaryDirectory: () async => root,
    microphonePermission: () async => true,
    encoder: liveAudio,
    audioJoiner: liveAudio,
    audioRecorderFactory: () => mic,
    chainRunner: passThroughChain,
  );
}

Future<void> _show(WidgetTester tester, Widget? preview, Size area) async {
  tester.view.physicalSize = area;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox.fromSize(
        size: area,
        child: preview ?? const SizedBox.shrink(),
      ),
    ),
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() shown,
  String what,
) async {
  for (int turn = 0; turn < _settleTurns; turn += 1) {
    if (shown()) {
      return;
    }
    await tester.pump();
  }
  fail('$what never showed.');
}

bool _platformPreviewShows() =>
    find.byKey(_platformPreviewKey).evaluate().isNotEmpty;

Finder _macTextures() => find.byWidgetPredicate(
  (Widget widget) => widget is Texture && widget.textureId == _macTexture,
);

double _fadeOf(WidgetTester tester, Finder finder) {
  final Element element = tester.element(finder);
  double product = _ownFade(element.widget);
  element.visitAncestorElements((Element ancestor) {
    product *= _ownFade(ancestor.widget);
    return true;
  });
  return product;
}

double _ownFade(Widget widget) {
  if (widget is Opacity) {
    return widget.opacity;
  }
  if (widget is FadeTransition) {
    return widget.opacity.value;
  }
  return 1;
}

Future<void> _close(
  WidgetTester tester,
  Future<void> Function() dispose,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(dispose);
}

void main() {
  testWidgets('the phone camera draws the picture with the fill behind it', (
    WidgetTester tester,
  ) async {
    _useFakeCamera();
    final CameraVideoRecorder recorder = _phoneRecorder();
    final devices = await recorder.listDevices();

    await _show(tester, recorder.openSession(devices.first.id), _phoneArea);
    await _pumpUntil(tester, _platformPreviewShows, 'The phone picture');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CameraPictureStage), findsOneWidget);
    expect(find.byKey(_platformPreviewKey), findsNWidgets(2));

    await _close(tester, recorder.dispose);
  });

  testWidgets('the Windows camera draws the picture with the fill behind it', (
    WidgetTester tester,
  ) async {
    _useFakeCamera();
    final CameraWindowsVideoRecorder recorder = _windowsRecorder();
    final devices = await recorder.listDevices();

    await _show(tester, recorder.openSession(devices.first.id), _wideArea);
    await _pumpUntil(tester, _platformPreviewShows, 'The Windows picture');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CameraPictureStage), findsOneWidget);
    expect(find.byKey(_platformPreviewKey), findsNWidgets(2));

    await _close(tester, recorder.dispose);
  });

  testWidgets('the Mac camera draws its texture twice once it is ready', (
    WidgetTester tester,
  ) async {
    _useMacChannel();
    final CameraMacosVideoRecorder recorder = _macRecorder();

    await _show(tester, recorder.openSession('built-in-id'), _wideArea);
    await _pumpUntil(
      tester,
      () => _macTextures().evaluate().length >= 2,
      'The Mac picture and its fill',
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(_macTextures(), findsNWidgets(2));

    await _close(tester, recorder.dispose);
  });

  testWidgets(
    'the Mac camera is not opened twice when the fill appears or the window changes',
    (WidgetTester tester) async {
      final _MacChannel channel = _useMacChannel();
      final CameraMacosVideoRecorder recorder = _macRecorder();
      final Widget? preview = recorder.openSession('built-in-id');

      await _show(tester, preview, _wideArea);
      await _pumpUntil(
        tester,
        () => _macTextures().evaluate().length >= 2,
        'The Mac picture and its fill',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await _show(tester, preview, _laptopArea);
      for (int turn = 0; turn < _settleTurns; turn += 1) {
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(channel.countOf('initialize'), 1);

      await _close(tester, recorder.dispose);
    },
  );

  testWidgets('the Mac recorder shows no black while the camera is loading', (
    WidgetTester tester,
  ) async {
    final _MacChannel channel = _useMacChannel(answers: false);
    final CameraMacosVideoRecorder recorder = _macRecorder();

    await _show(tester, recorder.openSession('built-in-id'), _wideArea);
    await _pumpUntil(
      tester,
      () => channel.countOf('initialize') > 0,
      'The Mac camera request',
    );
    for (int turn = 0; turn < _settleTurns; turn += 1) {
      await tester.pump();
    }

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is ColoredBox &&
            widget.color.toARGB32() == _black.toARGB32(),
      ),
      findsNothing,
    );

    await _close(tester, recorder.dispose);
  });

  testWidgets('the picture fades in once the camera is ready', (
    WidgetTester tester,
  ) async {
    _useFakeCamera();
    final CameraVideoRecorder recorder = _phoneRecorder();
    final devices = await recorder.listDevices();
    final Finder picture = find.descendant(
      of: find.byKey(cameraPictureKey),
      matching: find.byKey(_platformPreviewKey),
    );

    await _show(tester, recorder.openSession(devices.first.id), _phoneArea);
    await _pumpUntil(tester, _platformPreviewShows, 'The phone picture');
    await tester.pump(const Duration(milliseconds: 130));

    final double midway = _fadeOf(tester, picture);
    expect(midway, greaterThan(0));
    expect(midway, lessThan(1));

    await tester.pump(const Duration(milliseconds: 300));

    expect(_fadeOf(tester, picture), closeTo(1, 1e-9));

    await _close(tester, recorder.dispose);
  });
}
