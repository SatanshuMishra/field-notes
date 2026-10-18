import 'dart:async';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:fake_async/fake_async.dart';
import 'package:field_notes/data/media/video_join.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../audio/live_audio_test_support.dart';

const String _usbCamera = r'USB Camera <\\?\usb#vid_046d>';
const Key _platformPreviewKey = ValueKey<String>('windows-platform-preview');
final RegExp _segmentName = RegExp(r'^video_segment_\d+\.mp4$');
final RegExp _joinName = RegExp(r'^video_join_\d+\.mp4$');
final RegExp _keptName = RegExp(r'^video_\d+\.mp4$');

typedef _StopReply = Future<XFile> Function(
  _FakeWindowsCamera camera,
  int cameraId,
);

Future<XFile> _withData(_FakeWindowsCamera camera, int cameraId) async =>
    XFile(camera.movie(camera.nextMovieBytes()));

Future<XFile> _emptyFile(_FakeWindowsCamera camera, int cameraId) async =>
    XFile(camera.movie(const <int>[]));

Future<XFile> _missingFile(_FakeWindowsCamera camera, int cameraId) async =>
    XFile(camera.missing());

Future<XFile> _throws(_FakeWindowsCamera camera, int cameraId) async =>
    throw CameraException('stop', 'The camera went away.');

Future<XFile> _untilDisposed(_FakeWindowsCamera camera, int cameraId) =>
    camera.hold(cameraId);

_StopReply _after(Duration delay, _StopReply reply) =>
    (_FakeWindowsCamera camera, int cameraId) async {
      await Future<void>.delayed(delay);
      return reply(camera, cameraId);
    };

class _FakeWindowsCamera extends CameraPlatform {
  _FakeWindowsCamera({required this.root});

  final String root;
  final List<int> created = <int>[];
  final Map<int, List<String>> calls = <int, List<String>>{};
  final List<_StopReply> stopReplies = <_StopReply>[];
  final List<String> stopPaths = <String>[];
  final List<List<int>> stopBytes = <List<int>>[];
  final List<List<int>> stillBytes = <List<int>>[];
  final Map<int, List<Completer<XFile>>> _held =
      <int, List<Completer<XFile>>>{};
  final StreamController<CameraInitializedEvent> _initialized =
      StreamController<CameraInitializedEvent>.broadcast();
  final StreamController<CameraErrorEvent> _errors =
      StreamController<CameraErrorEvent>.broadcast();
  int _nextCamera = 0;
  int _written = 0;

  String get videos => p.join(root, 'Videos');

  String get pictures => p.join(root, 'Pictures');

  int get lastCamera => created.last;

  int count(int cameraId, String call) => (calls[cameraId] ?? const <String>[])
      .where((String logged) => logged == call)
      .length;

  void _log(int cameraId, String call) =>
      calls.putIfAbsent(cameraId, () => <String>[]).add(call);

  List<int> nextMovieBytes() => <int>[0, 0, 0, 24, stopBytes.length + 1];

  String movie(List<int> bytes) {
    final String path = _write(videos, 'mp4', bytes);
    stopPaths.add(path);
    stopBytes.add(bytes);
    return path;
  }

  String missing() {
    final String path = p.join(videos, 'Missing${stopPaths.length + 1}.mp4');
    stopPaths.add(path);
    stopBytes.add(const <int>[]);
    return path;
  }

  Future<XFile> hold(int cameraId) {
    final Completer<XFile> held = Completer<XFile>();
    _held.putIfAbsent(cameraId, () => <Completer<XFile>>[]).add(held);
    return held.future;
  }

  @override
  Future<List<CameraDescription>> availableCameras() async =>
      const <CameraDescription>[
        CameraDescription(
          name: _usbCamera,
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 0,
        ),
      ];

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async {
    _nextCamera += 1;
    created.add(_nextCamera);
    _log(_nextCamera, 'create');
    return _nextCamera;
  }

