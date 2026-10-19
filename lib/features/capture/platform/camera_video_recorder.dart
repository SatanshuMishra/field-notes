import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart'
    show CameraPlatform;
import 'package:camera_windows/camera_windows.dart' show CameraWindows;
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' show AudioRecorder;

import 'package:field_notes/data/media/captured_audio.dart';
import 'package:field_notes/data/media/live_audio_channel.dart';
import 'package:field_notes/data/media/media_work_budget.dart';
import 'package:field_notes/data/media/video_join.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/input_level.dart'
    show AudioRecorderFactory;
import 'package:field_notes/features/capture/audio/live_audio_capture.dart';
import 'package:field_notes/features/capture/audio/microphone_hearing.dart';
import 'package:field_notes/features/capture/video/audio_input_selectable.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:field_notes/features/capture/voice/record_voice_recorder.dart'
    show voiceRecordingExtension;
import 'package:field_notes/features/capture/voice/voice_processing.dart';
import 'package:field_notes/features/capture/voice/voice_recorder.dart'
    show micPermissionMessage;

const String videoRecordingMime = 'video/mp4';
const String videoRecordingExtension = 'mp4';
const String videoThumbnailMime = 'image/jpeg';
const String videoThumbnailExtension = 'jpg';
const int videoRecordingBitrate = 4000000;

String videoRecordingFileName(int nowMs) =>
    'video_$nowMs.$videoRecordingExtension';

String videoThumbnailFileName(int nowMs) =>
    'video_thumb_$nowMs.$videoThumbnailExtension';

Future<String> resolveVideoThumbnailPath(Directory directory, int nowMs) async {
  await directory.create(recursive: true);
  return p.join(directory.path, videoThumbnailFileName(nowMs));
}

typedef VideoSoundProcessing = Future<VoiceProcessing> Function();

VideoRecorder createPlatformVideoRecorder({
  TargetPlatform? platform,
  LiveEncoder encoder = const LiveEncoder(),
  AudioJoiner audioJoiner = const AudioJoiner(),
  AudioRecorderFactory audioRecorderFactory = AudioRecorder.new,
  Future<AudioInput> Function()? resolveInput,
  VideoSoundProcessing? resolveProcessing,
}) => switch (platform ?? defaultTargetPlatform) {
  TargetPlatform.macOS => CameraMacosVideoRecorder(
    encoder: encoder,
    audioJoiner: audioJoiner,
    audioRecorderFactory: audioRecorderFactory,
    resolveProcessing: resolveProcessing,
    microphoneCaptureTimes: macMicrophoneCaptureTimes,
  ),
  TargetPlatform.windows => CameraWindowsVideoRecorder(
    encoder: encoder,
    audioJoiner: audioJoiner,
    audioRecorderFactory: audioRecorderFactory,
    resolveProcessing: resolveProcessing,
  ),
  _ => CameraVideoRecorder(
    encoder: encoder,
    audioJoiner: audioJoiner,
    audioRecorderFactory: audioRecorderFactory,
    resolveInput: resolveInput,
    resolveProcessing: resolveProcessing,
  ),
};

List<File> _recordingFiles(VideoRecording recording) => <File>[
  for (final CaptureMedia? media in <CaptureMedia?>[
    recording.media,
    recording.thumbnail,
  ])
    if (media is CaptureFile) media.file,
];

bool _isMovieOf(String path, VideoRecording recording) {
  final CaptureMedia media = recording.media;
  return media is CaptureFile && media.file.path == path;
}

class _OwnedCaptures {
  const _OwnedCaptures([this._byPath = const <String, VideoRecording>{}]);

  final Map<String, VideoRecording> _byPath;

  _OwnedCaptures adopt(VideoRecording recording) => _OwnedCaptures(
    <String, VideoRecording>{
      ..._byPath,
      for (final File file in _recordingFiles(recording)) file.path: recording,
    },
  );

  _OwnedCaptures without(VideoRecording recording) =>
      _OwnedCaptures(<String, VideoRecording>{
        for (final MapEntry<String, VideoRecording> entry in _byPath.entries)
          if (!identical(entry.value, recording)) entry.key: entry.value,
      });

  _OwnedCaptures withoutMovies() => _OwnedCaptures(<String, VideoRecording>{
    for (final MapEntry<String, VideoRecording> entry in _byPath.entries)
      if (!_isMovieOf(entry.key, entry.value)) entry.key: entry.value,
  });

  bool holds(String path) =>
      _byPath.keys.any((String owned) => p.equals(owned, path));

  List<File> filesOf(VideoRecording recording) => <File>[
    for (final File file in _recordingFiles(recording))
      if (identical(_byPath[file.path], recording)) file,
  ];
}

