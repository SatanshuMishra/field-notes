import 'dart:async';
import 'dart:io';

import 'package:camera_macos/camera_macos.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:clock/clock.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../audio/live_audio_test_support.dart';

const MethodChannel _cameraMacosChannel = MethodChannel('camera_macos');
const String _cameraName = 'cam-0';
const List<int> _pictureBytes = <int>[0, 0, 0, 24];
const int _sampleRate = 48000;
const int _chunkSamples = 4800;
const Duration _chunk = Duration(milliseconds: 100);
const int _chunksBeforeTake = 3;
const int _chunksInTake = 30;
const String _micStart = 'mic.start';
const String _micStop = 'mic.stop';
const String _micCancel = 'mic.cancel';

class _Bench {
  _Bench(this.root);

  final Directory root;
  final List<String> events = <String>[];
  final FakeLiveAudio liveAudio = FakeLiveAudio();
  late final FakeMicrophone mic = FakeMicrophone(events: events);
  late final _FakeCamera camera = _FakeCamera(this);
  Duration _now = Duration.zero;
  int _written = 0;

  Duration now() => _now;

  Clock get wallClock => Clock(() => DateTime(2026, 10, 18).add(_now));

  void advance(Duration time) => _now += time;

  Directory get temporary => Directory(p.join(root.path, 'tmp'));

  int get microphoneOpens => mic.startStreamConfigs.length;

  String write(String extension, List<int> bytes) {
    _written += 1;
    final Directory folder = Directory(p.join(root.path, 'camera'))
      ..createSync(recursive: true);
    final String path = p.join(folder.path, 'take_$_written.$extension');
    File(path).writeAsBytesSync(bytes);
    return path;
  }

  Future<Object?> cameraMacos(MethodCall call) async {
    switch (call.method) {
      case 'startRecording':
        events.add('camera.start');
        return <String, Object?>{'started': true, 'error': null};
      case 'stopRecording':
        events.add('camera.stop');
        return <String, Object?>{
          'url': write('mp4', _pictureBytes),
          'videoData': null,
        };
      case 'destroy':
        return true;
    }
    return null;
  }

  CameraMacosVideoRecorder macos() => withClock(
    wallClock,
    () => CameraMacosVideoRecorder(
      temporaryDirectory: () async => temporary,
      controller: CameraMacOSController(
        CameraMacOSArguments(size: const Size(1280, 720)),
      ),
      microphonePermission: () async => true,
      encoder: liveAudio,
      audioJoiner: liveAudio,
      audioRecorderFactory: () => mic,
      chainRunner: passThroughChain,
      clock: now,
    )..useAudioInput('b'),
  );

  CameraWindowsVideoRecorder windows() {
    CameraPlatform.instance = camera;
    return CameraWindowsVideoRecorder(
      temporaryDirectory: () async => temporary,
      setAudioInputDevice: (String? endpointId) async {},
      encoder: liveAudio,
      audioJoiner: liveAudio,
      audioRecorderFactory: () => mic,
      chainRunner: passThroughChain,
    )..useAudioInput('ep-2');
  }

  CameraVideoRecorder android() {
    CameraPlatform.instance = camera;
    return CameraVideoRecorder(
      temporaryDirectory: () async => temporary,
      encoder: liveAudio,
      audioJoiner: liveAudio,
      audioRecorderFactory: () => mic,
      chainRunner: passThroughChain,
      resolveInput: () async =>
          const AudioInput(id: 'mic-2', label: 'USB microphone'),
    );
  }
}

class _FakeCamera extends CameraPlatform {
  _FakeCamera(this.bench);

  final _Bench bench;
  final StreamController<CameraInitializedEvent> _initialized =
      StreamController<CameraInitializedEvent>.broadcast();
  final StreamController<CameraErrorEvent> _errors =
      StreamController<CameraErrorEvent>.broadcast();

