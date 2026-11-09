import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../audio/live_audio_test_support.dart';

const int _cameraId = 11;
const int _settleTurns = 10;
const Key _platformPreviewKey = ValueKey<String>('primes-platform-preview');
const Size _phoneScreen = Size(412, 915);

const List<VideoStabilizationMode> _offAndLevelOne = <VideoStabilizationMode>[
  VideoStabilizationMode.off,
  VideoStabilizationMode.level1,
];

const List<CameraDescription> _phoneCameras = <CameraDescription>[
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

class _LoggingCameraPlatform extends CameraPlatform {
  _LoggingCameraPlatform({
    this.refusesStabilisation = false,
    this.opening,
    this.openFailure,
  });

  final bool refusesStabilisation;
  final Completer<void>? opening;
  final CameraException? openFailure;
  final List<String> calls = <String>[];
  final List<VideoStabilizationMode> stabilised = <VideoStabilizationMode>[];
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

  void _log(String call) => calls.add(call);

  @override
  Future<List<CameraDescription>> availableCameras() async {
    _log('availableCameras');
    return _phoneCameras;
  }

  @override
  Future<int> createCamera(
    CameraDescription cameraDescription,
    ResolutionPreset? resolutionPreset, {
    bool enableAudio = false,
  }) async {
    _log('createCamera');
    return _cameraId;
  }

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async {
    _log('createCameraWithSettings');
    return _cameraId;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    _log('initializeCamera');
    await opening?.future;
    final CameraException? failure = openFailure;
    if (failure != null) {
      throw failure;
    }
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
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) {
    _log('onCameraInitialized');
    return _initialized.stream;
  }

  @override
  Stream<CameraResolutionChangedEvent> onCameraResolutionChanged(int cameraId) {
    _log('onCameraResolutionChanged');
    return _resolutions.stream;
  }

  @override
  Stream<CameraClosingEvent> onCameraClosing(int cameraId) {
    _log('onCameraClosing');
    return _closings.stream;
  }

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) {
    _log('onCameraError');
    return _errors.stream;
  }

  @override
  Stream<VideoRecordedEvent> onVideoRecordedEvent(int cameraId) {
    _log('onVideoRecordedEvent');
    return _recorded.stream;
  }

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() {
    _log('onDeviceOrientationChanged');
    return _orientations.stream;
  }

  @override
  Future<void> lockCaptureOrientation(
    int cameraId,
    DeviceOrientation orientation,
  ) async => _log('lockCaptureOrientation');

  @override
  Future<void> unlockCaptureOrientation(int cameraId) async =>
      _log('unlockCaptureOrientation');

  @override
  Future<XFile> takePicture(int cameraId) async {
    _log('takePicture');
    throw CameraException('takePicture', 'No still in this test.');
  }

  @override
  Future<void> prepareForVideoRecording() async =>
      _log('prepareForVideoRecording');

  @override
  Future<void> startVideoRecording(
    int cameraId, {
    Duration? maxVideoDuration,
  }) async => _log('startVideoRecording');

  @override
  Future<void> startVideoCapturing(VideoCaptureOptions options) async =>
      _log('startVideoCapturing');

  @override
  Future<XFile> stopVideoRecording(int cameraId) async {
    _log('stopVideoRecording');
    throw CameraException('stopVideoRecording', 'No take in this test.');
  }

  @override
  Future<void> pauseVideoRecording(int cameraId) async =>
      _log('pauseVideoRecording');

  @override
  Future<void> resumeVideoRecording(int cameraId) async =>
      _log('resumeVideoRecording');

  @override
  bool supportsImageStreaming() {
    _log('supportsImageStreaming');
    return false;
  }

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    CameraImageStreamOptions? options,
  }) {
    _log('onStreamedFrameAvailable');
    return _frames.stream;
  }

  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async =>
      _log('setFlashMode');

  @override
  Future<void> setExposureMode(int cameraId, ExposureMode mode) async =>
      _log('setExposureMode');

  @override
  Future<void> setExposurePoint(int cameraId, Point<double>? point) async =>
      _log('setExposurePoint');

  @override
  Future<double> getMinExposureOffset(int cameraId) async {
    _log('getMinExposureOffset');
    return 0;
  }

  @override
  Future<double> getMaxExposureOffset(int cameraId) async {
    _log('getMaxExposureOffset');
    return 0;
  }

  @override
  Future<double> getExposureOffsetStepSize(int cameraId) async {
    _log('getExposureOffsetStepSize');
    return 0;
  }

  @override
  Future<double> setExposureOffset(int cameraId, double offset) async {
    _log('setExposureOffset');
    return offset;
  }

  @override
  Future<void> setFocusMode(int cameraId, FocusMode mode) async =>
      _log('setFocusMode');

  @override
  Future<void> setFocusPoint(int cameraId, Point<double>? point) async =>
      _log('setFocusPoint');

  @override
  Future<double> getMaxZoomLevel(int cameraId) async {
    _log('getMaxZoomLevel');
    return 8;
  }

  @override
  Future<double> getMinZoomLevel(int cameraId) async {
    _log('getMinZoomLevel');
    return 1;
  }

  @override
  Future<void> setZoomLevel(int cameraId, double zoom) async =>
      _log('setZoomLevel');

  @override
  Future<Iterable<VideoStabilizationMode>> getSupportedVideoStabilizationModes(
    int cameraId,
  ) async {
    _log('getSupportedVideoStabilizationModes');
    return _offAndLevelOne;
  }

  @override
  Future<void> setVideoStabilizationMode(
    int cameraId,
    VideoStabilizationMode mode,
  ) async {
    _log('setVideoStabilizationMode');
    stabilised.add(mode);
    if (refusesStabilisation) {
      throw CameraException(
        'setVideoStabilizationMode',
        'This camera refuses the stabilisation setting.',
      );
    }
  }

  @override
  Future<void> pausePreview(int cameraId) async => _log('pausePreview');

  @override
  Future<void> resumePreview(int cameraId) async => _log('resumePreview');

  @override
  Future<void> setDescriptionWhileRecording(
    CameraDescription description,
  ) async => _log('setDescriptionWhileRecording');

  @override
  Widget buildPreview(int cameraId) {
    _log('buildPreview');
    return const SizedBox.expand(key: _platformPreviewKey);
  }

  @override
  Future<void> dispose(int cameraId) async => _log('dispose');

  @override
  Future<void> setImageFileFormat(int cameraId, ImageFileFormat format) async =>
      _log('setImageFileFormat');

  @override
  Future<void> setJpegImageQuality(int cameraId, int quality) async =>
      _log('setJpegImageQuality');
}

