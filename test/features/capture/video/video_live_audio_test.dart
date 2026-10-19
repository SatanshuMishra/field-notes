import 'dart:async';
import 'dart:io';

import 'package:camera_macos/camera_macos.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/settings/app_settings.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/microphone_hearing.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/video/video_composer.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder_provider.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart' show AudioEncoder, RecordConfig;

import '../audio/live_audio_test_support.dart';
import 'video_test_support.dart';

const MethodChannel _cameraMacosChannel = MethodChannel('camera_macos');
const MethodChannel _videoJoinChannel = MethodChannel('field_notes/video_join');

const String _cameraName = 'cam-0';
const List<int> _pictureBytes = <int>[0, 0, 0, 24];
const String _clearingStatus = 'Clearing background noise…';
const String _adjustingStatus = 'Adjusting the volume…';
const String _openLabel = 'open video';

class _Bench {
  _Bench(this.root);

  final Directory root;
  final List<String> events = <String>[];
  final List<Map<Object?, Object?>> macosStarts = <Map<Object?, Object?>>[];
  final List<String> pictures = <String>[];
  final FakeLiveAudio liveAudio = FakeLiveAudio();
  late final FakeMicrophone mic = FakeMicrophone(events: events);
  late final _FakeCamera camera = _FakeCamera(events, this);
  int _written = 0;

  Directory get temporary => Directory(p.join(root.path, 'tmp'));

  String write(String extension, List<int> bytes) {
    _written += 1;
    final Directory folder = Directory(p.join(root.path, 'camera'))
      ..createSync(recursive: true);
    final String path = p.join(folder.path, 'take_$_written.$extension');
    File(path).writeAsBytesSync(bytes);
    return path;
  }

  Future<Object?> videoJoin(MethodCall call) async {
    final Map<Object?, Object?> arguments =
        call.arguments as Map<Object?, Object?>;
    final String output = arguments['output']! as String;
    File(output).writeAsBytesSync(_pictureBytes);
    return output;
  }

  Future<Object?> cameraMacos(MethodCall call) async {
    switch (call.method) {
      case 'startRecording':
        macosStarts.add(call.arguments as Map<Object?, Object?>);
        events.add('camera.start');
        return <String, Object?>{'error': null};
      case 'pauseRecording':
        events.add('camera.pause');
        return true;
      case 'resumeRecording':
        events.add('camera.resume');
        return true;
      case 'stopRecording':
        events.add('camera.stop');
        final String movie = write('mp4', _pictureBytes);
        pictures.add(movie);
        return <String, Object?>{'url': movie, 'videoData': null};
      case 'destroy':
        return true;
    }
    return null;
  }
}

class _FakeCamera extends CameraPlatform {
  _FakeCamera(this.events, this.bench);

  final List<String> events;
  final _Bench bench;
  MediaSettings? settings;
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
  ) async {
    settings = mediaSettings;
    return 1;
  }

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
    events.add('camera.start');
  }

  @override
  Future<void> pauseVideoRecording(int cameraId) async {
    events.add('camera.pause');
  }

  @override
  Future<void> resumeVideoRecording(int cameraId) async {
    events.add('camera.resume');
  }

  @override
  Future<XFile> takePicture(int cameraId) async =>
      XFile(bench.write('jpg', const <int>[0xFF, 0xD8, 0xFF, 0xD9]));

  @override
  Future<XFile> stopVideoRecording(int cameraId) async {
    events.add('camera.stop');
    final String movie = bench.write('mp4', _pictureBytes);
    bench.pictures.add(movie);
    return XFile(movie);
  }

  @override
  Future<void> dispose(int cameraId) async {}

  @override
  Widget buildPreview(int cameraId) => const SizedBox();
}

class _Rig {
  const _Rig({
    required this.name,
    required this.recorder,
    required this.chosenInput,
    required this.cameraSoundOff,
    required this.pauseOrder,
  });

  final String name;
  final VideoRecorder recorder;
  final String chosenInput;
  final bool Function() cameraSoundOff;
  final List<String> pauseOrder;
}

_Rig _android(_Bench bench) {
  CameraPlatform.instance = bench.camera;
  return _Rig(
    name: 'CameraVideoRecorder',
    recorder: CameraVideoRecorder(
      temporaryDirectory: () async => bench.temporary,
      encoder: bench.liveAudio,
      audioJoiner: bench.liveAudio,
      audioRecorderFactory: () => bench.mic,
      chainRunner: passThroughChain,
      resolveInput: () async =>
          const AudioInput(id: 'mic-2', label: 'USB microphone'),
    ),
    chosenInput: 'mic-2',
    cameraSoundOff: () =>
        bench.camera.settings?.enableAudio == false &&
        bench.camera.settings?.audioBitrate == null,
    pauseOrder: const <String>[
      'camera.pause',
      'mic.pause',
      'camera.resume',
      'mic.resume',
    ],
  );
}