  @override
  Future<int> createCamera(
    CameraDescription cameraDescription,
    ResolutionPreset? resolutionPreset, {
    bool enableAudio = false,
  }) => createCameraWithSettings(
    cameraDescription,
    MediaSettings(resolutionPreset: resolutionPreset, enableAudio: enableAudio),
  );

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    scheduleMicrotask(
      () => _initialized.add(
        CameraInitializedEvent(
          cameraId,
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
      _initialized.stream.where(
        (CameraInitializedEvent event) => event.cameraId == cameraId,
      );

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _errors.stream.where(
    (CameraErrorEvent event) => event.cameraId == cameraId,
  );

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream<DeviceOrientationChangedEvent>.empty();

  @override
  Future<void> startVideoCapturing(VideoCaptureOptions options) async =>
      _log(options.cameraId, 'start');

  @override
  Future<void> startVideoRecording(
    int cameraId, {
    Duration? maxVideoDuration,
  }) async => _log(cameraId, 'start');

  @override
  Future<XFile> takePicture(int cameraId) async {
    final List<int> bytes = <int>[0xFF, 0xD8, stillBytes.length + 1, 0xFF];
    stillBytes.add(bytes);
    return XFile(_write(pictures, 'jpg', bytes));
  }

  @override
  Future<XFile> stopVideoRecording(int cameraId) {
    _log(cameraId, 'stop');
    final _StopReply reply = stopReplies.isEmpty
        ? _withData
        : stopReplies.removeAt(0);
    return reply(this, cameraId);
  }

  @override
  Future<void> dispose(int cameraId) async {
    _log(cameraId, 'dispose');
    for (final Completer<XFile> held
        in _held.remove(cameraId) ?? const <Completer<XFile>>[]) {
      held.completeError(
        CameraException('plugin_disposed', 'The camera was disposed.'),
      );
    }
  }

  @override
  Widget buildPreview(int cameraId) => const SizedBox(key: _platformPreviewKey);

  String _write(String folder, String extension, List<int> bytes) {
    _written += 1;
    Directory(folder).createSync(recursive: true);
    final String path = p.join(folder, 'WindowsCapture$_written.$extension');
    File(path).writeAsBytesSync(bytes);
    return path;
  }
}

class _JoinCall {
  const _JoinCall(this.segments, this.contents, this.output);

  final List<String> segments;
  final List<List<int>> contents;
  final String output;
}

typedef _JoinPlan = Future<File> Function(List<String> segments, String output);

class _FakeJoiner extends VideoJoiner {
  _FakeJoiner();

  final List<_JoinCall> calls = <_JoinCall>[];
  final List<_JoinPlan> plans = <_JoinPlan>[];

  @override
  Future<File> join(List<String> segments, String output) async {
    calls.add(
      _JoinCall(List<String>.of(segments), <List<int>>[
        for (final String segment in segments) File(segment).readAsBytesSync(),
      ], output),
    );
    if (plans.isNotEmpty) {
      return plans.removeAt(0)(segments, output);
    }
    File(output).writeAsBytesSync(const <int>[7, 7, 7]);
    return File(output);
  }
}

class _Outcome<T> {
  _Outcome(Future<T> future) {
    future.then(
      (T value) {
        _value = value;
        done = true;
      },
      onError: (Object failure) {
        error = failure;
        done = true;
      },
    );
  }

  bool done = false;
  T? _value;
  Object? error;

  T get value {
    expect(error, isNull);
    expect(done, isTrue);
    return _value as T;
  }
}

class _Time {
  final FakeAsync fake = FakeAsync();
  final List<Object> escaped = <Object>[];
  late final Zone _zone = runZonedGuarded<Zone>(
    () => Zone.current,
    (Object error, StackTrace stackTrace) => escaped.add(error),
  )!;

  T run<T>(T Function() body) =>
      _zone.run(() => fake.run((FakeAsync _) => body()));

  Future<void> turn() async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    fake.flushMicrotasks();
  }

  Future<void> settle() async {
    for (int index = 0; index < 40; index += 1) {
      await turn();
    }
  }

  Future<void> until(bool Function() condition) async {
    for (int index = 0; index < 4000 && !condition(); index += 1) {
      await turn();
    }
    expect(condition(), isTrue, reason: 'the recorder never got there');
  }

  Future<void> elapse(Duration duration) async {
    fake.elapse(duration);
    await settle();
  }

  _Outcome<T> begin<T>(Future<T> Function() action) =>
      run(() => _Outcome<T>(action()));

  Future<_Outcome<T>> finish<T>(Future<T> Function() action) async {
    final _Outcome<T> outcome = begin(action);
    await until(() => outcome.done);
    return outcome;
  }
}

File _captureFile(CaptureMedia? media) => (media! as CaptureFile).file;

Matcher _keptWith(String message) => isA<VideoSegmentsKeptException>().having(
  (VideoSegmentsKeptException error) => error.message,
  'message',
  message,
);

Matcher _stopFailure() => allOf(
  isA<VideoRecorderException>().having(
    (VideoRecorderException error) => error.message,
    'message',
    videoStopMessage,
  ),
  isNot(isA<VideoSegmentsKeptException>()),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory temporary;
  late CameraPlatform original;
  late _FakeWindowsCamera camera;
  late _FakeJoiner joiner;
  late FakeMicrophone mic;
  late FakeLiveAudio liveAudio;
  late _Time time;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('windows_video_pause_');
    temporary = Directory(p.join(root.path, 'Temp'));
    original = CameraPlatform.instance;
    camera = _FakeWindowsCamera(root: root.path);
    CameraPlatform.instance = camera;
    joiner = _FakeJoiner();
    mic = FakeMicrophone();
    liveAudio = FakeLiveAudio();
    time = _Time();
  });