Future<void> _deleteCaptureFile(String? path) async {
  if (path == null || path.isEmpty) {
    return;
  }
  try {
    final File file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (error, stackTrace) {
    debugPrint('Capture file delete failed: $error\n$stackTrace');
  }
}

Future<bool> _holdsData(File file) async {
  try {
    return await file.exists() && await file.length() > 0;
  } catch (error) {
    return false;
  }
}

Future<void> _deleteCaptureFiles(List<File> files) async {
  for (final File file in files) {
    await _deleteCaptureFile(file.path);
  }
}

VideoRecording _recordingOf(File movie, File? thumbnail, int durationMs) =>
    VideoRecording(
      media: CaptureFile(
        file: movie,
        mime: videoRecordingMime,
        durationMs: durationMs,
      ),
      durationMs: durationMs,
      thumbnail: thumbnail == null
          ? null
          : CaptureFile(file: thumbnail, mime: videoThumbnailMime),
    );

AudioInput _soundInputWithId(String? deviceId) => deviceId == null
    ? const AudioInput(id: null, label: systemDefaultInputLabel)
    : AudioInput(id: deviceId, label: deviceId);

Future<void> _requireMicrophone(Future<bool> Function() permission) async {
  final bool granted;
  try {
    granted = await permission();
  } catch (error) {
    throw VideoRecorderException(micPermissionMessage, cause: error);
  }
  if (!granted) {
    throw const VideoRecorderException(micPermissionMessage);
  }
}

class _CaptureFolder {
  _CaptureFolder(this._temporaryDirectory);

  final Future<Directory> Function() _temporaryDirectory;
  int _lastNameMs = 0;

  Future<Directory> get location async =>
      Directory(p.join((await _temporaryDirectory()).path, _captureFolder));

  Future<String> freshPath(String Function(int nameMs) name) async {
    final Directory captures = await location;
    await captures.create(recursive: true);
    final int now = clock.now().millisecondsSinceEpoch;
    int nameMs = now > _lastNameMs ? now : _lastNameMs + 1;
    while (await FileSystemEntity.type(
          p.join(captures.path, name(nameMs)),
          followLinks: false,
        ) !=
        FileSystemEntityType.notFound) {
      nameMs += 1;
    }
    _lastNameMs = nameMs;
    return p.join(captures.path, name(nameMs));
  }
}

typedef _Picture = ({File movie, File? thumbnail, int durationMs});

class _LiveSound {
  _LiveSound({
    required AudioRecorderFactory recorderFactory,
    required LiveEncoder encoder,
    required VoiceChainRunner chainRunner,
    required this._joiner,
    required VideoSoundProcessing? resolveProcessing,
    required this._folder,
    Stream<CapturedAudio> captureTimes = const Stream<CapturedAudio>.empty(),
    Duration Function()? clock,
  }) : _capture = LiveAudioCapture(
         recorderFactory: recorderFactory,
         encoder: encoder,
         chainRunner: chainRunner,
         captureTimes: captureTimes,
         clock: clock,
       ),
       _resolveProcessing = resolveProcessing ?? defaultVoiceProcessing;

  final LiveAudioCapture _capture;
  final AudioJoiner _joiner;
  final VideoSoundProcessing _resolveProcessing;
  final _CaptureFolder _folder;
  LiveAudioTake? _take;
  _Picture? _pending;
  AudioInput? _armedOn;
  String? _armedPath;
  bool _inTake = false;
  bool _everArmed = false;
  bool _takeArming = false;
  int _epoch = 0;
  Future<bool>? _warmOpening;

  bool get holdsPicture => _pending != null;

  Stream<double> get level => _capture.level;

  Stream<MicrophoneHearing> get hearing => _capture.hearing;

  MicrophoneHearing get hearingNow => _capture.hearingNow;

  Future<bool> hasPermission() => _capture.hasPermission();

  bool holdsSound(String path) => _capture.running && _armedPath == path;

  bool get _busy => _inTake || _takeArming;

  bool _armedIdleOn(AudioInput input) =>
      _capture.running && !_inTake && _armedOn == input;

  Future<void> warm({
    required Future<AudioInput> Function() input,
    required Future<bool> Function() permission,
  }) async {
    final int epoch = _epoch;
    if (_busy || !await permission()) {
      return;
    }
    final AudioInput chosen = await input();
    if (epoch != _epoch || _busy || _armedIdleOn(chosen)) {
      return;
    }
    final Future<bool> opening = _arm(chosen, epoch);
    _warmOpening = opening;
    try {
      await opening;
    } finally {
      if (identical(_warmOpening, opening)) {
        _warmOpening = null;
      }
    }
  }

  Future<void> warmQuietly({
    required Future<AudioInput> Function() input,
    required Future<bool> Function() permission,
  }) async {
    try {
      await warm(input: input, permission: permission);
    } catch (error, stackTrace) {
      debugPrint(
        'The microphone did not open with the preview: $error\n$stackTrace',
      );
    }
  }

  Future<void> ensureArmed(AudioInput input) async {
    final int epoch = ++_epoch;
    _takeArming = true;
    try {
      if (_inTake) {
        await _capture.cancel();
        await _dropLeftovers();
      }
      final Future<bool>? opening = _warmOpening;
      if (opening != null && _armedIdleOn(input)) {
        await opening
            .timeout(_warmOpenWait, onTimeout: () => false)
            .then<void>((bool _) {}, onError: (Object _) {});
      }
      if (!_armedIdleOn(input) && !await _arm(input, epoch)) {
        throw const VideoRecorderException(videoStartMessage);
      }
      _inTake = true;
    } finally {
      _takeArming = false;
    }
  }

  void closeMicrophone() {
    _epoch += 1;
    if (!_busy && _everArmed) {
      unawaited(_capture.cancel());
    }
  }

  Future<VoiceProcessing> _processing() async {
    try {
      return await _resolveProcessing();
    } catch (_) {
      return defaultVoiceProcessing();
    }
  }

  Future<bool> _arm(AudioInput input, int epoch) async {
    final VoiceProcessing processing = await _processing();
    final String path;
    try {
      path = await _folder.freshPath(_soundFileName);
    } catch (error) {
      throw VideoRecorderException(videoStartMessage, cause: error);
    }
    if (epoch != _epoch) {
      return false;
    }
    if (_armedIdleOn(input)) {
      return true;
    }
    if (_capture.running) {
      await _capture.cancel();
      if (epoch != _epoch) {
        return false;
      }
    }
    _armedOn = input;
    _armedPath = path;
    _everArmed = true;
    try {
      await _capture.start(
        input: input,
        profile: processing.profile,
        volume: processing.volume,
        path: path,
        armed: true,
      );
    } catch (error) {
      throw VideoRecorderException(videoStartMessage, cause: error);
    }
    return _capture.running;
  }

  void beginWriting({PictureStart picture = const PictureStart()}) =>
      _capture.beginWriting(picture: picture);

  Future<void> pause() async {
    try {
      await _capture.pause();
    } catch (error) {
      throw VideoRecorderException(videoPauseMessage, cause: error);
    }
  }

  Future<void> resume() async {
    try {
      await _capture.resume();
    } catch (error) {
      throw VideoRecorderException(videoPauseMessage, cause: error);
    }
  }

  Future<VideoRecording> keep(Future<_Picture> Function() stopPicture) async {
    final _Picture picture;
    try {
      picture = _pending ?? await stopPicture();
    } on VideoSegmentsKeptException {
      await _pauseQuietly();
      rethrow;
    }
    _pending = picture;
    final LiveAudioTake? sound = await _finished();
    final File movie = sound == null
        ? picture.movie
        : await _join(picture, sound);
    _pending = null;
    _inTake = false;
    return _recordingOf(movie, picture.thumbnail, picture.durationMs);
  }

  Future<File> _join(_Picture picture, LiveAudioTake sound) async {
    final String output;
    try {
      output = await _folder.freshPath(videoRecordingFileName);
    } catch (error) {
      throw VideoSegmentsKeptException(videoJoinMessage, cause: error);
    }
    final Future<String> joining = Future<String>.sync(
      () => _joiner.join(
        video: picture.movie.path,
        audio: sound.path,
        output: output,
      ),
    );
    final String joined;
    try {
      joined = await joining.timeout(
        mediaWorkBudget(Duration(milliseconds: picture.durationMs)),
      );
    } catch (error) {
      unawaited(
        joining
            .then<void>((String _) {}, onError: (Object _) {})
            .whenComplete(() => _deleteCaptureFile(output)),
      );
      throw VideoSegmentsKeptException(videoJoinMessage, cause: error);
    }
    _take = null;
    await _deleteCaptureFile(picture.movie.path);
    await _deleteCaptureFile(sound.path);
    return File(joined);
  }

  Future<LiveAudioTake?> _finished() async {
    final LiveAudioTake? done = _take;
    if (done != null) {
      return done;
    }
    try {
      final LiveAudioTake take = await _capture.stop();
      _take = take;
      return take;
    } catch (error, stackTrace) {
      debugPrint(
        'Live sound could not be finished, keeping the picture alone: '
        '$error\n$stackTrace',
      );
      return null;
    }
  }

  Future<void> _pauseQuietly() async {
    try {
      await _capture.pause();
    } catch (error, stackTrace) {
      debugPrint('Live sound pause failed: $error\n$stackTrace');
    }
  }

  Future<void> _dropPending() async {
    final _Picture? pending = _pending;
    _pending = null;
    if (pending != null) {
      await _deleteCaptureFiles(<File>[pending.movie, ?pending.thumbnail]);
    }
  }

  Future<void> _dropLeftovers() async {
    final LiveAudioTake? take = _take;
    _take = null;
    _inTake = false;
    await _deleteCaptureFile(take?.path);
    await _dropPending();
  }

  Future<void> discard() async {
    _epoch += 1;
    if (_everArmed) {
      await _capture.cancel();
    }
    await _dropLeftovers();
  }

  Future<void> dispose() async {
    await discard();
    final Future<void> disposing = _capture.dispose();
    if (_everArmed) {
      await disposing;
    } else {
      unawaited(disposing);
    }
  }
}

abstract class _CameraPackageVideoRecorder implements VideoRecorder {
  _CameraPackageVideoRecorder({
    this._startTimeoutMessage,
    required Future<Directory> Function() temporaryDirectory,
    required LiveEncoder encoder,
    required AudioJoiner audioJoiner,
    required AudioRecorderFactory audioRecorderFactory,
    required VoiceChainRunner chainRunner,
    required VideoSoundProcessing? resolveProcessing,
  }) : _folder = _CaptureFolder(temporaryDirectory) {
    _sound = _LiveSound(
      recorderFactory: audioRecorderFactory,
      encoder: encoder,
      chainRunner: chainRunner,
      joiner: audioJoiner,
      resolveProcessing: resolveProcessing,
      folder: _folder,
    );
  }

  final String? _startTimeoutMessage;
  final _CaptureFolder _folder;
  late final _LiveSound _sound;
  CameraController? _controller;
  _CameraSession? _session;
  final Stopwatch _elapsed = clock.stopwatch();
  _OwnedCaptures _owned = const _OwnedCaptures();

  Future<AudioInput> _soundInput();

  List<VideoCaptureDevice> _devicesOf(List<CameraDescription> cameras);

  Future<void> _stabilise(CameraController controller);

  Widget _preview(CameraController controller);

  Future<(File, File?)> _claim(File movie, File? still);

  Future<void> _abandonStill(File? still) async {}

  Future<void> _beforeControllerCreated() async {}

  void _controllerCreated() {}

  @override
  Duration get elapsed => _elapsed.elapsed;

  @override
  Stream<double> get level => _sound.level;

  @override
  Stream<MicrophoneHearing> get hearing => _sound.hearing;

  @override
  MicrophoneHearing get hearingNow => _sound.hearingNow;

  Future<void> _warmMicrophone() =>
      _sound.warmQuietly(input: _soundInput, permission: _sound.hasPermission);

  @override
  Future<List<VideoCaptureDevice>> listDevices() async {
    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (error) {
      throw VideoRecorderException(videoDeviceListMessage, cause: error);
    }
    return _devicesOf(cameras);
  }

  @override
  Future<void> start() async {
    final _CameraSession? session = _session;
    if (session == null) {
      throw const VideoRecorderException(videoStartMessage);
    }
    try {
      await _requireMicrophone(_sound.hasPermission);
      await _sound.ensureArmed(await _soundInput());
      final CameraController controller = await _ready(session);
      if (!identical(_session, session)) {
        throw const VideoRecorderException(videoStartMessage);
      }
      await controller.startVideoRecording();
      _sound.beginWriting();
      _elapsed
        ..reset()
        ..start();
      await _stabilise(controller);
    } on VideoRecorderException {
      _elapsed.stop();
      await _sound.discard();
      rethrow;
    } catch (error) {
      _elapsed.stop();
      await _sound.discard();
      throw VideoRecorderException(videoStartMessage, cause: error);
    }
  }

  Future<CameraController> _ready(_CameraSession session) async {
    final String? timeoutMessage = _startTimeoutMessage;
    if (timeoutMessage == null) {
      return session.ready;
    }
    try {
      return await session.ready.timeout(cameraStartTimeout);
    } on TimeoutException {
      throw VideoRecorderException(timeoutMessage);
    }
  }

  @override
  Future<VideoRecording> stop() async {
    _elapsed.stop();
    final VideoRecording recording = await _sound.keep(_stopPicture);
    _owned = _owned.adopt(recording);
    return recording;
  }

  Future<_Picture> _stopPicture() async {
    final int durationMs = _elapsed.elapsedMilliseconds;
    final CameraController? controller = _controller;
    if (controller == null) {
      throw const VideoRecorderException(videoStopMessage);
    }
    File? still;
    try {
      still = await _captureThumbnail(controller);
      final XFile take = await controller.stopVideoRecording();
      final (File movie, File? thumbnail) = await _claim(
        File(take.path),
        still,
      );
      return (movie: movie, thumbnail: thumbnail, durationMs: durationMs);
    } on VideoRecorderException {
      rethrow;
    } catch (error) {
      await _abandonStill(still);
      throw VideoRecorderException(videoStopMessage, cause: error);
    } finally {
      await _releaseController(controller);
    }
  }

  Future<void> _releaseController(CameraController controller) async {
    _session = null;
    _controller = null;
    await controller.dispose();
  }

  Future<File?> _captureThumbnail(CameraController controller) async {
    try {
      final XFile still = await controller.takePicture();
      return File(still.path);
    } catch (error) {
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    _elapsed.stop();
    final CameraController? controller = _controller;
    _controller = null;
    _session = null;
    await _sound.discard();
    if (controller == null) {
      return;
    }
    try {
      if (controller.value.isRecordingVideo) {
        final XFile take = await controller.stopVideoRecording();
        await _deleteCaptureFile(take.path);
      }
    } on CameraException {
      return;
    } finally {
      await controller.dispose();
    }
  }

  @override
  Future<void> releaseSaved(VideoRecording recording) async {
    final List<File> files = _owned.filesOf(recording);
    _owned = _owned.without(recording);
    await _deleteCaptureFiles(files);
  }

  @override
  Future<void> release() async {
    _elapsed.stop();
    final CameraController? controller = _controller;
    _controller = null;
    _session = null;
    _sound.closeMicrophone();
    if (controller == null) {
      return;
    }
    try {
      await controller.dispose();
    } catch (error, stackTrace) {
      debugPrint('Camera release failed: $error\n$stackTrace');
    }
  }

  @override
  Future<void> dispose() async {
    await release();
    await _sound.dispose();
  }

  @override
  Widget? openSession(String deviceId) {
    final _CameraSession? existing = _session;
    if (existing != null && existing.deviceId == deviceId) {
      unawaited(_warmMicrophone());
      return existing.preview;
    }
    final Completer<CameraController> ready = Completer<CameraController>();
    ready.future.ignore();
    final _CameraSession session = _CameraSession(
      deviceId: deviceId,
      ready: ready.future,
      preview: _CameraSessionPreview(
        key: ValueKey<String>('camera-preview-$deviceId'),
        ready: ready.future,
        builder: _preview,
      ),
    );
    _session = session;
    unawaited(_warmMicrophone());
    unawaited(_initialise(session, ready));
    return session.preview;
  }

  Future<void> _initialise(
    _CameraSession session,
    Completer<CameraController> ready,
  ) async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty || !identical(_session, session)) {
        throw const VideoRecorderException(videoStartMessage);
      }
      await _beforeControllerCreated();
      if (!identical(_session, session)) {
        throw const VideoRecorderException(videoStartMessage);
      }
      final CameraController controller = CameraController(
        _selected(cameras, session.deviceId),
        ResolutionPreset.veryHigh,
        enableAudio: false,
        videoBitrate: videoRecordingBitrate,
      );
      _controller = controller;
      _controllerCreated();
      await controller.initialize();
      if (!identical(_session, session)) {
        throw const VideoRecorderException(videoStartMessage);
      }
      await _stabilise(controller);
      ready.complete(controller);
    } on VideoRecorderException catch (error) {
      ready.completeError(error);
    } catch (error) {
      ready.completeError(
        VideoRecorderException(videoStartMessage, cause: error),
      );
    }
  }

  CameraDescription _selected(
    List<CameraDescription> cameras,
    String deviceId,
  ) {
    for (final CameraDescription camera in cameras) {
      if (camera.name == deviceId) {
        return camera;
      }
    }
    return cameras.first;
  }
}