class _PermissionCountingMicrophone extends FakeMicrophone {
  int timesAsked = 0;

  @override
  Future<bool> hasPermission({bool request = true}) async {
    timesAsked += 1;
    return true;
  }
}

class _Phone {
  _Phone(this.platform, this.root)
    : mic = _PermissionCountingMicrophone(),
      liveAudio = FakeLiveAudio();

  final _LoggingCameraPlatform platform;
  final Directory root;
  final _PermissionCountingMicrophone mic;
  final FakeLiveAudio liveAudio;

  CameraVideoRecorder recorder() => CameraVideoRecorder(
    temporaryDirectory: () async => root,
    encoder: liveAudio,
    audioJoiner: liveAudio,
    audioRecorderFactory: () => mic,
    chainRunner: passThroughChain,
  );
}

_Phone _phoneWith(_LoggingCameraPlatform platform) {
  final CameraPlatform original = CameraPlatform.instance;
  CameraPlatform.instance = platform;
  final Directory root = Directory.systemTemp.createTempSync('open_primes_');
  addTearDown(() {
    CameraPlatform.instance = original;
    root.deleteSync(recursive: true);
  });
  return _Phone(platform, root);
}

Future<void> _openUntilPictureShows(
  WidgetTester tester,
  CameraVideoRecorder recorder,
) async {
  tester.view.physicalSize = _phoneScreen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final devices = await recorder.listDevices();
  final Widget? preview = recorder.openSession(devices.first.id);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox.fromSize(
        size: _phoneScreen,
        child: preview ?? const SizedBox.shrink(),
      ),
    ),
  );
  for (int turn = 0; turn < _settleTurns; turn += 1) {
    if (find.byKey(_platformPreviewKey).evaluate().isNotEmpty) {
      return;
    }
    await tester.pump();
  }
  fail('The camera picture never showed.');
}

Future<void> _settle(WidgetTester tester) async {
  for (int turn = 0; turn < _settleTurns; turn += 1) {
    await tester.pump();
  }
}

