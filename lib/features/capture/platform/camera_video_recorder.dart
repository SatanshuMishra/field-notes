import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';

const String videoRecordingMime = 'video/mp4';
const String videoRecordingExtension = 'mp4';
const String videoThumbnailMime = 'image/jpeg';
const String videoThumbnailExtension = 'jpg';
const int videoRecordingBitrate = 4000000;
const int videoRecordingAudioBitrate = 96000;

String videoRecordingFileName(int nowMs) =>
    'video_$nowMs.$videoRecordingExtension';

String videoThumbnailFileName(int nowMs) =>
    'video_thumb_$nowMs.$videoThumbnailExtension';

Future<String> resolveVideoThumbnailPath(Directory directory, int nowMs) async {
  await directory.create(recursive: true);
  return p.join(directory.path, videoThumbnailFileName(nowMs));
}

VideoRecorder createPlatformVideoRecorder({TargetPlatform? platform}) =>
    switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.macOS => CameraMacosVideoRecorder(),
      TargetPlatform.windows => CameraWindowsVideoRecorder(),
      _ => CameraVideoRecorder(),
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

  _OwnedCaptures adopt(VideoRecording recording) =>
      _OwnedCaptures(<String, VideoRecording>{
        ..._byPath,
        for (final File file in _recordingFiles(recording)) file.path: recording,
      });

  _OwnedCaptures without(VideoRecording recording) =>
      _OwnedCaptures(<String, VideoRecording>{
        for (final MapEntry<String, VideoRecording> entry in _byPath.entries)
          if (!identical(entry.value, recording)) entry.key: entry.value,
      });

  _OwnedCaptures withoutMovies() => _OwnedCaptures(<String, VideoRecording>{
        for (final MapEntry<String, VideoRecording> entry in _byPath.entries)
          if (!_isMovieOf(entry.key, entry.value)) entry.key: entry.value,
      });

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

Future<void> _deleteCaptureFiles(List<File> files) async {
  for (final File file in files) {
    await _deleteCaptureFile(file.path);
  }
}

abstract class _CameraPackageVideoRecorder implements VideoRecorder {
  _CameraPackageVideoRecorder({this._startTimeoutMessage});

  final String? _startTimeoutMessage;
  CameraController? _controller;
  _CameraSession? _session;
  final Stopwatch _elapsed = Stopwatch();
  _OwnedCaptures _owned = const _OwnedCaptures();

  List<VideoCaptureDevice> _devicesOf(List<CameraDescription> cameras);

  Future<void> _stabilise(CameraController controller);

  Widget _preview(CameraController controller);

  Future<(File, File?)> _claim(File movie, File? still);

  void _controllerCreated() {}

