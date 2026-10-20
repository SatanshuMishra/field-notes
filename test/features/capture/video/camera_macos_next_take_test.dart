import 'dart:io';

import 'package:camera_macos/camera_macos.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../audio/live_audio_test_support.dart';
import 'video_test_support.dart';

const Duration _firstTake = Duration(milliseconds: 600);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  int moviesWritten = 0;

  setUp(() {
    root = Directory.systemTemp.createTempSync('camera_macos_next_take_');
    moviesWritten = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraMacosChannel, (MethodCall call) async {
          switch (call.method) {
            case 'startRecording':
              return <String, Object?>{'started': true, 'error': null};
            case 'stopRecording':
              moviesWritten += 1;
              final Directory folder = Directory(p.join(root.path, 'camera'))
                ..createSync(recursive: true);
              final String movie = p.join(
                folder.path,
                'take_$moviesWritten.mp4',
              );
              File(movie).writeAsBytesSync(const <int>[0, 0, 0, 24]);
              return <String, Object?>{'url': movie, 'videoData': null};
            case 'destroy':
              return true;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraMacosChannel, null);
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  test('the next macOS take reads zero until its movie starts, not the last '
      "take's time", () async {
    final FakeLiveAudio liveAudio = FakeLiveAudio();
    final FakeMicrophone mic = FakeMicrophone();
    final CameraMacosVideoRecorder recorder = CameraMacosVideoRecorder(
      temporaryDirectory: () async => Directory(p.join(root.path, 'tmp')),
      controller: CameraMacOSController(
        CameraMacOSArguments(size: const Size(1280, 720)),
      ),
      microphonePermission: () async => true,
      encoder: liveAudio,
      audioJoiner: liveAudio,
      audioRecorderFactory: () => mic,
      chainRunner: passThroughChain,
    );
    recorder.openSession('cam-0');

    await recorder.start();
    await sendMacMovieStart();
    await Future<void>.delayed(_firstTake);
    final VideoRecording first = await recorder.stop();
    expect(first.durationMs, greaterThanOrEqualTo(_firstTake.inMilliseconds));

    await recorder.start();
    final Duration beforeMovieStart = recorder.elapsed;
    final VideoRecording second = await recorder.stop();

    expect(beforeMovieStart, Duration.zero);
    expect(second.durationMs, 0);
    await recorder.releaseSaved(first);
    await recorder.releaseSaved(second);
  });
}