  tearDown(() async {
    expect(time.escaped, isEmpty);
    CameraPlatform.instance = original;
    await root.delete(recursive: true);
  });

  String captures() => p.join(temporary.path, 'captures');

  Set<String> captureFiles() {
    final Directory folder = Directory(captures());
    if (!folder.existsSync()) {
      return <String>{};
    }
    return <String>{
      for (final FileSystemEntity entity in folder.listSync())
        if (entity is File) entity.path,
    };
  }

  Set<String> segmentFiles() => <String>{
    for (final String path in captureFiles())
      if (_segmentName.hasMatch(p.basename(path))) path,
  };

  CameraWindowsVideoRecorder newRecorder() => time.run(
    () => CameraWindowsVideoRecorder(
      temporaryDirectory: () async => temporary,
      joiner: joiner,
      encoder: liveAudio,
      audioJoiner: liveAudio,
      audioRecorderFactory: () => mic,
      chainRunner: passThroughChain,
    ),
  );

  FakeSoundJoin soundJoinOf(VideoRecording recording) {
    final String kept = _captureFile(recording.media).path;
    return liveAudio.joins.singleWhere(
      (FakeSoundJoin join) => join.output == kept,
    );
  }

  Future<void> startTake(CameraWindowsVideoRecorder recorder) async {
    time.run(() => recorder.openSession(_usbCamera));
    final _Outcome<void> started = await time.finish(recorder.start);
    expect(started.error, isNull);
  }

  Future<String> pauseKeeping(CameraWindowsVideoRecorder recorder) async {
    final Set<String> before = segmentFiles();
    final _Outcome<void> paused = await time.finish(recorder.pause);
    expect(paused.error, isNull);
    final Set<String> added = segmentFiles().difference(before);
    expect(added, hasLength(1));
    return added.single;
  }

  test(
    'a paused Windows take records segments and joins them on Keep',
    () async {
      final CameraWindowsVideoRecorder recorder = newRecorder();
      await startTake(recorder);
      final int cameraId = camera.lastCamera;
      expect(camera.count(cameraId, 'start'), 1);

      await time.elapse(const Duration(seconds: 3));
      expect((await time.finish(recorder.pause)).error, isNull);
      expect(camera.count(cameraId, 'stop'), 1);
      expect(camera.stillBytes, hasLength(1));

      expect((await time.finish(recorder.resume)).error, isNull);
      expect(camera.count(cameraId, 'start'), 2);

      await time.elapse(const Duration(seconds: 2));
      final VideoRecording recording = (await time.finish(recorder.stop)).value;

      expect(camera.count(cameraId, 'stop'), 2);
      expect(joiner.calls, hasLength(1));
      final _JoinCall join = joiner.calls.single;
      expect(join.segments, hasLength(2));
      for (final String segment in join.segments) {
        expect(p.dirname(segment), captures());
        expect(p.basename(segment), matches(_segmentName));
      }
      expect(join.contents, <List<int>>[
        camera.stopBytes[0],
        camera.stopBytes[1],
      ]);
      expect(p.dirname(join.output), captures());
      expect(p.basename(join.output), matches(_joinName));
      expect(soundJoinOf(recording).video, join.output);
      expect(soundJoinOf(recording).audio, liveAudio.soundPath);
      expect(_captureFile(recording.media).readAsBytesSync(), fakeJoinedBytes);
      expect(File(join.output).existsSync(), isFalse);
      expect(recording.media.mime, videoRecordingMime);
      expect(recording.durationMs, 5000);
      expect(
        _captureFile(recording.thumbnail).readAsBytesSync(),
        camera.stillBytes.single,
      );
      for (final String segment in join.segments) {
        expect(File(segment).existsSync(), isFalse);
      }
    },
  );