class CameraVideoRecorder extends _CameraPackageVideoRecorder
    implements CameraControls {
  CameraVideoRecorder({
    Future<Directory> Function()? temporaryDirectory,
    super.encoder = const LiveEncoder(),
    super.audioJoiner = const AudioJoiner(),
    super.audioRecorderFactory = AudioRecorder.new,
    super.chainRunner = runVoiceChainInIsolate,
    Future<AudioInput> Function()? resolveInput,
    super.resolveProcessing,
  }) : _resolveInput = resolveInput ?? systemDefaultAudioInput,
       super(temporaryDirectory: temporaryDirectory ?? getTemporaryDirectory);

  final Future<AudioInput> Function() _resolveInput;
  double _zoom = 1;

  @override
  Future<AudioInput> _soundInput() async {
    try {
      return await _resolveInput();
    } catch (_) {
      return systemDefaultAudioInput();
    }
  }

  @override
  bool get supportsPause => true;

  @override
  double get zoom => _zoom;

  @override
  List<VideoCaptureDevice> _devicesOf(List<CameraDescription> cameras) =>
      cameraDeviceLabels(frontAndBackCameras(cameras));

  @override
  void _controllerCreated() {
    _zoom = 1;
  }

  @override
  Widget _preview(CameraController controller) =>
      Center(child: CameraPreview(controller));

  @override
  Future<(File, File?)> _claim(File movie, File? still) async => (movie, still);

  CameraController? get _readyController {
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return null;
    }
    return controller;
  }

  @override
  Rect? previewRectIn(Size area) {
    final CameraController? controller = _readyController;
    if (controller == null || area.isEmpty) {
      return null;
    }
    final double aspect = previewAspectRatio(controller.value);
    final Size fitted = applyBoxFit(
      BoxFit.contain,
      Size(aspect, 1),
      area,
    ).destination;
    return Alignment.center.inscribe(fitted, Offset.zero & area);
  }

  @override
  Future<ZoomRange?> zoomRange() async {
    final CameraController? controller = _readyController;
    if (controller == null) {
      return null;
    }
    try {
      return ZoomRange(
        await controller.getMinZoomLevel(),
        await controller.getMaxZoomLevel(),
      );
    } on CameraException catch (error) {
      debugPrint('Camera zoom range unavailable: $error');
      return null;
    }
  }

  @override
  Future<void> setZoom(double zoom) async {
    final CameraController? controller = _readyController;
    if (controller == null) {
      return;
    }
    try {
      await controller.setZoomLevel(zoom);
      _zoom = zoom;
    } on CameraException catch (error) {
      debugPrint('Camera zoom failed: $error');
    }
  }

  @override
  Future<void> focusAt(Offset point) async {
    final CameraController? controller = _readyController;
    if (controller == null) {
      return;
    }
    try {
      await controller.setExposurePoint(point);
      await controller.setFocusPoint(point);
    } on CameraException catch (error) {
      debugPrint('Camera focus failed: $error');
    }
  }

  @override
  Future<void> pause() async {
    final CameraController? controller = _controller;
    if (controller == null) {
      throw const VideoRecorderException(videoPauseMessage);
    }
    try {
      await controller.pauseVideoRecording();
    } catch (error) {
      throw VideoRecorderException(videoPauseMessage, cause: error);
    }
    _elapsed.stop();
    await _sound.pause();
  }

  @override
  Future<void> resume() async {
    final CameraController? controller = _controller;
    if (controller == null) {
      throw const VideoRecorderException(videoPauseMessage);
    }
    try {
      await controller.resumeVideoRecording();
    } catch (error) {
      throw VideoRecorderException(videoPauseMessage, cause: error);
    }
    _elapsed.start();
    await _sound.resume();
  }

  @override
  Future<void> _stabilise(CameraController controller) async {
    try {
      await controller.setVideoStabilizationMode(VideoStabilizationMode.level1);
    } on CameraException catch (error) {
      debugPrint('Video stabilisation unavailable: $error');
    }
  }
}