  @override
  Duration get elapsed => _elapsed.elapsed;

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
      final CameraController controller = await _ready(session);
      if (!identical(_session, session)) {
        throw const VideoRecorderException(videoStartMessage);
      }
      await controller.startVideoRecording();
      _elapsed
        ..reset()
        ..start();
      await _stabilise(controller);
    } on VideoRecorderException {
      _elapsed.stop();
      rethrow;
    } catch (error) {
      _elapsed.stop();
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
    final int durationMs = _elapsed.elapsedMilliseconds;
    final CameraController? controller = _controller;
    if (controller == null) {
      throw const VideoRecorderException(videoStopMessage);
    }
    try {
      final File? still = await _captureThumbnail(controller);
      final XFile take = await controller.stopVideoRecording();
      final (File movie, File? thumbnail) = await _claim(File(take.path), still);
      final VideoRecording recording = VideoRecording(
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
      _owned = _owned.adopt(recording);
      return recording;
    } on VideoRecorderException {
      rethrow;
    } catch (error) {
      throw VideoRecorderException(videoStopMessage, cause: error);
    } finally {
      _session = null;
      _controller = null;
      await controller.dispose();
    }
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
  }

  @override
  Widget? openSession(String deviceId) {
    final _CameraSession? existing = _session;
    if (existing != null && existing.deviceId == deviceId) {
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
      final CameraController controller = CameraController(
        _selected(cameras, session.deviceId),
        ResolutionPreset.veryHigh,
        enableAudio: true,
        videoBitrate: videoRecordingBitrate,
        audioBitrate: videoRecordingAudioBitrate,
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
  double _zoom = 1;

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
  Future<(File, File?)> _claim(File movie, File? still) async =>
      (movie, still);

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
    final Size fitted =
        applyBoxFit(BoxFit.contain, Size(aspect, 1), area).destination;
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

class CameraWindowsVideoRecorder extends _CameraPackageVideoRecorder {
  CameraWindowsVideoRecorder({
    Future<Directory> Function()? temporaryDirectory,
  })  : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
        super(startTimeoutMessage: videoStartTimeoutMessageWindows);

  final Future<Directory> Function() _temporaryDirectory;

  @override
  bool get supportsPause => false;

  @override
  Future<void> pause() async {
    throw UnsupportedError(
      'CameraWindowsVideoRecorder cannot pause a recording',
    );
  }

  @override
  Future<void> resume() async {
    throw UnsupportedError(
      'CameraWindowsVideoRecorder cannot pause a recording',
    );
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
  Future<(File, File?)> _claim(File movie, File? still) async {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final Directory captures;
    final File claimedMovie;
    try {
      captures = Directory(
        p.join((await _temporaryDirectory()).path, _windowsCaptureFolder),
      );
      await captures.create(recursive: true);
      claimedMovie = await _moveCaptureFile(
        movie,
        p.join(captures.path, videoRecordingFileName(nowMs)),
      );
    } catch (error) {
      await _deleteCaptureFile(still?.path);
      rethrow;
    }
    if (still == null) {
      return (claimedMovie, null);
    }
    try {
      final File claimedStill = await _moveCaptureFile(
        still,
        p.join(captures.path, videoThumbnailFileName(nowMs)),
      );
      return (claimedMovie, claimedStill);
    } catch (error, stackTrace) {
      debugPrint('Video thumbnail move failed: $error\n$stackTrace');
      await _deleteCaptureFile(still.path);
      return (claimedMovie, null);
    }
  }
}

const String _windowsCaptureFolder = 'captures';

Future<File> _moveCaptureFile(File source, String target) async {
  try {
    return await source.rename(target);
  } on FileSystemException {
    final File copy = await source.copy(target);
    await _deleteCaptureFile(source.path);
    return copy;
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
  final int occurrence =
      labels.take(index + 1).where((String other) => other == label).length;
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
      builder: (BuildContext context, AsyncSnapshot<CameraController> snapshot) {
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
  final bool landscape = orientation == DeviceOrientation.landscapeLeft ||
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

class CameraMacosVideoRecorder implements VideoRecorder {
  CameraMacosVideoRecorder({Future<Directory> Function()? temporaryDirectory})
      : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final Future<Directory> Function() _temporaryDirectory;
  final Stopwatch _elapsed = Stopwatch();
  Completer<CameraMacOSController>? _ready;
  Widget? _preview;
  String? _previewDeviceId;
  CameraMacOSController? _controller;
  bool _destroyRequested = false;
  bool _aborted = false;
  _OwnedCaptures _owned = const _OwnedCaptures();

  @override
  Duration get elapsed => _elapsed.elapsed;

  @override
  bool get supportsPause => false;

  @override
  Future<void> pause() async {
    throw UnsupportedError('CameraMacosVideoRecorder cannot pause a recording');
  }

  @override
  Future<void> resume() async {
    throw UnsupportedError('CameraMacosVideoRecorder cannot pause a recording');
  }

  @override
  Future<List<VideoCaptureDevice>> listDevices() async {
    final List<CameraMacOSDevice> devices;
    try {
      devices = await CameraMacOS.instance
          .listDevices(deviceType: CameraMacOSDeviceType.video);
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
  Widget? openSession(String deviceId) {
    final Widget? existing = _preview;
    if (existing != null && _previewDeviceId == deviceId) {
      return existing;
    }
    _abandonPendingReady();
    _destroyRequested = false;
    _aborted = false;
    final Completer<CameraMacOSController> ready =
        Completer<CameraMacOSController>();
    _ready = ready;
    final Widget view = CameraMacOSView(
      key: ValueKey<String>('camera-preview-$deviceId'),
      deviceId: deviceId,
      cameraMode: CameraMacOSMode.video,
      fit: BoxFit.contain,
      useMovieFileOutput: true,
      movieResolution: PictureResolution.veryHigh,
      videoBitrate: videoRecordingBitrate,
      audioBitrate: videoRecordingAudioBitrate,
      pictureFormat: PictureFormat.jpg,
      onCameraInizialized: (CameraMacOSController controller) =>
          _onControllerReady(ready, controller),
      onCameraLoading: (Object? error) {
        if (error != null && !ready.isCompleted) {
          ready.completeError(
            const VideoRecorderException(videoStartMessage),
          );
        }
        return const ColoredBox(color: Color(0xFF000000));
      },
    );
    _preview = view;
    _previewDeviceId = deviceId;
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
      pending.completeError(
        const VideoRecorderException(videoStartMessage),
      );
    }
  }

  @override
  Future<void> start() async {
    final Completer<CameraMacOSController>? ready = _ready;
    if (ready == null) {
      throw const VideoRecorderException(videoStartMessage);
    }
    _aborted = false;
    final CameraMacOSController controller;
    try {
      controller = await ready.future.timeout(cameraStartTimeout);
    } on TimeoutException {
      _elapsed.stop();
      throw const VideoRecorderException(videoStartTimeoutMessage);
    } on VideoRecorderException {
      _elapsed.stop();
      rethrow;
    } catch (error) {
      _elapsed.stop();
      throw VideoRecorderException(videoStartMessage, cause: error);
    }
    if (_aborted) {
      throw const VideoRecorderException(videoStartMessage);
    }
    _owned = _owned.withoutMovies();
    try {
      await controller.recordVideo(maxVideoDuration: videoHardCapSeconds);
    } catch (error) {
      _elapsed.stop();
      throw VideoRecorderException(videoStartMessage, cause: error);
    }
    if (_aborted) {
      throw const VideoRecorderException(videoStartMessage);
    }
    _controller = controller;
    _elapsed
      ..reset()
      ..start();
  }

  @override
  Future<VideoRecording> stop() async {
    _elapsed.stop();
    final int durationMs = _elapsed.elapsedMilliseconds;
    final CameraMacOSController? controller = _controller;
    if (controller == null) {
      throw const VideoRecorderException(videoStopMessage);
    }
    try {
      final CaptureMedia? thumbnail = await _captureThumbnail(controller);
      final CameraMacOSFile? file = await controller.stopRecording();
      final String? path = file?.url;
      if (path == null || path.isEmpty) {
        throw const VideoRecorderException(videoStopMessage);
      }
      final VideoRecording recording = VideoRecording(
        media: CaptureFile(
          file: File(path),
          mime: videoRecordingMime,
          durationMs: durationMs,
        ),
        durationMs: durationMs,
        thumbnail: thumbnail,
      );
      _owned = _owned.adopt(recording);
      return recording;
    } on VideoRecorderException {
      rethrow;
    } catch (error) {
      throw VideoRecorderException(videoStopMessage, cause: error);
    }
  }

  Future<CaptureMedia?> _captureThumbnail(
    CameraMacOSController controller,
  ) async {
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
      return CaptureFile(file: file, mime: videoThumbnailMime);
    } catch (error, stackTrace) {
      debugPrint('Video thumbnail capture failed: $error\n$stackTrace');
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    _elapsed.stop();
    _aborted = true;
    _destroyRequested = true;
    final CameraMacOSController? controller = _controller;
    _controller = null;
    _preview = null;
    _previewDeviceId = null;
    _ready = null;
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
    _elapsed.stop();
    _destroyRequested = true;
    final CameraMacOSController? controller = _controller;
    _controller = null;
    _preview = null;
    _previewDeviceId = null;
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
  }
}

const double videoHardCapSeconds = 30 * 60;
const Duration cameraStartTimeout = Duration(seconds: 12);
const String _cameraPermissionRefusal = 'Permission not granted';
