import 'dart:async';

import 'package:camera_macos/camera_macos.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/media/audio_output.dart';
import 'package:field_notes/domain/settings/app_settings.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/video/video_composer.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder_provider.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/voice/voice_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart'
    show AudioRecorder, InputDevice, RecordConfig;

import '../../settings/support/fake_settings_repository.dart';
import 'video_test_support.dart';

const MethodChannel _cameraChannel = MethodChannel('camera_macos');
const String _camera = 'built-in-id';
const String _usbCamera = 'usb-id';
const Duration _fade = Duration(milliseconds: 600);
const Duration _step = Duration(milliseconds: 50);
const Duration _frame = Duration(milliseconds: 16);
const Duration _second = Duration(seconds: 1);

const Map<String, Object?> _cameraDevice = <String, Object?>{
  'deviceType': 0,
  'localizedName': 'FaceTime HD Camera',
  'manufacturer': 'Apple Inc.',
  'deviceId': _camera,
};

const Map<String, Object?> _usbCameraDevice = <String, Object?>{
  'deviceType': 0,
  'localizedName': 'USB Camera',
  'manufacturer': 'Logitech',
  'deviceId': _usbCamera,
};

const List<InputDevice> _inputs = <InputDevice>[
  InputDevice(id: 'a', label: 'MacBook Pro Microphone'),
  InputDevice(id: 'b', label: 'CORSAIR HS80 MAX'),
];

class _NativeCamera {
  final List<MethodCall> calls = <MethodCall>[];
  Duration? destroyDelay;
  bool secondCamera = false;

  List<String> get methods => <String>[
    for (final MethodCall call in calls) call.method,
  ];

  List<Object?> get initializedAudio => <Object?>[
    for (final MethodCall call in calls)
      if (call.method == 'initialize')
        (call.arguments as Map<Object?, Object?>)['audioDeviceId'],
  ];

  int get recordingsStarted => <String>[
    for (final String method in methods)
      if (method == 'startRecording') method,
  ].length;

  List<Map<String, Object?>> get _devices => <Map<String, Object?>>[
    _cameraDevice,
    if (secondCamera) _usbCameraDevice,
  ];

  Future<Object?> handle(MethodCall call) async {
    calls.add(call);
    switch (call.method) {
      case 'listDevices':
        return <String, Object?>{'devices': _devices};
      case 'initialize':
        return <String, Object?>{
          'textureId': 7,
          'size': <String, Object?>{'width': 1920.0, 'height': 1080.0},
          'devices': _devices,
        };
      case 'startRecording':
        return <String, Object?>{'error': null};
      case 'destroy':
        final Duration? delay = destroyDelay;
        if (delay != null) {
          await Future<void>.delayed(delay);
        }
        return true;
      default:
        return null;
    }
  }
}

class _LevelRecorder extends Fake implements AudioRecorder {
  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async =>
      const Stream<Uint8List>.empty();

  @override
  Future<String?> stop() async => null;

  @override
  Future<void> dispose() async {}
}

class _Output extends AudioOutput {
  _Output();

  @override
  Future<String?> defaultOutputName() async => 'MacBook Pro Speakers';

  @override
  Future<void> openSoundSettings() async {}
}

CameraMacOSController _suppliedController() =>
    CameraMacOSController(CameraMacOSArguments(size: const Size(1280, 720)));

CameraMacOSView _view(Widget? widget) => widget! as CameraMacOSView;

AppSettings _storedInput(String id) =>
    AppSettings.defaults.copyWith(audioInputId: id);

Matcher _micRefused() => throwsA(
  isA<VideoRecorderException>().having(
    (VideoRecorderException error) => error.message,
    'message',
    micPermissionMessage,
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 14; i++) {
    await tester.pump(_step);
  }
}

Future<void> _pass(WidgetTester tester, Duration time) async {
  final int steps = time.inMilliseconds ~/ _step.inMilliseconds;
  for (int i = 0; i < steps; i++) {
    await tester.pump(_step);
  }
}