  @override
  Future<List<CameraDescription>> availableCameras() async =>
      const <CameraDescription>[
        CameraDescription(
          name: _cameraName,
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 0,
        ),
      ];

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async => 1;

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    scheduleMicrotask(
      () => _initialized.add(
        const CameraInitializedEvent(
          1,
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
  Future<void> startVideoCapturing(VideoCaptureOptions options) async {
    bench.events.add('camera.start');
  }

  @override
  Future<XFile> takePicture(int cameraId) async =>
      XFile(bench.write('jpg', const <int>[0xFF, 0xD8, 0xFF, 0xD9]));

  @override
  Future<XFile> stopVideoRecording(int cameraId) async {
    bench.events.add('camera.stop');
    return XFile(bench.write('mp4', _pictureBytes));
  }

  @override
  Future<void> dispose(int cameraId) async {}

  @override
  Widget buildPreview(int cameraId) => const SizedBox();
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

Future<void> _untilMicrophoneOpens(_Bench bench) async {
  for (int round = 0; round < 200 && bench.microphoneOpens == 0; round += 1) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  await _settle();
}

Future<void> _movieBegan() => TestDefaultBinaryMessengerBinding
    .instance
    .defaultBinaryMessenger
    .handlePlatformMessage(
      _cameraMacosChannel.name,
      _cameraMacosChannel.codec.encodeMethodCall(
        const MethodCall('onVideoRecordingStarted'),
      ),
      (ByteData? _) {},
    );

Future<void> _speak(_Bench bench, int chunks) async {
  for (int chunk = 0; chunk < chunks; chunk += 1) {
    bench.advance(_chunk);
    bench.mic.push(pcmAtDbfs(-20, samples: _chunkSamples));
    await _settle();
  }
}

Duration _soundWritten(FakeLiveAudio liveAudio) => Duration(
  microseconds:
      liveAudio.samplesAppended * Duration.microsecondsPerSecond ~/ _sampleRate,
);

int _opensBefore(List<String> events, String marker) => events
    .take(events.indexOf(marker))
    .where((String event) => event == _micStart)
    .length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late _Bench bench;
  late CameraPlatform original;

  setUp(() {
    root = Directory.systemTemp.createTempSync('warm_microphone_test_');
    bench = _Bench(root);
    original = CameraPlatform.instance;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_cameraMacosChannel, bench.cameraMacos);
  });

  tearDown(() {
    CameraPlatform.instance = original;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_cameraMacosChannel, null);
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  test('a macOS take uses the microphone opened with the preview', () async {
    final CameraMacosVideoRecorder recorder = bench.macos();

    recorder.openSession(_cameraName);
    await _untilMicrophoneOpens(bench);

    expect(
      bench.microphoneOpens,
      1,
      reason: 'the microphone did not open with the camera preview',
    );

    await recorder.start();
    await _movieBegan();
    await _speak(bench, 2);

    expect(
      bench.microphoneOpens,
      1,
      reason: 'the take reopened the microphone the preview had open',
    );
    expect(bench.mic.startStreamConfigs.single.device?.id, 'b');

    await recorder.dispose();

    expect(bench.microphoneOpens, 1);
    expect(bench.events.last, _micCancel);
  });

  test('a Windows take uses the microphone opened with the preview', () async {
    final CameraWindowsVideoRecorder recorder = bench.windows();

    recorder.openSession((await recorder.listDevices()).single.id);
    await _untilMicrophoneOpens(bench);

    expect(
      bench.microphoneOpens,
      1,
      reason: 'the microphone did not open with the camera preview',
    );

    await recorder.start();

    expect(
      bench.microphoneOpens,
      1,
      reason: 'the take reopened the microphone the preview had open',
    );
    expect(bench.mic.startStreamConfigs.single.device?.id, 'ep-2');

    final VideoRecording take = await recorder.stop();

    expect(bench.microphoneOpens, 1);
    expect(bench.liveAudio.joins.single.audioBytes, fakeSoundBytes);

    await recorder.releaseSaved(take);
    await recorder.dispose();
  });

  test('an Android take uses the microphone opened with the preview', () async {
    final CameraVideoRecorder recorder = bench.android();

    recorder.openSession((await recorder.listDevices()).first.id);
    await _untilMicrophoneOpens(bench);

    expect(
      bench.microphoneOpens,
      1,
      reason: 'the microphone did not open with the camera preview',
    );

    await recorder.start();

    expect(
      bench.microphoneOpens,
      1,
      reason: 'the take reopened the microphone the preview had open',
    );
    expect(bench.mic.startStreamConfigs.single.device?.id, 'mic-2');

    final VideoRecording take = await recorder.stop();

    expect(bench.microphoneOpens, 1);

    await recorder.releaseSaved(take);
    await recorder.dispose();
  });

  test('a healthy macOS take writes sound for the whole picture and reopens nothing', () async {
    final CameraMacosVideoRecorder recorder = bench.macos();
    recorder.openSession(_cameraName);
    await _untilMicrophoneOpens(bench);
    await _speak(bench, _chunksBeforeTake);
    final int opensBeforeTake = bench.microphoneOpens;

    await recorder.start();
    await _movieBegan();
    await _speak(bench, _chunksInTake);
    final VideoRecording take = await recorder.stop();

    expect(bench.events, contains(_micStop));
    expect(
      _opensBefore(bench.events, _micStop),
      1,
      reason: 'the microphone was opened more than once for one take',
    );
    expect(
      opensBeforeTake,
      1,
      reason: 'the microphone was not already open when the take began',
    );
    expect(take.durationMs, _chunk.inMilliseconds * _chunksInTake);
    expect(
      (_soundWritten(bench.liveAudio).inMilliseconds - take.durationMs).abs(),
      lessThanOrEqualTo(_chunk.inMilliseconds),
      reason: 'the saved sound does not cover the whole picture',
    );

    await recorder.releaseSaved(take);
    await recorder.dispose();
  });
}