Future<void> _beginOpening(
  WidgetTester tester,
  CameraVideoRecorder recorder,
) async {
  final devices = await recorder.listDevices();
  recorder.openSession(devices.first.id);
  await _settle(tester);
}

Future<void> _close(WidgetTester tester, CameraVideoRecorder recorder) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(recorder.dispose);
}

void main() {
  testWidgets('the microphone is asked for only once the camera has opened', (
    WidgetTester tester,
  ) async {
    final Completer<void> opening = Completer<void>();
    final _Phone phone = _phoneWith(_LoggingCameraPlatform(opening: opening));
    final CameraVideoRecorder recorder = phone.recorder();

    await _beginOpening(tester, recorder);

    expect(phone.platform.calls, contains('initializeCamera'));
    expect(phone.mic.timesAsked, 0);

    opening.complete();
    await _settle(tester);

    expect(phone.mic.timesAsked, 1);

    await _close(tester, recorder);
  });

  testWidgets('the microphone is still asked for when the camera is refused', (
    WidgetTester tester,
  ) async {
    final _Phone phone = _phoneWith(
      _LoggingCameraPlatform(
        openFailure: CameraException(
          'CameraAccessDenied',
          'The camera was refused.',
        ),
      ),
    );
    final CameraVideoRecorder recorder = phone.recorder();

    await _beginOpening(tester, recorder);

    expect(phone.mic.timesAsked, 1);

    await _close(tester, recorder);
  });

  testWidgets('leaving while the camera opens never asks for the microphone', (
    WidgetTester tester,
  ) async {
    final Completer<void> opening = Completer<void>();
    final _Phone phone = _phoneWith(_LoggingCameraPlatform(opening: opening));
    final CameraVideoRecorder recorder = phone.recorder();

    await _beginOpening(tester, recorder);
    final Future<void> releasing = recorder.release();
    await _settle(tester);
    opening.complete();
    await _settle(tester);
    await tester.runAsync(() => releasing);

    expect(phone.mic.timesAsked, 0);

    await _close(tester, recorder);
  });

  testWidgets('starting a take makes no camera call but the recording call', (
    WidgetTester tester,
  ) async {
    final _Phone phone = _phoneWith(_LoggingCameraPlatform());
    final CameraVideoRecorder recorder = phone.recorder();
    await _openUntilPictureShows(tester, recorder);
    phone.platform.calls.clear();

    await tester.runAsync(recorder.start);

    expect(phone.platform.calls, <String>['startVideoCapturing']);

    await _close(tester, recorder);
  });

  testWidgets(
    'opening the phone camera turns stabilisation off before the picture shows',
    (WidgetTester tester) async {
      final _Phone phone = _phoneWith(_LoggingCameraPlatform());
      final CameraVideoRecorder recorder = phone.recorder();

      await _openUntilPictureShows(tester, recorder);

      final List<String> calls = phone.platform.calls;
      expect(phone.platform.stabilised, <VideoStabilizationMode>[
        VideoStabilizationMode.off,
      ]);
      expect(
        calls.indexOf('setVideoStabilizationMode'),
        lessThan(calls.indexOf('buildPreview')),
      );

      await _close(tester, recorder);
    },
  );

  testWidgets('the camera never asks for stabilisation', (
    WidgetTester tester,
  ) async {
    final _Phone phone = _phoneWith(_LoggingCameraPlatform());
    final CameraVideoRecorder recorder = phone.recorder();
    await _openUntilPictureShows(tester, recorder);

    await tester.runAsync(recorder.start);

    expect(phone.platform.calls, contains('startVideoCapturing'));
    expect(
      phone.platform.stabilised,
      isNot(contains(VideoStabilizationMode.level1)),
    );

    await _close(tester, recorder);
  });

  testWidgets(
    'a camera that refuses the stabilisation setting still opens and records',
    (WidgetTester tester) async {
      final _Phone phone = _phoneWith(
        _LoggingCameraPlatform(refusesStabilisation: true),
      );
      final CameraVideoRecorder recorder = phone.recorder();

      await _openUntilPictureShows(tester, recorder);
      expect(recorder.previewRectIn(_phoneScreen), isNotNull);
      phone.platform.calls.clear();

      await tester.runAsync(recorder.start);

      expect(phone.platform.calls, contains('startVideoCapturing'));

      await _close(tester, recorder);
    },
  );
}
