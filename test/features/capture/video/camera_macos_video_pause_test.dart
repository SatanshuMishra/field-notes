import 'dart:async';

import 'package:camera_macos/camera_macos.dart';
import 'package:fake_async/fake_async.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _cameraChannel = MethodChannel('camera_macos');

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

CameraMacosVideoRecorder _startedRecorder(FakeAsync async) {
  final CameraMacosVideoRecorder recorder = CameraMacosVideoRecorder(
    controller: CameraMacOSController(
      CameraMacOSArguments(size: const Size(1280, 720)),
    ),
    microphonePermission: () async => true,
  );
  recorder.openSession('built-in-id');
  unawaited(recorder.start());
  async.flushMicrotasks();
  return recorder;
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

  test('a macOS take pauses and resumes the movie recording', () {
    fakeAsync((FakeAsync async) {
      native.pauseReplies.add(() => true);
      native.resumeReplies.add(() => true);
      final CameraMacosVideoRecorder recorder = _startedRecorder(async);
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

  test('a refused macOS pause leaves the take recording', () {
    fakeAsync((FakeAsync async) {
      native.pauseReplies
        ..add(
          () => throw PlatformException(
            code: 'PAUSE_FAILED',
            message: 'The movie output refused to pause',
          ),
        )
        ..add(() => null);
      final CameraMacosVideoRecorder recorder = _startedRecorder(async);

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
}
