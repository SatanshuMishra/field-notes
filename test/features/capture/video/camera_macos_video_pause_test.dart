import 'dart:io';

import 'package:camera_macos/camera_macos.dart';
import 'package:fake_async/fake_async.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../audio/live_audio_test_support.dart';

const MethodChannel _cameraChannel = MethodChannel('camera_macos');
const Duration _fileWorkWait = Duration(milliseconds: 5);
const int _fileWorkTurns = 40;

class _NativeCamera {
  final List<String> methods = <String>[];
  final List<Object? Function()> pauseReplies = <Object? Function()>[];
  final List<Object? Function()> resumeReplies = <Object? Function()>[];

  Future<Object?> handle(MethodCall call) async {
    methods.add(call.method);
    switch (call.method) {
      case 'startRecording':
        return <String, Object?>{'error': null};
      case 'pauseRecording':
        return pauseReplies.removeAt(0)();
      case 'resumeRecording':
        return resumeReplies.removeAt(0)();
      case 'destroy':
        return true;
      default:
        return null;
    }
  }
}

void _sendMovieStart(FakeAsync async) {
  async.run((FakeAsync _) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          _cameraChannel.name,
          _cameraChannel.codec.encodeMethodCall(
            const MethodCall('onVideoRecordingStarted'),
          ),
          (ByteData? _) {},
        );
  });
  async.flushMicrotasks();
}

Future<CameraMacosVideoRecorder> _startedRecorder(
  FakeAsync async,
  Directory root, {
  bool movieBegins = true,
}) async {
  final FakeLiveAudio liveAudio = FakeLiveAudio();
  final FakeMicrophone mic = FakeMicrophone();
  late final CameraMacosVideoRecorder recorder;
  bool started = false;
  async.run((FakeAsync async) {
    recorder = CameraMacosVideoRecorder(
      temporaryDirectory: () async => root,
      controller: CameraMacOSController(
        CameraMacOSArguments(size: const Size(1280, 720)),
      ),
      microphonePermission: () async => true,
      encoder: liveAudio,
      audioJoiner: liveAudio,
      audioRecorderFactory: () => mic,
      chainRunner: passThroughChain,
    );
    recorder.openSession('built-in-id');
    recorder.start().then((_) => started = true);
  });
  for (int turn = 0; turn < _fileWorkTurns && !started; turn += 1) {
    await Future<void>.delayed(_fileWorkWait);
    async.flushMicrotasks();
  }
  expect(started, isTrue);
  expect(mic.startStreamConfigs, hasLength(1));
  if (movieBegins) {
    _sendMovieStart(async);
  }
  return recorder;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _NativeCamera native;
  late Directory root;

  setUp(() {
    native = _NativeCamera();
    root = Directory.systemTemp.createTempSync('camera_macos_video_pause_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_cameraChannel, native.handle);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_cameraChannel, null);
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  test('a macOS take pauses and resumes the movie recording', () async {
    final FakeAsync async = FakeAsync();
    native.pauseReplies.add(() => true);
    native.resumeReplies.add(() => true);
    final CameraMacosVideoRecorder recorder = await _startedRecorder(
      async,
      root,
    );
    async.run((FakeAsync async) {
      expect(native.methods, contains('startRecording'));
      expect(recorder.supportsPause, isTrue);

      async.elapse(const Duration(seconds: 1));
      expect(recorder.elapsed, const Duration(seconds: 1));

      Object? pauseError;
      recorder.pause().catchError((Object error) {
        pauseError = error;
      });
      async.flushMicrotasks();
      expect(pauseError, isNull);
      expect(native.methods, contains('pauseRecording'));
      expect(recorder.elapsed, const Duration(seconds: 1));

      async.elapse(const Duration(milliseconds: 200));
      expect(recorder.elapsed, const Duration(seconds: 1));

      Object? resumeError;
      recorder.resume().catchError((Object error) {
        resumeError = error;
      });
      async.flushMicrotasks();
      expect(resumeError, isNull);
      expect(native.methods, contains('resumeRecording'));

      async.elapse(const Duration(milliseconds: 300));
      expect(recorder.elapsed, const Duration(milliseconds: 1300));
    });
  });

  test('a refused macOS pause leaves the take recording', () async {
    final FakeAsync async = FakeAsync();
    native.pauseReplies
      ..add(
        () => throw PlatformException(
          code: 'PAUSE_FAILED',
          message: 'The movie output refused to pause',
        ),
      )
      ..add(() => null);
    final CameraMacosVideoRecorder recorder = await _startedRecorder(
      async,
      root,
    );
    async.run((FakeAsync async) {
      async.elapse(const Duration(seconds: 1));

      Object? firstError;
      recorder.pause().catchError((Object error) {
        firstError = error;
      });
      async.flushMicrotasks();
      expect(firstError, isA<VideoRecorderException>());
      expect(
        (firstError! as VideoRecorderException).message,
        videoPauseMessage,
      );

      async.elapse(const Duration(milliseconds: 500));
      expect(recorder.elapsed, const Duration(milliseconds: 1500));

      Object? secondError;
      recorder.pause().catchError((Object error) {
        secondError = error;
      });
      async.flushMicrotasks();
      expect(secondError, isA<VideoRecorderException>());
      expect(
        (secondError! as VideoRecorderException).message,
        videoPauseMessage,
      );

      async.elapse(const Duration(milliseconds: 500));
      expect(recorder.elapsed, const Duration(seconds: 2));
      expect(
        native.methods.where((String method) => method == 'pauseRecording'),
        hasLength(2),
      );
    });
  });

  test(
    'a macOS take paused before the movie starts keeps its clock still until '
    'resumed',
    () async {
      final FakeAsync async = FakeAsync();
      native.pauseReplies.add(() => true);
      native.resumeReplies.add(() => true);
      final CameraMacosVideoRecorder recorder = await _startedRecorder(
        async,
        root,
        movieBegins: false,
      );
      async.run((FakeAsync async) {
        recorder.pause();
        async.flushMicrotasks();
      });
      _sendMovieStart(async);
      async.run((FakeAsync async) {
        async.elapse(const Duration(seconds: 1));
        expect(recorder.elapsed, Duration.zero);

        recorder.resume();
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 300));
        expect(recorder.elapsed, const Duration(milliseconds: 300));
      });
    },
  );

  test('a macOS take paused before the movie starts keeps its clock still past '
      'the movie-start fallback', () async {
    final FakeAsync async = FakeAsync();
    native.pauseReplies.add(() => true);
    native.resumeReplies.add(() => true);
    final CameraMacosVideoRecorder recorder = await _startedRecorder(
      async,
      root,
      movieBegins: false,
    );
    async.run((FakeAsync async) {
      recorder.pause();
      async.flushMicrotasks();
      async.elapse(movieStartTimeout + const Duration(seconds: 1));
      expect(recorder.elapsed, Duration.zero);

      recorder.resume();
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 300));
      expect(recorder.elapsed, const Duration(milliseconds: 300));
    });
  });
}