  test('a Windows take that never paused is saved without a join', () async {
    final CameraWindowsVideoRecorder recorder = newRecorder();
    await startTake(recorder);
    await time.elapse(const Duration(seconds: 2));

    final VideoRecording recording = (await time.finish(recorder.stop)).value;

    expect(joiner.calls, isEmpty);
    expect(camera.stopPaths, hasLength(1));
    final File movie = _captureFile(recording.media);
    expect(soundJoinOf(recording).videoBytes, camera.stopBytes.single);
    expect(p.dirname(soundJoinOf(recording).video), captures());
    expect(p.dirname(movie.path), captures());
    expect(File(camera.stopPaths.single).existsSync(), isFalse);
    expect(recording.durationMs, 2000);
  });

  test("a Windows take that never paused keeps today's stop", () async {
    final CameraWindowsVideoRecorder recorder = newRecorder();

    await startTake(recorder);
    await time.elapse(const Duration(seconds: 20));
    camera.stopReplies.add(_throws);
    expect((await time.finish(recorder.stop)).error, _stopFailure());

    await startTake(recorder);
    await time.elapse(const Duration(seconds: 20));
    camera.stopReplies.add(_after(const Duration(seconds: 30), _withData));
    final _Outcome<VideoRecording> slow = time.begin(recorder.stop);
    await time.settle();
    await time.elapse(const Duration(seconds: 15));
    expect(slow.done, isFalse);
    await time.elapse(const Duration(seconds: 15));
    await time.until(() => slow.done);
    expect(soundJoinOf(slow.value).videoBytes, camera.stopBytes.last);
    expect(joiner.calls, isEmpty);

    await startTake(recorder);
    await time.elapse(const Duration(seconds: 20));
    camera.stopReplies.add(_missingFile);
    expect((await time.finish(recorder.stop)).error, _stopFailure());
  });

  test(
    'a take kept while paused with no segment saves nothing and can go on',
    () async {
      final CameraWindowsVideoRecorder recorder = newRecorder();
      await startTake(recorder);
      final int firstCamera = camera.lastCamera;
      camera.stopReplies.add(_emptyFile);
      expect((await time.finish(recorder.pause)).error, isNull);

      expect((await time.finish(recorder.stop)).error, _stopFailure());
      expect(joiner.calls, isEmpty);
      expect(camera.count(firstCamera, 'stop'), 1);

      time.run(() => recorder.openSession(_usbCamera));
      expect((await time.finish(recorder.resume)).error, isNull);
      final int secondCamera = camera.lastCamera;
      expect(secondCamera, isNot(firstCamera));
      expect(camera.count(secondCamera, 'start'), 1);

      await time.elapse(const Duration(seconds: 5));
      final VideoRecording recording = (await time.finish(recorder.stop)).value;

      expect(joiner.calls, isEmpty);
      expect(recording.durationMs, 5000);
      expect(soundJoinOf(recording).videoBytes, camera.stopBytes.last);
    },
  );

  test(
    'a Windows take kept while paused is not stopped again, and the next take '
    'starts afresh',
    () async {
      final CameraWindowsVideoRecorder recorder = newRecorder();

      await startTake(recorder);
      final int firstCamera = camera.lastCamera;
      await time.elapse(const Duration(seconds: 2));
      await pauseKeeping(recorder);
      final VideoRecording first = (await time.finish(recorder.stop)).value;

      expect(camera.count(firstCamera, 'stop'), 1);
      expect(joiner.calls, isEmpty);
      expect(soundJoinOf(first).videoBytes, camera.stopBytes.single);
      expect(
        _captureFile(first.thumbnail).readAsBytesSync(),
        camera.stillBytes.single,
      );

      await startTake(recorder);
      final int secondCamera = camera.lastCamera;
      await time.elapse(const Duration(seconds: 1));
      await pauseKeeping(recorder);
      expect((await time.finish(recorder.resume)).error, isNull);
      await time.elapse(const Duration(seconds: 1));
      await pauseKeeping(recorder);
      final VideoRecording second = (await time.finish(recorder.stop)).value;

      expect(camera.count(secondCamera, 'stop'), 2);
      expect(joiner.calls, hasLength(1));
      expect(joiner.calls.single.contents, <List<int>>[
        camera.stopBytes[1],
        camera.stopBytes[2],
      ]);
      expect(camera.stillBytes, hasLength(2));
      expect(
        _captureFile(second.thumbnail).readAsBytesSync(),
        camera.stillBytes[1],
      );
      expect(
        _captureFile(second.thumbnail).readAsBytesSync(),
        isNot(camera.stillBytes[0]),
      );
      expect(_captureFile(first.media).existsSync(), isTrue);
    },
  );

