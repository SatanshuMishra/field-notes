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
  Future<void> start() async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw const VideoRecorderException(videoStartMessage);
      }
      final CameraController controller = CameraController(
        cameras.first,
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
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }

  @override
  Widget buildPreview() {
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(controller);
  }
}

class CameraMacosVideoRecorder implements VideoRecorder {
  final Completer<CameraMacOSController> _ready =
      Completer<CameraMacOSController>();
  final Stopwatch _elapsed = Stopwatch();
  CameraMacOSController? _controller;

  @override
  Future<bool> hasPermission() async {
    try {
      final List<CameraMacOSDevice> videoDevices = await CameraMacOS.instance
          .listDevices(deviceType: CameraMacOSDeviceType.video);
      return videoDevices.isNotEmpty;
    } catch (error) {
      return false;
    }
  }

  @override
  Future<void> start() async {
    try {
      final CameraMacOSController controller = await _ready.future;
      await controller.recordVideo(
        maxVideoDuration: videoHardCapSeconds,
      );
      _controller = controller;
      _elapsed
        ..reset()
        ..start();
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
    } finally {
      _controller = null;
    }
  }

  @override
  Future<void> cancel() async {
    _elapsed.stop();
    final CameraMacOSController? controller = _controller;
    _controller = null;
    if (controller == null) {
      return;
    }
    try {
      await controller.stopRecording();
    } catch (error) {
      return;
    }
  }

  @override
  Future<void> dispose() async {
    _controller = null;
  }

  @override
  Widget buildPreview() {
    return CameraMacOSView(
      cameraMode: CameraMacOSMode.video,
      fit: BoxFit.cover,
      onCameraInizialized: (CameraMacOSController controller) {
        if (!_ready.isCompleted) {
          _ready.complete(controller);
        }
      },
    );
  }
}

const double videoHardCapSeconds = 30 * 60;
