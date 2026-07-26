import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';

const String videoRecordingMime = 'video/mp4';
const String videoRecordingExtension = 'mp4';
const String videoThumbnailMime = 'image/jpeg';
const String videoThumbnailExtension = 'jpg';

String videoRecordingFileName(int nowMs) =>
    'video_$nowMs.$videoRecordingExtension';

String videoThumbnailFileName(int nowMs) =>
    'video_thumb_$nowMs.$videoThumbnailExtension';

Future<String> resolveVideoThumbnailPath(Directory directory, int nowMs) async {
  await directory.create(recursive: true);
  return p.join(directory.path, videoThumbnailFileName(nowMs));
}

VideoRecorder createPlatformVideoRecorder() =>
    Platform.isMacOS ? CameraMacosVideoRecorder() : CameraVideoRecorder();

class CameraVideoRecorder implements VideoRecorder {
  CameraController? _controller;
  String? _deviceId;
  final Stopwatch _elapsed = Stopwatch();

  @override
  Future<List<VideoCaptureDevice>> listDevices() async {
    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (error) {
      throw VideoRecorderException(videoDeviceListMessage, cause: error);
    }
    return cameraDeviceLabels(cameras);
  }

  @override
  Future<void> start() async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw const VideoRecorderException(videoStartMessage);
      }
      final CameraController controller = CameraController(
        _selected(cameras),
        ResolutionPreset.high,
        enableAudio: true,
      );
      await controller.initialize();
      await controller.startVideoRecording();
      _controller = controller;
      _elapsed
        ..reset()
        ..start();
    } on VideoRecorderException {
      _elapsed.stop();
      rethrow;
    } catch (error) {
      _elapsed.stop();
      throw VideoRecorderException(videoStartMessage, cause: error);
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
      final CaptureMedia? thumbnail = await _captureThumbnail(controller);
      final XFile file = await controller.stopVideoRecording();
      return VideoRecording(
        media: CaptureFile(
          file: File(file.path),
          mime: videoRecordingMime,
          durationMs: durationMs,
        ),
        durationMs: durationMs,
        thumbnail: thumbnail,
      );
    } on VideoRecorderException {
      rethrow;
    } catch (error) {
      throw VideoRecorderException(videoStopMessage, cause: error);
    } finally {
      await controller.dispose();
      _controller = null;
    }
  }

  Future<CaptureMedia?> _captureThumbnail(CameraController controller) async {
    try {
      final XFile still = await controller.takePicture();
      return CaptureFile(file: File(still.path), mime: videoThumbnailMime);
    } catch (error) {
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    _elapsed.stop();
    final CameraController? controller = _controller;
    _controller = null;
    if (controller == null) {
      return;
    }
    try {
      if (controller.value.isRecordingVideo) {
        await controller.stopVideoRecording();
      }
    } on CameraException {
      return;
    } finally {
      await controller.dispose();
    }
  }

  @override
  Future<void> release() async {
    _elapsed.stop();
    final CameraController? controller = _controller;
    _controller = null;
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
    _deviceId = deviceId;
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return null;
    }
    return CameraPreview(controller);
  }

  CameraDescription _selected(List<CameraDescription> cameras) {
    final String? deviceId = _deviceId;
    for (final CameraDescription camera in cameras) {
      if (camera.name == deviceId) {
        return camera;
      }
    }
    return cameras.first;
  }
}

List<VideoCaptureDevice> cameraDeviceLabels(List<CameraDescription> cameras) {
  final Map<CameraLensDirection, int> seen = <CameraLensDirection, int>{};
  final Map<CameraLensDirection, int> totals = <CameraLensDirection, int>{};
  for (final CameraDescription camera in cameras) {
    totals[camera.lensDirection] = (totals[camera.lensDirection] ?? 0) + 1;
  }
  return <VideoCaptureDevice>[
    for (final CameraDescription camera in cameras)
      VideoCaptureDevice(
        id: camera.name,
        label: _cameraLabel(
          camera.lensDirection,
          index: seen[camera.lensDirection] =
              (seen[camera.lensDirection] ?? 0) + 1,
          total: totals[camera.lensDirection] ?? 1,
        ),
      ),
  ];
}

String _cameraLabel(
  CameraLensDirection direction, {
  required int index,
  required int total,
}) {
  final String base = switch (direction) {
    CameraLensDirection.front => 'Front camera',
    CameraLensDirection.back => 'Back camera',
    CameraLensDirection.external => 'External camera',
  };
  return total > 1 ? '$base $index' : base;
}

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

  @override
  Future<List<VideoCaptureDevice>> listDevices() async {
    final List<CameraMacOSDevice> devices;
    try {
      devices = await CameraMacOS.instance
          .listDevices(deviceType: CameraMacOSDeviceType.video);
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
      fit: BoxFit.cover,
      useMovieFileOutput: true,
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
      return VideoRecording(
        media: CaptureFile(
          file: File(path),
          mime: videoRecordingMime,
          durationMs: durationMs,
        ),
        durationMs: durationMs,
        thumbnail: thumbnail,
      );
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
      await _deleteIfPresent(file?.url);
    } catch (error, stackTrace) {
      debugPrint('Video discard failed: $error\n$stackTrace');
    }
    await _destroy(controller);
  }

  Future<void> _deleteIfPresent(String? path) async {
    if (path == null || path.isEmpty) {
      return;
    }
    try {
      final File file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error, stackTrace) {
      debugPrint('Discarded recording delete failed: $error\n$stackTrace');
    }
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