Future<void> _showComposer(
  WidgetTester tester, {
  required FakeSettingsRepository settings,
  required CameraOffVoiceRecorder voice,
  Duration? listDelay,
}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final CameraMacosVideoRecorder recorder = CameraMacosVideoRecorder(
    microphonePermission: () async => true,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        videoRecorderProvider.overrideWith((Ref ref) => recorder),
        voiceRecorderProvider.overrideWith((Ref ref) => voice),
        captureServiceProvider.overrideWith((Ref ref) => FakeCaptureService()),
        settingsRepositoryProvider.overrideWithValue(settings),
        audioInputListerProvider.overrideWithValue(() async {
          final Duration? delay = listDelay;
          if (delay != null) {
            await Future<void>.delayed(delay);
          }
          return _inputs;
        }),
        inputLevelRecorderProvider.overrideWithValue(_LevelRecorder.new),
        audioOutputProvider.overrideWithValue(_Output()),
        reflectionPromptsOff(),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showVideoComposer(context, '2026-10-14'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(_fade);
  await _settle(tester);
}

VideoRecorderSheet _sheet(WidgetTester tester) =>
    tester.widget<VideoRecorderSheet>(find.byType(VideoRecorderSheet));

Future<void> _press(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pump();
  await tester.pump(_step);
}

Future<void> _openInputChoices(WidgetTester tester) async {
  await _press(tester, recorderInputKey);
  await _press(tester, inputDeviceRowKey);
}

Future<void> _closeComposer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(_second);
  debugDefaultTargetPlatformOverride = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _NativeCamera native;

  setUp(() {
    native = _NativeCamera();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_cameraChannel, native.handle);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_cameraChannel, null);
  });

  test('a macOS video take records from the chosen microphone', () async {
    final CameraMacosVideoRecorder recorder = CameraMacosVideoRecorder(
      controller: _suppliedController(),
      microphonePermission: () async => true,
    );
    const AudioInput input = AudioInput(id: 'b', label: 'CORSAIR HS80 MAX');

    recorder.useAudioInput(input.id);
    final CameraMacOSView view = _view(recorder.openSession(_camera));

    expect(view.enableAudio, isTrue);
    expect(view.audioDeviceId, 'b');
    expect(view.deviceId, _camera);

    await recorder.start();
    expect(native.methods, contains('startRecording'));
    await recorder.release();
  });

  test('a macOS video take with no choice records from the system default', () {
    final CameraMacosVideoRecorder recorder = CameraMacosVideoRecorder(
      microphonePermission: () async => true,
    );
    const AudioInput systemDefault = AudioInput(
      id: null,
      label: 'System default',
    );

    recorder.useAudioInput(systemDefault.id);
    final CameraMacOSView view = _view(recorder.openSession(_camera));

    expect(view.audioDeviceId, isNull);
    expect(view.enableAudio, isTrue);
  });

  test(
    'a refused microphone stops a macOS video take before it starts',
    () async {
      Future<bool> Function() check = () async => false;
      final CameraMacosVideoRecorder recorder = CameraMacosVideoRecorder(
        controller: _suppliedController(),
        microphonePermission: () => check(),
      );
      recorder.openSession(_camera);

      await expectLater(recorder.start(), _micRefused());

      check = () async => throw PlatformException(
        code: 'record',
        message: 'The microphone check failed.',
      );
      await expectLater(recorder.start(), _micRefused());

      expect(native.methods, isNot(contains('startRecording')));
      expect(recorder.elapsed, Duration.zero);
    },
  );

  test('changing the input while idle reopens the macOS camera view', () {
    final CameraMacosVideoRecorder recorder = CameraMacosVideoRecorder(
      microphonePermission: () async => true,
    );
    recorder.useAudioInput('a');
    final Widget? onA = recorder.openSession(_camera);
    expect(_view(onA).audioDeviceId, 'a');

    recorder.useAudioInput('b');
    final Widget? onB = recorder.openSession(_camera);

    expect(onB, isNot(same(onA)));
    expect(_view(onB).audioDeviceId, 'b');
    expect(_view(onB).enableAudio, isTrue);

    recorder.useAudioInput('b');
    expect(recorder.openSession(_camera), same(onB));
  });

  testWidgets(
    'an input chosen while the camera is off is used when it comes back on',
    (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final StreamController<AppSettings> stored =
          StreamController<AppSettings>.broadcast();
      addTearDown(stored.close);
      final CameraMacosVideoRecorder recorder = CameraMacosVideoRecorder(
        microphonePermission: () async => true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            videoRecorderProvider.overrideWith((Ref ref) => recorder),
            voiceRecorderProvider.overrideWith(
              (Ref ref) => CameraOffVoiceRecorder(),
            ),
            captureServiceProvider.overrideWith(
              (Ref ref) => FakeCaptureService(),
            ),
            appSettingsProvider.overrideWith((Ref ref) async* {
              yield _storedInput('a');
              yield* stored.stream;
            }),
            audioInputListerProvider.overrideWithValue(
              () async => const <InputDevice>[
                InputDevice(id: 'a', label: 'MacBook Pro Microphone'),
                InputDevice(id: 'b', label: 'CORSAIR HS80 MAX'),
              ],
            ),
            reflectionPromptsOff(),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: fieldNotesTheme(platform: TargetPlatform.macOS),
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) => TextButton(
                  onPressed: () => showVideoComposer(context, '2026-10-14'),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(_fade);
      await _settle(tester);

      expect(
        tester
            .widget<VideoRecorderSheet>(find.byType(VideoRecorderSheet))
            .phase,
        VideoRecorderPhase.idle,
      );
      expect(
        tester
            .widget<CameraMacOSView>(find.byType(CameraMacOSView))
            .audioDeviceId,
        'a',
      );

      await tester.tap(find.byKey(videoCameraKey));
      await tester.pump();
      await _settle(tester);
      expect(find.byType(CameraMacOSView), findsNothing);
      final int opened = native.initializedAudio.length;

      stored.add(_storedInput('b'));
      await tester.pump();
      await _settle(tester);

      expect(find.byType(CameraMacOSView), findsNothing);
      expect(native.initializedAudio, hasLength(opened));

      await tester.tap(find.byKey(videoCameraKey));
      await tester.pump();
      await _settle(tester);

      final CameraMacOSView view = tester.widget<CameraMacOSView>(
        find.byType(CameraMacOSView),
      );
      expect(view.audioDeviceId, 'b');
      expect(view.enableAudio, isTrue);
      expect(native.initializedAudio.last, 'b');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('the shutter is ignored while the camera turns back on', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository settings = FakeSettingsRepository(
      initial: _storedInput('a'),
    );
    final CameraOffVoiceRecorder voice = CameraOffVoiceRecorder();
    await _showComposer(
      tester,
      settings: settings,
      voice: voice,
      listDelay: const Duration(milliseconds: 120),
    );
    expect(_sheet(tester).phase, VideoRecorderPhase.idle);

    await tester.tap(find.byKey(videoCameraKey));
    await tester.pump();
    await _pass(tester, _second);
    expect(_sheet(tester).cameraOn, isFalse);
    expect(voice.calls, isEmpty);

    await settings.setAudioInputId('b');
    await tester.pump();
    await _pass(tester, _second);
    expect(voice.calls, isEmpty);

    await tester.tap(find.byKey(videoCameraKey));
    await tester.pump(_frame);
    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump();
    expect(voice.calls, isEmpty);
    await _pass(tester, _second);

    expect(voice.calls, isEmpty);
    expect(_sheet(tester).phase, VideoRecorderPhase.idle);
    expect(_sheet(tester).cameraOn, isTrue);
    expect(native.initializedAudio.last, 'b');
    expect(native.recordingsStarted, 0);

    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump();
    await _pass(tester, _second);

    expect(voice.calls, isEmpty);
    expect(_sheet(tester).phase, VideoRecorderPhase.recording);
    expect(native.recordingsStarted, 1);

    await _closeComposer(tester);
  });

  testWidgets(
    'choosing an input keeps the video input panel open while the camera reopens',
    (WidgetTester tester) async {
      final FakeSettingsRepository settings = FakeSettingsRepository(
        initial: _storedInput('a'),
      );
      native.destroyDelay = const Duration(milliseconds: 100);
      await _showComposer(
        tester,
        settings: settings,
        voice: CameraOffVoiceRecorder(),
      );
      final Finder panel = find.byType(InputPanel);
      final Finder button = find.byKey(recorderInputKey);
      await _openInputChoices(tester);
      expect(panel, findsOneWidget);

      await tester.tap(find.byKey(inputChoiceKey('b')));
      for (int frame = 0; frame < 13; frame++) {
        await tester.pump(_frame);
        expect(panel, findsOneWidget, reason: 'frame $frame');
        expect(button, findsOneWidget, reason: 'frame $frame');
        expect(
          _sheet(tester).phase,
          VideoRecorderPhase.idle,
          reason: 'frame $frame',
        );
      }
      await _pass(tester, _second);

      expect(panel, findsOneWidget);
      expect(button, findsOneWidget);
      expect(_sheet(tester).phase, VideoRecorderPhase.idle);
      expect(settings.audioInputIdWrites, <String?>['b']);
      expect(native.initializedAudio.last, 'b');

      await _press(tester, inputDeviceRowKey);
      await tester.tap(find.byKey(inputChoiceKey('a')));
      await tester.pump(_frame);
      expect(panel, findsOneWidget);
      await tester.tap(find.byKey(videoShutterKey));
      await tester.pump(const Duration(milliseconds: 24));
      expect(panel, findsNothing);
      expect(_sheet(tester).phase, VideoRecorderPhase.idle);
      await tester.tap(find.byKey(videoShutterKey));
      await tester.pump();
      expect(_sheet(tester).phase, VideoRecorderPhase.idle);
      await _pass(tester, _second);

      expect(panel, findsNothing);
      expect(_sheet(tester).phase, VideoRecorderPhase.idle);
      expect(native.recordingsStarted, 0);
      expect(native.initializedAudio.last, 'a');

      await tester.tap(find.byKey(videoShutterKey));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(videoShutterKey));
      await tester.pump();
      await _pass(tester, _second);

      expect(_sheet(tester).phase, VideoRecorderPhase.recording);
      expect(native.recordingsStarted, 1);

      await _closeComposer(tester);
    },
  );

  testWidgets(
    'leaving while the camera reopens for a chosen input opens no camera',
    (WidgetTester tester) async {
      native.destroyDelay = const Duration(milliseconds: 100);
      await _showComposer(
        tester,
        settings: FakeSettingsRepository(initial: _storedInput('a')),
        voice: CameraOffVoiceRecorder(),
      );
      await _openInputChoices(tester);
      final int opened = native.initializedAudio.length;

      await tester.tap(find.byKey(inputChoiceKey('b')));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.byKey(videoCloseKey));
      await tester.pump();
      await _pass(tester, _second);

      expect(find.byType(VideoRecorderSheet), findsNothing);
      expect(native.initializedAudio, hasLength(opened));

      await _closeComposer(tester);
    },
  );

  testWidgets(
    'opening Voice settings while the camera reopens for a chosen input opens no camera',
    (WidgetTester tester) async {
      native.destroyDelay = const Duration(milliseconds: 100);
      await _showComposer(
        tester,
        settings: FakeSettingsRepository(initial: _storedInput('a')),
        voice: CameraOffVoiceRecorder(),
      );
      await _openInputChoices(tester);
      final int opened = native.initializedAudio.length;

      await tester.tap(find.byKey(inputChoiceKey('b')));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.byKey(voiceSettingsRowKey));
      await tester.pump();
      await _pass(tester, _second);

      expect(find.byType(VideoRecorderSheet), findsNothing);
      expect(native.initializedAudio, hasLength(opened));

      await _closeComposer(tester);
    },
  );

  testWidgets('leaving during a camera switch opens no camera', (
    WidgetTester tester,
  ) async {
    native
      ..secondCamera = true
      ..destroyDelay = const Duration(milliseconds: 100);
    await _showComposer(
      tester,
      settings: FakeSettingsRepository(initial: _storedInput('a')),
      voice: CameraOffVoiceRecorder(),
    );
    expect(_sheet(tester).phase, VideoRecorderPhase.idle);
    expect(_sheet(tester).selectedDeviceId, _camera);
    final int opened = native.initializedAudio.length;

    _sheet(tester).onDeviceChanged!(_usbCamera);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.tap(find.byKey(videoCloseKey));
    await tester.pump();
    await _pass(tester, _second);

    expect(find.byType(VideoRecorderSheet), findsNothing);
    expect(native.initializedAudio, hasLength(opened));

    await _closeComposer(tester);
  });
}
