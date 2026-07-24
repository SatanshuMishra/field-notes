import 'package:flutter/widgets.dart';

import 'package:field_notes/domain/services/capture_service.dart';

const String cameraPermissionMessage =
    'Field Notes needs camera and microphone access to record video. Turn them '
    'on in your system settings and try again.';
const String videoStartMessage =
    'Could not start recording. Check your camera and try again.';
const String videoStartTimeoutMessage =
    'The camera did not respond. Make sure Field Notes has camera access in '
    'System Settings, then try again.';
const String videoStopMessage =
    'Could not finish that recording. Nothing was saved — please try again.';
const String videoDeviceListMessage =
    'Could not find a camera. Connect one and try again.';
const String videoDeviceSwitchMessage =
    'Could not switch cameras. Try picking one again.';

class VideoCaptureDevice {
  const VideoCaptureDevice({required this.id, required this.label});

  final String id;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is VideoCaptureDevice && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);

  @override
  String toString() => 'VideoCaptureDevice($id, $label)';
}

class VideoRecording {
  const VideoRecording({
    required this.media,
    required this.durationMs,
    this.thumbnail,
  });

  final CaptureMedia media;
  final int durationMs;
  final CaptureMedia? thumbnail;
}

class VideoRecorderException implements Exception {
  const VideoRecorderException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'VideoRecorderException: $message'
      : 'VideoRecorderException: $message ($cause)';
}

abstract interface class VideoRecorder {
  Future<bool> hasPermission();

  Future<List<VideoCaptureDevice>> listDevices();

  Future<void> start();

  Future<VideoRecording> stop();

  Future<void> cancel();

  Future<void> release();

  Future<void> dispose();

  Widget buildPreview(String deviceId);
}