class CameraWindowsVideoRecorder extends _CameraPackageVideoRecorder
    implements AudioInputSelectable {
  CameraWindowsVideoRecorder({
    Future<Directory> Function()? temporaryDirectory,
    VideoJoiner? joiner,
    Future<void> Function(String? endpointId)? setAudioInputDevice,
    super.encoder = const LiveEncoder(),
    super.audioJoiner = const AudioJoiner(),
    super.audioRecorderFactory = AudioRecorder.new,
    super.chainRunner = runVoiceChainInIsolate,
    super.resolveProcessing,
  }) : _joiner = joiner ?? const VideoJoiner(),
       _setAudioInputDevice =
           setAudioInputDevice ?? CameraWindows.setAudioInputDevice,
       super(
         startTimeoutMessage: videoStartTimeoutMessageWindows,
         temporaryDirectory: temporaryDirectory ?? getTemporaryDirectory,
       );

  final VideoJoiner _joiner;
  final Future<void> Function(String? endpointId) _setAudioInputDevice;
  String? _audioDeviceId;
  File? _takeThumbnail;
  List<File> _segments = const <File>[];
  bool _joinPending = false;
  Duration _dropped = Duration.zero;
  Duration _stretchStart = Duration.zero;

  @override
  bool get supportsPause => true;

  @override
  Duration get elapsed => _elapsed.elapsed - _dropped;

  @override
  void useAudioInput(String? deviceId) {
    _audioDeviceId = deviceId;
  }

  @override
  Future<AudioInput> _soundInput() async => _soundInputWithId(_audioDeviceId);

  @override
  Future<void> _beforeControllerCreated() async {
    try {
      await _setAudioInputDevice(_audioDeviceId);
    } catch (error, stackTrace) {
      debugPrint('Windows microphone choice failed: $error\n$stackTrace');
    }
  }

  void _clearTake() {
    _takeThumbnail = null;
    _segments = const <File>[];
    _joinPending = false;
    _dropped = Duration.zero;
  }

  @override
  Future<void> start() async {
    _clearTake();
    await _sweepCaptures();
    await super.start();
    _stretchStart = _elapsed.elapsed;
  }

  @override
  Future<void> pause() async {
    final CameraController? controller = _controller;
    if (controller == null) {
      throw const VideoRecorderException(videoPauseMessage);
    }
    final XFile stretch;
    try {
      await _ensureThumbnail(controller);
      stretch = await controller.stopVideoRecording();
    } catch (error) {
      throw VideoRecorderException(videoPauseMessage, cause: error);
    }
    _elapsed.stop();
    await _sound.pause();
    await _keepStretch(File(stretch.path), _elapsed.elapsed - _stretchStart);
  }

  @override
  Future<void> resume() async {
    final _CameraSession? session = _session;
    if (session == null) {
      throw const VideoRecorderException(videoPauseMessage);
    }
    try {
      final CameraController controller = await _ready(session);
      await controller.startVideoRecording();
    } catch (error) {
      throw VideoRecorderException(videoPauseMessage, cause: error);
    }
    _joinPending = false;
    _elapsed.start();
    _stretchStart = _elapsed.elapsed;
    await _sound.resume();
  }

  @override
  Future<_Picture> _stopPicture() async {
    if (!_joinPending) {
      final CameraController? controller = _controller;
      if (controller != null && controller.value.isRecordingVideo) {
        if (_segments.isEmpty) {
          await _endOnlyStretch(controller);
        } else {
          await _endLastStretch(controller);
        }
      } else if (controller != null) {
        await _releaseQuietly(controller);
      }
    }
    final List<File> segments = _segments;
    if (segments.isEmpty) {
      throw const VideoRecorderException(videoStopMessage);
    }
    final int durationMs = elapsed.inMilliseconds;
    final File movie = segments.length == 1
        ? segments.single
        : await _join(segments, durationMs);
    final File? thumbnail = _takeThumbnail;
    _clearTake();
    return (movie: movie, thumbnail: thumbnail, durationMs: durationMs);
  }

  @override
  Future<void> cancel() async {
    final List<File> leftovers = <File>[..._segments, ?_takeThumbnail];
    _clearTake();
    try {
      await super.cancel();
    } finally {
      await _deleteCaptureFiles(leftovers);
    }
  }

  Future<void> _endOnlyStretch(CameraController controller) async {
    final File? still = _takeThumbnail == null
        ? await _captureThumbnail(controller)
        : null;
    final (File, File?) claimed;
    try {
      final XFile take = await controller.stopVideoRecording();
      claimed = await _claim(File(take.path), still);
    } catch (error) {
      await _abandonStill(still);
      throw VideoRecorderException(videoStopMessage, cause: error);
    } finally {
      await _releaseController(controller);
    }
    final (File movie, File? claimedStill) = claimed;
    _segments = <File>[movie];
    _takeThumbnail ??= claimedStill;
  }

  Future<void> _endLastStretch(CameraController controller) async {
    final Duration stretch = _elapsed.elapsed - _stretchStart;
    bool abandoned = false;
    Future<File?> endStretch() async {
      await _ensureThumbnail(controller);
      if (abandoned) {
        return null;
      }
      final XFile stopped = await CameraPlatform.instance.stopVideoRecording(
        controller.cameraId,
      );
      final File file = File(stopped.path);
      if (abandoned || !await _holdsData(file)) {
        await _deleteCaptureFile(file.path);
        return null;
      }
      return _claimSegment(file);
    }

    final Future<File?> ending = endStretch();
    final File? segment;
    try {
      segment = await ending.timeout(mediaWorkBudget(stretch));
    } catch (error) {
      abandoned = true;
      unawaited(
        ending.then<void>(
          (File? late) => _deleteCaptureFile(late?.path),
          onError: (Object _) {},
        ),
      );
      _dropStretch(controller, stretch);
      throw VideoSegmentsKeptException(videoLastPartMessage, cause: error);
    }
    if (segment == null) {
      _dropStretch(controller, stretch);
      throw const VideoSegmentsKeptException(videoLastPartMessage);
    }
    _segments = <File>[..._segments, segment];
    await _releaseQuietly(controller);
  }

  void _dropStretch(CameraController controller, Duration stretch) {
    _session = null;
    _controller = null;
    _dropped += stretch;
    unawaited(
      controller.dispose().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Dropped camera dispose failed: $error\n$stackTrace');
      }),
    );
  }

  Future<void> _releaseQuietly(CameraController controller) async {
    try {
      await _releaseController(controller);
    } catch (error, stackTrace) {
      debugPrint('Camera release failed: $error\n$stackTrace');
    }
  }

  Future<File> _join(List<File> segments, int durationMs) async {
    final String output;
    try {
      output = await _folder.freshPath(_joinFileName);
    } catch (error) {
      _joinPending = true;
      throw VideoSegmentsKeptException(videoJoinMessage, cause: error);
    }
    final Future<File> joining = Future<File>.sync(
      () => _joiner.join(<String>[
        for (final File segment in segments) segment.path,
      ], output),
    );
    final File joined;
    try {
      joined = await joining.timeout(
        mediaWorkBudget(Duration(milliseconds: durationMs)),
      );
    } catch (error) {
      _joinPending = true;
      unawaited(
        joining
            .then<void>((File _) {}, onError: (Object _) {})
            .whenComplete(() => _deleteCaptureFile(output)),
      );
      throw VideoSegmentsKeptException(videoJoinMessage, cause: error);
    }
    await _deleteCaptureFiles(segments);
    return joined;
  }

  Future<void> _keepStretch(File file, Duration stretch) async {
    if (await _holdsData(file)) {
      _segments = <File>[..._segments, await _claimSegment(file)];
      return;
    }
    await _deleteCaptureFile(file.path);
    _dropped += stretch;
  }

  Future<void> _ensureThumbnail(CameraController controller) async {
    if (_takeThumbnail != null) {
      return;
    }
    final File? still = await _captureThumbnail(controller);
    if (still == null) {
      return;
    }
    _takeThumbnail = await _claimStill(still);
  }

  Future<void> _sweepCaptures() async {
    final List<FileSystemEntity> entries;
    try {
      entries = (await _folder.location).listSync(followLinks: false);
    } catch (error) {
      return;
    }
    for (final FileSystemEntity entry in entries) {
      final String name = p.basename(entry.path);
      final bool stale =
          name.startsWith(_segmentFilePrefix) ||
          name.startsWith(_joinFilePrefix) ||
          name.startsWith(_soundFilePrefix);
      if (entry is File &&
          stale &&
          !_owned.holds(entry.path) &&
          !_sound.holdsSound(entry.path)) {
        try {
          entry.deleteSync();
        } catch (error, stackTrace) {
          debugPrint('Capture file delete failed: $error\n$stackTrace');
        }
      }
    }
  }

  Future<File> _claimSegment(File file) async {
    try {
      return await _moveCaptureFile(
        file,
        await _folder.freshPath(_segmentFileName),
      );
    } catch (error, stackTrace) {
      debugPrint('Video segment move failed: $error\n$stackTrace');
      return file;
    }
  }

  Future<File?> _claimStill(File still) async {
    try {
      return await _moveCaptureFile(
        still,
        await _folder.freshPath(videoThumbnailFileName),
      );
    } catch (error, stackTrace) {
      debugPrint('Video thumbnail move failed: $error\n$stackTrace');
      await _deleteCaptureFile(still.path);
      return null;
    }
  }

  @override
  List<VideoCaptureDevice> _devicesOf(List<CameraDescription> cameras) =>
      _windowsCameraDevices(cameras);

  @override
  Future<void> _stabilise(CameraController controller) async {}

  @override
  Widget _preview(CameraController controller) => Center(
    child: AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: controller.buildPreview(),
    ),
  );

  @override
  Future<void> _abandonStill(File? still) => _deleteCaptureFile(still?.path);

  @override
  Future<(File, File?)> _claim(File movie, File? still) async {
    final File claimedMovie;
    try {
      claimedMovie = await _moveCaptureFile(
        movie,
        await _folder.freshPath(videoRecordingFileName),
      );
    } catch (error) {
      await _deleteCaptureFile(still?.path);
      rethrow;
    }
    if (still == null) {
      return (claimedMovie, null);
    }
    return (claimedMovie, await _claimStill(still));
  }
}