  test(
    'a pause whose stretch file is missing or empty keeps no segment',
    () async {
      final CameraWindowsVideoRecorder recorder = newRecorder();
      camera.stopReplies.addAll(<_StopReply>[
        _emptyFile,
        _withData,
        _missingFile,
      ]);
      await startTake(recorder);

      await time.elapse(const Duration(seconds: 5));
      expect((await time.finish(recorder.pause)).error, isNull);
      final String empty = camera.stopPaths[0];

      expect((await time.finish(recorder.resume)).error, isNull);
      await time.elapse(const Duration(seconds: 7));
      expect((await time.finish(recorder.pause)).error, isNull);

      expect((await time.finish(recorder.resume)).error, isNull);
      await time.elapse(const Duration(seconds: 3));
      expect((await time.finish(recorder.pause)).error, isNull);

      expect(time.run(() => recorder.elapsed), const Duration(seconds: 7));

      final VideoRecording recording = (await time.finish(recorder.stop)).value;

      expect(joiner.calls, isEmpty);
      expect(soundJoinOf(recording).videoBytes, camera.stopBytes[1]);
      expect(recording.durationMs, 7000);
      expect(File(empty).existsSync(), isFalse);
    },
  );

  test('a failed join keeps the segments for a second Keep, and a failed '
      'sound join keeps the joined picture for a third', () async {
    final CameraWindowsVideoRecorder recorder = newRecorder();
    joiner.plans.add(
      (List<String> segments, String output) async =>
          throw const VideoJoinException('the parts would not join'),
    );
    await startTake(recorder);
    final int cameraId = camera.lastCamera;
    await time.elapse(const Duration(seconds: 2));
    await pauseKeeping(recorder);
    expect((await time.finish(recorder.resume)).error, isNull);
    await time.elapse(const Duration(seconds: 2));

    expect(
      (await time.finish(recorder.stop)).error,
      _keptWith(videoJoinMessage),
    );
    final _JoinCall failed = joiner.calls.single;
    expect(failed.segments, hasLength(2));
    for (final String segment in failed.segments) {
      expect(File(segment).existsSync(), isTrue);
    }
    expect(camera.count(cameraId, 'stop'), 2);

    liveAudio.joinFails = true;
    expect(
      (await time.finish(recorder.stop)).error,
      _keptWith(videoJoinMessage),
    );
    expect(joiner.calls, hasLength(2));
    final _JoinCall retried = joiner.calls.last;
    expect(retried.segments, failed.segments);
    expect(retried.output, isNot(failed.output));
    expect(File(retried.output).existsSync(), isTrue);
    expect(File(liveAudio.soundPath!).existsSync(), isTrue);

    liveAudio.joinFails = false;
    final VideoRecording recording = (await time.finish(recorder.stop)).value;

    expect(joiner.calls, hasLength(2));
    expect(liveAudio.joins, hasLength(2));
    expect(soundJoinOf(recording).video, retried.output);
    expect(_captureFile(recording.media).readAsBytesSync(), fakeJoinedBytes);
    expect(camera.count(cameraId, 'stop'), 2);
  });

