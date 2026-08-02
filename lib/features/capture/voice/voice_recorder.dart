import 'package:field_notes/domain/services/capture_service.dart';

const String micPermissionMessage =
    'Field Notes needs microphone access to record. Turn it on in your system '
    'settings and try again.';
const String recordStartMessage =
    'Could not start recording. Check your microphone and try again.';
const String recordStopMessage =
    'Could not finish that recording. Nothing was saved — please try again.';

class VoiceRecording {
  const VoiceRecording({required this.media, required this.durationMs});

  final CaptureMedia media;
  final int durationMs;
}

class VoiceRecorderException implements Exception {
  const VoiceRecorderException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'VoiceRecorderException: $message'
      : 'VoiceRecorderException: $message ($cause)';
}

abstract interface class VoiceRecorder {
  Duration get elapsed;

  Future<bool> hasPermission();

  Future<void> start();

  Future<VoiceRecording> stop();

  Future<void> cancel();

  Future<void> dispose();
}
