import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/widgets.dart';

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

VideoRecorder createPlatformVideoRecorder() =>
    Platform.isMacOS ? CameraMacosVideoRecorder() : CameraVideoRecorder();

class CameraVideoRecorder implements VideoRecorder {
  CameraController? _controller;
  String? _deviceId;
  final Stopwatch _elapsed = Stopwatch();

  @override
  Future<bool> hasPermission() async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      return cameras.isNotEmpty;
    } on CameraException {
      return false;
    }
  }

  @override
  Future<List<VideoCaptureDevice>> listDevices() async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      return <VideoCaptureDevice>[
        for (final CameraDescription camera in cameras)
          VideoCaptureDevice(id: camera.name, label: camera.name),
      ];
    } catch (error) {
      throw VideoRecorderException(videoDeviceListMessage, cause: error);
    }
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
  Widget buildPreview(String deviceId) {
    _deviceId = deviceId;
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
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

class CameraMacosVideoRecorder implements VideoRecorder {
  final Stopwatch _elapsed = Stopwatch();
  Completer<CameraMacOSController>? _ready;
  Widget? _preview;
  String? _previewDeviceId;
  CameraMacOSController? _controller;

  Completer<CameraMacOSController> _session() =>
      _ready ??= Completer<CameraMacOSController>();

  @override
  Future<bool> hasPermission() async {
    try {
      final List<VideoCaptureDevice> devices = await listDevices();
      return devices.isNotEmpty;
    } catch (error) {
      return false;
    }
  }

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
  Future<void> start() async {
    final Completer<CameraMacOSController> ready = _session();
    try {
      final CameraMacOSController controller =
          await ready.future.timeout(cameraStartTimeout);
      await controller.recordVideo(
        maxVideoDuration: videoHardCapSeconds,
      );
      _controller = controller;
      _elapsed
        ..reset()
        ..start();
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
      );
    } on VideoRecorderException {
      rethrow;
    } catch (error) {
      throw VideoRecorderException(videoStopMessage, cause: error);
    }
  }

  @override
  Future<void> cancel() async {
    _elapsed.stop();
    final CameraMacOSController? controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      await controller.stopRecording();
    } catch (error, stackTrace) {
      debugPrint('Video cancel failed: $error\n$stackTrace');
    }
  }

  @override
  Future<void> release() async {
    _elapsed.stop();
    final CameraMacOSController? controller = _controller;
    _resetSession();
    if (controller == null) {
      return;
    }
    try {
      await controller.destroy();
    } catch (error, stackTrace) {
      debugPrint('Camera release failed: $error\n$stackTrace');
    }
  }

  @override
  Future<void> dispose() async {
    await release();
  }

  @override
  Widget buildPreview(String deviceId) {
    final Widget? existing = _preview;
    if (existing != null && _previewDeviceId == deviceId) {
      return existing;
    }
    final Completer<CameraMacOSController> ready =
        Completer<CameraMacOSController>();
    _ready = ready;
    final Widget view = CameraMacOSView(
      key: ValueKey<String>('camera-preview-$deviceId'),
      deviceId: deviceId,
      cameraMode: CameraMacOSMode.video,
      fit: BoxFit.cover,
      useMovieFileOutput: true,
      onCameraInizialized: (CameraMacOSController controller) {
        _controller = controller;
        if (!ready.isCompleted) {
          ready.complete(controller);
        }
      },
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

  void _resetSession() {
    _controller = null;
    _preview = null;
    _previewDeviceId = null;
    _ready = null;
  }
}

const double videoHardCapSeconds = 30 * 60;
const Duration cameraStartTimeout = Duration(seconds: 12);