  test(
    'a join past its budget is abandoned and its late file deleted',
    () async {
      final CameraWindowsVideoRecorder recorder = newRecorder();
      joiner.plans.add((List<String> segments, String output) async {
        File(output).writeAsBytesSync(const <int>[9, 9]);
        await Future<void>.delayed(const Duration(seconds: 40));
        return File(output);
      });
      await startTake(recorder);
      await time.elapse(const Duration(seconds: 30));
      await pauseKeeping(recorder);
      expect((await time.finish(recorder.resume)).error, isNull);
      await time.elapse(const Duration(seconds: 30));

      final _Outcome<VideoRecording> keep = time.begin(recorder.stop);
      await time.until(() => joiner.calls.isNotEmpty);
      final _JoinCall join = joiner.calls.single;

      await time.elapse(const Duration(seconds: 24));
      expect(keep.done, isFalse);
      await time.elapse(const Duration(seconds: 1));
      expect(keep.done, isTrue);
      expect(keep.error, _keptWith(videoJoinMessage));
      for (final String segment in join.segments) {
        expect(File(segment).existsSync(), isTrue);
      }
      expect(File(join.output).existsSync(), isTrue);

      await time.elapse(const Duration(seconds: 15));
      await time.until(() => !File(join.output).existsSync());
      expect(File(join.output).existsSync(), isFalse);
      for (final String segment in join.segments) {
        expect(File(segment).existsSync(), isTrue);
      }
    },
  );

  test('a last stretch that throws is dropped and the take resumes on a new '
      'session', () async {
    final CameraWindowsVideoRecorder recorder = newRecorder();
    await startTake(recorder);
    final int firstCamera = camera.lastCamera;
    await time.elapse(const Duration(seconds: 10));
    final String firstSegment = await pauseKeeping(recorder);
    expect((await time.finish(recorder.resume)).error, isNull);
    await time.elapse(const Duration(seconds: 4));
    camera.stopReplies.add(_throws);

    expect(
      (await time.finish(recorder.stop)).error,
      _keptWith(videoLastPartMessage),
    );
    await time.settle();
    expect(File(firstSegment).existsSync(), isTrue);
    expect(camera.count(firstCamera, 'dispose'), 1);
    expect(time.run(() => recorder.elapsed), const Duration(seconds: 10));
    final int firstCameraStops = camera.count(firstCamera, 'stop');
    expect(firstCameraStops, 2);

    time.run(() => recorder.openSession(_usbCamera));
    expect((await time.finish(recorder.resume)).error, isNull);
    final int secondCamera = camera.lastCamera;
    expect(secondCamera, isNot(firstCamera));
    expect(camera.count(secondCamera, 'create'), 1);
    expect(camera.count(secondCamera, 'start'), 1);

    await time.elapse(const Duration(seconds: 6));
    final String secondSegment = await pauseKeeping(recorder);
    final VideoRecording recording = (await time.finish(recorder.stop)).value;

    expect(camera.count(firstCamera, 'stop'), firstCameraStops);
    expect(joiner.calls.single.segments, <String>[firstSegment, secondSegment]);
    expect(joiner.calls.single.contents, <List<int>>[
      camera.stopBytes[0],
      camera.stopBytes[1],
    ]);
    expect(recording.durationMs, 16000);
  });