const String _captureFolder = 'captures';
const String _segmentFilePrefix = 'video_segment_';
const String _joinFilePrefix = 'video_join_';
const String _soundFilePrefix = 'video_sound_';

String _segmentFileName(int nameMs) =>
    '$_segmentFilePrefix$nameMs.$videoRecordingExtension';

String _joinFileName(int nameMs) =>
    '$_joinFilePrefix$nameMs.$videoRecordingExtension';

String _soundFileName(int nameMs) =>
    '$_soundFilePrefix$nameMs.$voiceRecordingExtension';

Future<File> _moveCaptureFile(File source, String target) async {
  try {
    return await source.rename(target);
  } on FileSystemException {
    final File copy = await source.copy(target);
    try {
      await source.delete();
      return copy;
    } on FileSystemException catch (error, stackTrace) {
      debugPrint('Capture file stayed in place: $error\n$stackTrace');
      await _deleteCaptureFile(copy.path);
      return source;
    }
  }
}

String windowsCameraLabel(String name) {
  final String label = name.replaceFirst(_windowsDevicePath, '');
  return label.isEmpty ? name : label;
}

final RegExp _windowsDevicePath = RegExp(r' <[^<>]*>$');

List<VideoCaptureDevice> _windowsCameraDevices(
  List<CameraDescription> cameras,
) {
  final List<String> labels = <String>[
    for (final CameraDescription camera in cameras)
      windowsCameraLabel(camera.name),
  ];
  return <VideoCaptureDevice>[
    for (int index = 0; index < cameras.length; index += 1)
      VideoCaptureDevice(
        id: cameras[index].name,
        label: _numberedLabel(labels, index),
      ),
  ];
}