_Rig _windows(_Bench bench) {
  CameraPlatform.instance = bench.camera;
  final CameraWindowsVideoRecorder recorder = CameraWindowsVideoRecorder(
    temporaryDirectory: () async => bench.temporary,
    setAudioInputDevice: (String? endpointId) async {},
    encoder: bench.liveAudio,
    audioJoiner: bench.liveAudio,
    audioRecorderFactory: () => bench.mic,
    chainRunner: passThroughChain,
  )..useAudioInput('ep-2');
  return _Rig(
    name: 'CameraWindowsVideoRecorder',
    recorder: recorder,
    chosenInput: 'ep-2',
    cameraSoundOff: () =>
        bench.camera.settings?.enableAudio == false &&
        bench.camera.settings?.audioBitrate == null,
    pauseOrder: const <String>[
      'camera.stop',
      'mic.pause',
      'camera.start',
      'mic.resume',
    ],
  );
}

_Rig _macos(_Bench bench) {
  final CameraMacosVideoRecorder recorder = CameraMacosVideoRecorder(
    temporaryDirectory: () async => bench.temporary,
    controller: CameraMacOSController(
      CameraMacOSArguments(size: const Size(1280, 720)),
    ),
    microphonePermission: () async => true,
    encoder: bench.liveAudio,
    audioJoiner: bench.liveAudio,
    audioRecorderFactory: () => bench.mic,
    chainRunner: passThroughChain,
  )..useAudioInput('b');
  CameraMacOSView? view;
  return _Rig(
    name: 'CameraMacosVideoRecorder',
    recorder: _ViewCapturingRecorder(recorder, (Widget? opened) {
      view = opened as CameraMacOSView?;
    }),
    chosenInput: 'b',
    cameraSoundOff: () =>
        view?.enableAudio == false &&
        view?.audioBitrate == null &&
        bench.macosStarts.isNotEmpty &&
        bench.macosStarts.every(
          (Map<Object?, Object?> start) => start['enableAudio'] == false,
        ),
    pauseOrder: const <String>[
      'camera.pause',
      'mic.pause',
      'camera.resume',
      'mic.resume',
    ],
  );
}

class _ViewCapturingRecorder implements VideoRecorder {
  _ViewCapturingRecorder(this._inner, this._onView);

  final VideoRecorder _inner;
  final void Function(Widget? view) _onView;

  @override
  Duration get elapsed => _inner.elapsed;

  @override
  Stream<double> get level => _inner.level;

  @override
  Stream<MicrophoneHearing> get hearing => _inner.hearing;

  @override
  MicrophoneHearing get hearingNow => _inner.hearingNow;

  @override
  bool get supportsPause => _inner.supportsPause;

  @override
  Future<List<VideoCaptureDevice>> listDevices() => _inner.listDevices();

  @override
  Widget? openSession(String deviceId) {
    final Widget? view = _inner.openSession(deviceId);
    _onView(view);
    return view;
  }

  @override
  Future<void> start() => _inner.start();

  @override
  Future<void> pause() => _inner.pause();

  @override
  Future<void> resume() => _inner.resume();

  @override
  Future<VideoRecording> stop() => _inner.stop();

  @override
  Future<void> cancel() => _inner.cancel();

  @override
  Future<void> releaseSaved(VideoRecording recording) =>
      _inner.releaseSaved(recording);

  @override
  Future<void> release() => _inner.release();

  @override
  Future<void> dispose() => _inner.dispose();
}

final Map<String, _Rig Function(_Bench bench)> _rigs =
    <String, _Rig Function(_Bench bench)>{
      'android': _android,
      'windows': _windows,
      'macos': _macos,
    };

File _fileOf(CaptureMedia media) => (media as CaptureFile).file;

