import 'dart:io';
import 'dart:typed_data';

import 'package:camera_macos/camera_macos.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../audio/live_audio_test_support.dart';
import 'video_test_support.dart' show cameraMacosChannel, sendMacMovieStart;

const String _cameraName = 'cam-0';
const List<int> _pictureBytes = <int>[0, 0, 0, 24];
const int _sampleRate = 48000;
const int _firstChunkSamples = 3040;
const Duration _quietMicrophoneTake = Duration(milliseconds: 1500);
const Duration _soundAllowedShortOfPicture = Duration(milliseconds: 500);
const Duration _firstFrameAge = Duration(milliseconds: 90);
const int _firstFrameAgeSamples = 4320;

class _MacBench {
  _MacBench(this.root);

  final Directory root;
  final FakeLiveAudio liveAudio = FakeLiveAudio();
  final FakeMicrophone mic = FakeMicrophone();
  final Stopwatch _running = Stopwatch()..start();
  Duration _skipped = Duration.zero;
  int _written = 0;

  Duration now() => _running.elapsed + _skipped;

  void skip(Duration time) => _skipped += time;

  Directory get temporary => Directory(p.join(root.path, 'tmp'));

  Future<Object?> cameraMacos(MethodCall call) async {
    switch (call.method) {
      case 'startRecording':
        return <String, Object?>{'started': true, 'error': null};
      case 'stopRecording':
        _written += 1;
        final Directory folder = Directory(p.join(root.path, 'camera'))
          ..createSync(recursive: true);
        final String movie = p.join(folder.path, 'take_$_written.mp4');
        File(movie).writeAsBytesSync(_pictureBytes);
        return <String, Object?>{'url': movie, 'videoData': null};
      case 'destroy':
        return true;
    }
    return null;
  }

  CameraMacosVideoRecorder recorder() {
    final CameraMacosVideoRecorder recorder = CameraMacosVideoRecorder(
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
    )..useAudioInput('b');
    recorder.openSession(_cameraName);
    return recorder;
  }
}

Duration _soundWritten(FakeLiveAudio liveAudio) => Duration(
  microseconds:
      liveAudio.samplesAppended * Duration.microsecondsPerSecond ~/ _sampleRate,
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

int _leadingSilentSamples(FakeLiveAudio liveAudio) {
  int silent = 0;
  for (final Uint8List pcm in liveAudio.appended) {
    final ByteData samples = ByteData.sublistView(pcm);
    for (int offset = 0; offset + 1 < pcm.lengthInBytes; offset += 2) {
      if (samples.getInt16(offset, Endian.little) != 0) {
        return silent;
      }
      silent += 1;
    }
  }
  return silent;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late _MacBench bench;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mac_video_sound_repro_');
    bench = _MacBench(root);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraMacosChannel, bench.cameraMacos);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraMacosChannel, null);
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  test('a take whose microphone goes quiet after its first chunk keeps sound '
      'for the whole picture', () async {
    final VideoRecorder recorder = bench.recorder();
    await recorder.start();
    await sendMacMovieStart();
    bench.mic.push(silentPcm(_firstChunkSamples));
    await _settle();

    await Future<void>.delayed(_quietMicrophoneTake);
    final VideoRecording take = await recorder.stop();

    expect(
      bench.mic.startStreamConfigs.length,
      greaterThan(1),
      reason: 'the microphone went quiet mid-take and was never reopened',
    );
    expect(
      _soundWritten(bench.liveAudio),
      greaterThanOrEqualTo(
        Duration(milliseconds: take.durationMs) - _soundAllowedShortOfPicture,
      ),
      reason: 'the saved take holds sound for only part of its picture',
    );

    await recorder.releaseSaved(take);
  });

  test(
    'sound heard before the movie has begun is not written to the take',
    () async {
      final VideoRecorder recorder = bench.recorder();
      await recorder.start();
      bench.mic.push(silentPcm(_sampleRate));
      await _settle();

      await sendMacMovieStart();
      bench.skip(const Duration(seconds: 2));
      bench.mic.push(silentPcm(_sampleRate * 2));
      await _settle();
      final VideoRecording take = await recorder.stop();

      expect(
        _soundWritten(bench.liveAudio),
        const Duration(seconds: 2),
        reason:
            'the second of sound before the movie began leads the take, '
            'so the sound lags the picture',
      );

      await recorder.releaseSaved(take);
    },
  );

  test('sound lines up with the first frame the camera captured before it '
      'reported the movie start', () async {
    final VideoRecorder recorder = bench.recorder();
    await recorder.start();
    await sendMacMovieStart(firstFrameAge: _firstFrameAge);
    bench.skip(const Duration(seconds: 1));
    bench.mic.push(pcmAtDbfs(-20, samples: _sampleRate));
    await _settle();
    final VideoRecording take = await recorder.stop();

    expect(
      _leadingSilentSamples(bench.liveAudio),
      _firstFrameAgeSamples,
      reason:
          'the sound starts where the camera reported the movie, after its '
          'first frame, so the sound plays ahead of the picture',
    );
    expect(
      _soundWritten(bench.liveAudio),
      const Duration(seconds: 1) + _firstFrameAge,
    );

    await recorder.releaseSaved(take);
  });
}