String _numberedLabel(List<String> labels, int index) {
  final String label = labels[index];
  final int occurrence = labels
      .take(index + 1)
      .where((String other) => other == label)
      .length;
  return occurrence == 1 ? label : '$label ($occurrence)';
}

class _CameraSession {
  const _CameraSession({
    required this.deviceId,
    required this.ready,
    required this.preview,
  });

  final String deviceId;
  final Future<CameraController> ready;
  final Widget preview;
}

class _CameraSessionPreview extends StatelessWidget {
  const _CameraSessionPreview({
    super.key,
    required this.ready,
    required this.builder,
  });

  final Future<CameraController> ready;
  final Widget Function(CameraController controller) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CameraController>(
      future: ready,
      builder:
          (BuildContext context, AsyncSnapshot<CameraController> snapshot) {
            final CameraController? controller = snapshot.data;
            if (controller == null) {
              return const SizedBox.shrink();
            }
            return builder(controller);
          },
    );
  }
}

double previewAspectRatio(CameraValue value) {
  final DeviceOrientation orientation = value.isRecordingVideo
      ? value.recordingOrientation ?? value.deviceOrientation
      : value.previewPauseOrientation ??
            value.lockedCaptureOrientation ??
            value.deviceOrientation;
  final bool landscape =
      orientation == DeviceOrientation.landscapeLeft ||
      orientation == DeviceOrientation.landscapeRight;
  return landscape ? value.aspectRatio : 1 / value.aspectRatio;
}

List<CameraDescription> frontAndBackCameras(List<CameraDescription> cameras) {
  CameraDescription? back;
  CameraDescription? front;
  for (final CameraDescription camera in cameras) {
    switch (camera.lensDirection) {
      case CameraLensDirection.back:
        back ??= camera;
      case CameraLensDirection.front:
        front ??= camera;
      case CameraLensDirection.external:
        break;
    }
  }
  final List<CameraDescription> chosen = <CameraDescription>[?back, ?front];
  return chosen.isEmpty ? cameras.take(1).toList() : chosen;
}