  test(
    'a last stretch that hangs or hands back no data keeps the earlier parts',
    () async {
      final CameraWindowsVideoRecorder recorder = newRecorder();

      Future<String> pausedAndResumed() async {
        await startTake(recorder);
        await time.elapse(const Duration(seconds: 5));
        final String segment = await pauseKeeping(recorder);
        expect((await time.finish(recorder.resume)).error, isNull);
        await time.elapse(const Duration(seconds: 20));
        return segment;
      }

      final String hungSegment = await pausedAndResumed();
      final int hungCamera = camera.lastCamera;
      final int stopsBeforeKeep = camera.count(hungCamera, 'stop');
      final Set<String> filesBeforeKeep = captureFiles();
      camera.stopReplies.add(_untilDisposed);
      final _Outcome<VideoRecording> hung = time.begin(recorder.stop);
      await time.settle();
      await time.elapse(const Duration(seconds: 14));
      expect(hung.done, isFalse);
      await time.elapse(const Duration(seconds: 1));
      expect(hung.done, isTrue);
      expect(hung.error, _keptWith(videoLastPartMessage));
      await time.settle();
      expect(camera.count(hungCamera, 'dispose'), 1);
      expect(time.escaped, isEmpty);
      expect(File(hungSegment).existsSync(), isTrue);
      expect(captureFiles(), filesBeforeKeep);
      final VideoRecording kept = (await time.finish(recorder.stop)).value;
      expect(soundJoinOf(kept).video, hungSegment);
      expect(camera.count(hungCamera, 'stop') - stopsBeforeKeep, 1);

      final String lateSegment = await pausedAndResumed();
      final int lateCamera = camera.lastCamera;
      camera.stopReplies.add(_after(const Duration(seconds: 20), _withData));
      final _Outcome<VideoRecording> late = time.begin(recorder.stop);
      await time.settle();
      await time.elapse(const Duration(seconds: 14));
      expect(late.done, isFalse);
      await time.elapse(const Duration(seconds: 1));
      expect(late.error, _keptWith(videoLastPartMessage));
      expect(camera.count(lateCamera, 'dispose'), 1);
      final int repliesBefore = camera.stopPaths.length;
      await time.elapse(const Duration(seconds: 5));
      await time.until(() => camera.stopPaths.length > repliesBefore);
      final String replied = camera.stopPaths.last;
      await time.until(() => !File(replied).existsSync());
      expect(File(replied).existsSync(), isFalse);
      expect(time.escaped, isEmpty);
      expect(File(lateSegment).existsSync(), isTrue);

      await pausedAndResumed();
      camera.stopReplies.add(_after(const Duration(seconds: 20), _missingFile));
      final _Outcome<VideoRecording> lateMissing = time.begin(recorder.stop);
      await time.settle();
      await time.elapse(const Duration(seconds: 15));
      expect(lateMissing.error, _keptWith(videoLastPartMessage));
      await time.elapse(const Duration(seconds: 5));
      await time.settle();
      expect(time.escaped, isEmpty);

      final String missingSegment = await pausedAndResumed();
      camera.stopReplies.add(_missingFile);
      expect(
        (await time.finish(recorder.stop)).error,
        _keptWith(videoLastPartMessage),
      );
      expect(File(missingSegment).existsSync(), isTrue);

      final String emptySegment = await pausedAndResumed();
      camera.stopReplies.add(_emptyFile);
      expect(
        (await time.finish(recorder.stop)).error,
        _keptWith(videoLastPartMessage),
      );
      expect(File(emptySegment).existsSync(), isTrue);
    },
  );

  test(
    'stale segment and join files are swept when a Windows take starts',
    () async {
      final CameraWindowsVideoRecorder recorder = newRecorder();
      await startTake(recorder);
      await pauseKeeping(recorder);
      expect((await time.finish(recorder.resume)).error, isNull);
      final VideoRecording saved = (await time.finish(recorder.stop)).value;
      final File savedMovie = _captureFile(saved.media);
      expect(p.basename(soundJoinOf(saved).video), matches(_joinName));
      expect(p.basename(savedMovie.path), matches(_keptName));

      final File staleSegment = File(p.join(captures(), 'video_segment_1.mp4'))
        ..writeAsBytesSync(const <int>[1]);
      final File staleJoin = File(p.join(captures(), 'video_join_2.mp4'))
        ..writeAsBytesSync(const <int>[2]);
      final File locked = File(p.join(captures(), 'video_segment_5.mp4'))
        ..writeAsBytesSync(const <int>[5]);
      final Directory folder = Directory(
        p.join(captures(), 'video_segment_3.mp4'),
      )..createSync();
      await Process.run('chflags', <String>['uchg', locked.path]);
      addTearDown(
        () => Process.run('chflags', <String>['nouchg', locked.path]),
      );

      await startTake(recorder);

      expect(camera.count(camera.lastCamera, 'start'), 1);
      expect(staleSegment.existsSync(), isFalse);
      expect(staleJoin.existsSync(), isFalse);
      expect(locked.readAsBytesSync(), const <int>[5]);
      expect(folder.existsSync(), isTrue);
      expect(savedMovie.readAsBytesSync(), fakeJoinedBytes);
    },
  );

  test('letting a paused Windows take go deletes its segments', () async {
    final CameraWindowsVideoRecorder recorder = newRecorder();
    await startTake(recorder);
    await time.elapse(const Duration(seconds: 1));
    final String segment = await pauseKeeping(recorder);
    expect(File(segment).existsSync(), isTrue);

    expect((await time.finish(recorder.cancel)).error, isNull);

    expect(segmentFiles(), isEmpty);
    expect(joiner.calls, isEmpty);
    expect(camera.stillBytes, hasLength(1));

    await startTake(recorder);
    await pauseKeeping(recorder);
    expect(camera.stillBytes, hasLength(2));
  });
}