class _Launcher extends ConsumerWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appSettingsProvider);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showVideoComposer(context, '2026-10-16'),
      child: const Text(_openLabel),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late _Bench bench;
  late CameraPlatform original;

  setUp(() {
    root = Directory.systemTemp.createTempSync('video_live_audio_test_');
    bench = _Bench(root);
    original = CameraPlatform.instance;
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_cameraMacosChannel, bench.cameraMacos);
    messenger.setMockMethodCallHandler(_videoJoinChannel, bench.videoJoin);
  });

  tearDown(() {
    CameraPlatform.instance = original;
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_cameraMacosChannel, null);
    messenger.setMockMethodCallHandler(_videoJoinChannel, null);
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  Future<_Rig> openRig(String platform) async {
    final _Rig rig = _rigs[platform]!(bench);
    final List<VideoCaptureDevice> devices = platform == 'macos'
        ? const <VideoCaptureDevice>[
            VideoCaptureDevice(id: _cameraName, label: 'FaceTime HD Camera'),
          ]
        : await rig.recorder.listDevices();
    rig.recorder.openSession(devices.single.id);
    return rig;
  }

  for (final String platform in _rigs.keys) {
    group(platform, () {
      test('the camera records picture only', () async {
        final _Rig rig = await openRig(platform);

        await rig.recorder.start();

        expect(rig.cameraSoundOff(), isTrue, reason: rig.name);
        expect(bench.events, <String>['mic.start', 'camera.start']);
        final RecordConfig config = bench.mic.startStreamConfigs.single;
        expect(config.device?.id, rig.chosenInput);
        expect(config.encoder, AudioEncoder.pcm16bits);
        expect(config.sampleRate, 48000);
        expect(config.numChannels, 1);
        final FakeEncoderOpening open = bench.liveAudio.opened.single;
        expect(open.sampleRate, 48000);
        expect(open.channels, 1);
        expect(open.bitRate, 96000);
        expect(p.dirname(open.path), p.join(root.path, 'tmp', 'captures'));
        expect(p.extension(open.path), '.m4a');

        await rig.recorder.cancel();
      });

      test('keep joins picture and sound', () async {
        final _Rig rig = await openRig(platform);
        await rig.recorder.start();

        final VideoRecording take = await rig.recorder.stop();

        final FakeSoundJoin join = bench.liveAudio.joins.single;
        expect(join.videoBytes, _pictureBytes);
        expect(join.audioBytes, fakeSoundBytes);
        expect(join.audio, bench.liveAudio.opened.first.path);
        final File joined = _fileOf(take.media);
        expect(joined.path, join.output);
        expect(joined.readAsBytesSync(), fakeJoinedBytes);
        expect(p.dirname(joined.path), p.join(root.path, 'tmp', 'captures'));
        expect(File(join.video).existsSync(), isFalse);
        expect(File(join.audio).existsSync(), isFalse);
        for (final String picture in bench.pictures) {
          expect(File(picture).existsSync(), isFalse);
        }

        await rig.recorder.releaseSaved(take);
      });

      test('pause reaches both halves', () async {
        final _Rig rig = await openRig(platform);
        await rig.recorder.start();
        bench.events.clear();

        await rig.recorder.pause();
        await rig.recorder.resume();
        final List<String> paused = List<String>.of(bench.events);
        final VideoRecording take = await rig.recorder.stop();

        expect(paused, rig.pauseOrder);
        expect(
          bench.events.where((String event) => event == 'mic.pause'),
          hasLength(1),
        );
        expect(
          bench.events.where((String event) => event == 'mic.resume'),
          hasLength(1),
        );
        expect(_fileOf(take.media).readAsBytesSync(), fakeJoinedBytes);

        await rig.recorder.releaseSaved(take);
      });
    });
  }

  testWidgets('keep never waits on cleaning', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final File movie = File(p.join(root.path, 'joined.mp4'))
      ..writeAsBytesSync(fakeJoinedBytes);
    final FakeVideoRecorder recorder = FakeVideoRecorder(
      supportsPause: true,
      recording: VideoRecording(
        media: CaptureFile(file: movie, mime: 'video/mp4', durationMs: 6000),
        durationMs: 6000,
      ),
    )..elapsedValue = const Duration(seconds: 6);
    final FakeCaptureService service = FakeCaptureService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          videoRecorderProvider.overrideWith((Ref ref) => recorder),
          captureServiceProvider.overrideWith((Ref ref) => service),
          appSettingsProvider.overrideWith(
            (Ref ref) => Stream<AppSettings>.value(
              AppSettings.defaults.copyWith(
                inputProfile: InputProfile.voiceIsolation,
              ),
            ),
          ),
          reflectionPromptsOff(),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fieldNotesTheme(platform: TargetPlatform.macOS),
          home: const Scaffold(body: Center(child: _Launcher())),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(_openLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    for (int step = 0; step < 14; step += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump();
    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump();
    for (int step = 0; step < 14; step += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      tester.widget<VideoRecorderSheet>(find.byType(VideoRecorderSheet)).phase,
      VideoRecorderPhase.recording,
    );

    final List<String> statusesSeen = <String>[];
    bool toastShown = false;
    await tester.tap(find.byKey(videoSaveCircleKey));
    for (int frame = 0; frame < 600 && !toastShown; frame += 1) {
      await tester.pump(const Duration(milliseconds: 8));
      for (final String status in <String>[_clearingStatus, _adjustingStatus]) {
        if (find.text(status).evaluate().isNotEmpty) {
          statusesSeen.add(status);
        }
      }
      toastShown = find.text('Video saved').evaluate().isNotEmpty;
    }

    expect(toastShown, isTrue);
    expect(statusesSeen, isEmpty);
    expect(service.requests, hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