List<VideoCaptureDevice> cameraDeviceLabels(List<CameraDescription> cameras) =>
    <VideoCaptureDevice>[
      for (final CameraDescription camera in cameras)
        VideoCaptureDevice(
          id: camera.name,
          label: switch (camera.lensDirection) {
            CameraLensDirection.front => 'Front camera',
            CameraLensDirection.back => 'Back camera',
            CameraLensDirection.external => 'External camera',
          },
        ),
    ];

class CameraMacosVideoRecorder implements VideoRecorder, AudioInputSelectable {
  CameraMacosVideoRecorder({
    Future<Directory> Function()? temporaryDirectory,
    CameraMacOSController? controller,
    this._microphonePermission,
    LiveEncoder encoder = const LiveEncoder(),
    AudioJoiner audioJoiner = const AudioJoiner(),
    AudioRecorderFactory audioRecorderFactory = AudioRecorder.new,
    VoiceChainRunner chainRunner = runVoiceChainInIsolate,
    VideoSoundProcessing? resolveProcessing,
    Stream<CapturedAudio> microphoneCaptureTimes =
        const Stream<CapturedAudio>.empty(),
    Duration Function()? clock,
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _suppliedController = controller {
    _sound = _LiveSound(
      recorderFactory: audioRecorderFactory,
      encoder: encoder,
      chainRunner: chainRunner,
      joiner: audioJoiner,
      resolveProcessing: resolveProcessing,
      folder: _CaptureFolder(_temporaryDirectory),
      captureTimes: microphoneCaptureTimes,
      clock: clock,
    );
  }

  final Future<Directory> Function() _temporaryDirectory;
  final CameraMacOSController? _suppliedController;
  final Future<bool> Function()? _microphonePermission;
  late final _LiveSound _sound;
  final Stopwatch _elapsed = clock.stopwatch();
  Completer<CameraMacOSController>? _ready;
  Widget? _preview;
  String? _previewDeviceId;
  String? _audioDeviceId;
  CameraMacOSController? _controller;
  StreamSubscription<void>? _movieStart;
  Timer? _movieStartWait;
  bool _destroyRequested = false;
  bool _aborted = false;
  bool _movieBegun = false;
  bool _paused = false;
  _OwnedCaptures _owned = const _OwnedCaptures();

  @override
  Duration get elapsed => _elapsed.elapsed;

  @override
  Stream<double> get level => _sound.level;

  @override
  Stream<MicrophoneHearing> get hearing => _sound.hearing;

  @override
  MicrophoneHearing get hearingNow => _sound.hearingNow;

  @override
  bool get supportsPause => true;

  Future<void> _warmMicrophone() => _sound.warmQuietly(
    input: () async => _soundInputWithId(_audioDeviceId),
    permission: _microphonePermission ?? _sound.hasPermission,
  );

  @override
  Future<void> pause() async {
    await _confirm(
      (CameraMacOSController controller) => controller.pauseRecording(),
    );
    _paused = true;
    _elapsed.stop();
    await _sound.pause();
  }

  @override
  Future<void> resume() async {
    await _confirm(
      (CameraMacOSController controller) => controller.resumeRecording(),
    );
    _paused = false;
    _runClockWhileFilming();
    await _sound.resume();
  }

  Future<void> _confirm(
    Future<bool?> Function(CameraMacOSController controller) request,
  ) async {
    final CameraMacOSController? controller = _controller;
    if (controller == null) {
      throw const VideoRecorderException(videoPauseMessage);
    }
    final bool? reply;
    try {
      reply = await request(controller);
    } catch (error) {
      throw VideoRecorderException(videoPauseMessage, cause: error);
    }
    if (reply != true) {
      throw const VideoRecorderException(videoPauseMessage);
    }
  }

  @override
  Future<List<VideoCaptureDevice>> listDevices() async {
    final List<CameraMacOSDevice> devices;
    try {
      devices = await CameraMacOS.instance.listDevices(
        deviceType: CameraMacOSDeviceType.video,
      );
    } on PlatformException catch (error) {
      throw VideoRecorderException(
        error.message == _cameraPermissionRefusal
            ? cameraPermissionMessage
            : videoDeviceListMessage,
        cause: error,
      );
    } catch (error) {
      throw VideoRecorderException(videoDeviceListMessage, cause: error);
    }
    return <VideoCaptureDevice>[
      for (final CameraMacOSDevice device in devices)
        if (device.deviceId.isNotEmpty)
          VideoCaptureDevice(id: device.deviceId, label: _deviceLabel(device)),
    ];
  }

  String _deviceLabel(CameraMacOSDevice device) {
    final String? name = device.localizedName;
    return name == null || name.isEmpty ? device.deviceId : name;
  }

  @override
  void useAudioInput(String? deviceId) => _audioDeviceId = deviceId;

  @override
  Widget? openSession(String deviceId) {
    final Widget? existing = _preview;
    if (existing != null && _previewDeviceId == deviceId) {
      unawaited(_warmMicrophone());
      return existing;
    }
    _abandonPendingReady();
    _destroyRequested = false;
    _aborted = false;
    final Completer<CameraMacOSController> ready =
        Completer<CameraMacOSController>();
    _ready = ready;
    final Widget view = CameraMacOSView(
      key: ValueKey<String>(deviceId),
      deviceId: deviceId,
      enableAudio: false,
      cameraMode: CameraMacOSMode.video,
      fit: BoxFit.contain,
      useMovieFileOutput: true,
      movieResolution: PictureResolution.veryHigh,
      videoBitrate: videoRecordingBitrate,
      pictureFormat: PictureFormat.jpg,
      onCameraInizialized: (CameraMacOSController controller) =>
          _onControllerReady(ready, controller),
      onCameraLoading: (Object? error) {
        if (error != null && !ready.isCompleted) {
          ready.completeError(const VideoRecorderException(videoStartMessage));
        }
        return const ColoredBox(color: Color(0xFF000000));
      },
    );
    _preview = view;
    _previewDeviceId = deviceId;
    unawaited(_warmMicrophone());
    final CameraMacOSController? supplied = _suppliedController;
    if (supplied != null) {
      _onControllerReady(ready, supplied);
    }
    return view;
  }

  void _onControllerReady(
    Completer<CameraMacOSController> ready,
    CameraMacOSController controller,
  ) {
    final bool isCurrent = identical(_ready, ready);
    if (!isCurrent || _destroyRequested) {
      if (isCurrent) {
        _ready = null;
      }
      unawaited(_destroy(controller));
      return;
    }
    _controller = controller;
    if (!ready.isCompleted) {
      ready.complete(controller);
    }
  }

  void _abandonPendingReady() {
    final Completer<CameraMacOSController>? pending = _ready;
    _ready = null;
    if (pending != null && !pending.isCompleted) {
      pending.future.ignore();
      pending.completeError(const VideoRecorderException(videoStartMessage));
    }
  }

  @override
  Future<void> start() async {
    await _requireMicrophone(_microphonePermission ?? _sound.hasPermission);
    final Completer<CameraMacOSController>? ready = _ready;
    if (ready == null) {
      throw const VideoRecorderException(videoStartMessage);
    }
    _aborted = false;
    _movieBegun = false;
    _paused = false;
    _elapsed
      ..stop()
      ..reset();
    try {
      await _sound.ensureArmed(_soundInputWithId(_audioDeviceId));
      await _startCamera(ready);
    } catch (_) {
      _stopWaitingForMovieStart();
      _elapsed.stop();
      await _sound.discard();
      rethrow;
    }
  }

  void _listenForMovieStart(CameraMacOSController controller) {
    _stopWaitingForMovieStart();
    _movieStart = controller.videoRecordingStarted.listen(_movieBegan);
  }

  void _waitForMovieStart() {
    if (_movieStart == null) {
      return;
    }
    _movieStartWait = Timer(movieStartTimeout, () {
      debugPrint(
        'The camera never reported the movie start within '
        '${movieStartTimeout.inMilliseconds} ms; writing sound from now',
      );
      _movieBegan();
    });
  }

  void _movieBegan([
    CameraMacOSMovieStart movieStart = const CameraMacOSMovieStart(),
  ]) {
    if (_movieStart == null) {
      return;
    }
    _stopWaitingForMovieStart();
    _sound.beginWriting(
      picture: PictureStart(
        ago: movieStart.firstFrameAge,
        capturedAtNs: movieStart.firstFrameCapturedAtNs,
      ),
    );
    _movieBegun = true;
    _elapsed.reset();
    _runClockWhileFilming();
  }

  void _runClockWhileFilming() {
    if (_movieBegun && !_paused) {
      _elapsed.start();
    }
  }

  void _stopWaitingForMovieStart() {
    final StreamSubscription<void>? movieStart = _movieStart;
    _movieStart = null;
    _movieStartWait?.cancel();
    _movieStartWait = null;
    if (movieStart != null) {
      unawaited(movieStart.cancel());
    }
  }

  Future<void> _startCamera(Completer<CameraMacOSController> ready) async {
    final CameraMacOSController controller;
    try {
      controller = await ready.future.timeout(cameraStartTimeout);
    } on TimeoutException {
      throw const VideoRecorderException(videoStartTimeoutMessage);
    } on VideoRecorderException {
      rethrow;
    } catch (error) {
      throw VideoRecorderException(videoStartMessage, cause: error);
    }
    if (_aborted) {
      throw const VideoRecorderException(videoStartMessage);
    }
    _owned = _owned.withoutMovies();
    _listenForMovieStart(controller);
    try {
      await controller.recordVideo(
        maxVideoDuration: videoHardCapSeconds,
        enableAudio: false,
      );
    } catch (error) {
      throw VideoRecorderException(videoStartMessage, cause: error);
    }
    if (_aborted) {
      throw const VideoRecorderException(videoStartMessage);
    }
    _controller = controller;
    _waitForMovieStart();
  }

  @override
  Future<VideoRecording> stop() async {
    _stopWaitingForMovieStart();
    _elapsed.stop();
    final VideoRecording recording = await _sound.keep(_stopPicture);
    _owned = _owned.adopt(recording);
    if (_preview != null) {
      unawaited(_warmMicrophone());
    }
    return recording;
  }

  Future<_Picture> _stopPicture() async {
    final int durationMs = _elapsed.elapsedMilliseconds;
    final CameraMacOSController? controller = _controller;
    if (controller == null) {
      throw const VideoRecorderException(videoStopMessage);
    }
    File? thumbnail;
    try {
      thumbnail = await _captureThumbnail(controller);
      final CameraMacOSFile? file = await controller.stopRecording();
      final String? path = file?.url;
      if (path == null || path.isEmpty) {
        throw const VideoRecorderException(videoStopMessage);
      }
      return (movie: File(path), thumbnail: thumbnail, durationMs: durationMs);
    } catch (error) {
      await _deleteCaptureFile(thumbnail?.path);
      if (error is VideoRecorderException) {
        rethrow;
      }
      throw VideoRecorderException(videoStopMessage, cause: error);
    }
  }

  Future<File?> _captureThumbnail(CameraMacOSController controller) async {
    try {
      final CameraMacOSFile? still = await controller.takePicture();
      final List<int>? bytes = still?.bytes;
      if (bytes == null || bytes.isEmpty) {
        return null;
      }
      final Directory directory = await _temporaryDirectory();
      final String path = await resolveVideoThumbnailPath(
        directory,
        DateTime.now().millisecondsSinceEpoch,
      );
      final File file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (error, stackTrace) {
      debugPrint('Video thumbnail capture failed: $error\n$stackTrace');
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    _stopWaitingForMovieStart();
    _elapsed.stop();
    _aborted = true;
    _destroyRequested = true;
    final CameraMacOSController? controller = _controller;
    _controller = null;
    _preview = null;
    _previewDeviceId = null;
    _ready = null;
    await _sound.discard();
    if (controller == null) {
      return;
    }
    await _discard(controller);
  }

  Future<void> _discard(CameraMacOSController controller) async {
    try {
      final CameraMacOSFile? file = await controller.stopRecording();
      await _deleteCaptureFile(file?.url);
    } catch (error, stackTrace) {
      debugPrint('Video discard failed: $error\n$stackTrace');
    }
    await _destroy(controller);
  }

  @override
  Future<void> releaseSaved(VideoRecording recording) async {
    final List<File> files = _owned.filesOf(recording);
    _owned = _owned.without(recording);
    await _deleteCaptureFiles(files);
  }

  @override
  Future<void> release() async {
    _stopWaitingForMovieStart();
    _elapsed.stop();
    _destroyRequested = true;
    final CameraMacOSController? controller = _controller;
    _controller = null;
    _preview = null;
    _previewDeviceId = null;
    _sound.closeMicrophone();
    if (controller == null) {
      return;
    }
    _ready = null;
    await _destroy(controller, surface: true);
  }

  Future<void> _destroy(
    CameraMacOSController controller, {
    bool surface = false,
  }) async {
    try {
      await controller.destroy();
    } catch (error, stackTrace) {
      debugPrint('Camera destroy failed: $error\n$stackTrace');
      if (surface) {
        throw VideoRecorderException(videoReleaseMessage, cause: error);
      }
    }
  }

  @override
  Future<void> dispose() async {
    await release();
    await _sound.dispose();
  }
}

const double videoHardCapSeconds = 30 * 60;
const Duration cameraStartTimeout = Duration(seconds: 12);
const Duration movieStartTimeout = Duration(seconds: 2);
const Duration _warmOpenWait = Duration(seconds: 3);
const String _cameraPermissionRefusal = 'Permission not granted';
