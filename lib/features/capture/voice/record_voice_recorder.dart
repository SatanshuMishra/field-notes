import 'dart:io';

import 'package:field_notes/domain/services/capture_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'voice_recorder.dart';

const String voiceRecordingMime = 'audio/mp4';
const String voiceRecordingExtension = 'm4a';
const AudioEncoder voiceRecordingEncoder = AudioEncoder.aacLc;

String voiceRecordingFileName(int nowMs) =>
    'voice_$nowMs.$voiceRecordingExtension';

Future<String> resolveVoiceRecordingPath(Directory directory, int nowMs) async {
  await directory.create(recursive: true);
  return p.join(directory.path, voiceRecordingFileName(nowMs));
}

class RecordVoiceRecorder implements VoiceRecorder {
  RecordVoiceRecorder({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final Stopwatch _elapsed = Stopwatch();
  String? _activePath;

  @override
  Duration get elapsed => _elapsed.elapsed;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    try {
      final Directory directory = await getTemporaryDirectory();
      final String path = await resolveVoiceRecordingPath(
        directory,
        DateTime.now().millisecondsSinceEpoch,
      );
      _elapsed
        ..reset()
        ..start();
      await _recorder.start(
        const RecordConfig(encoder: voiceRecordingEncoder),
        path: path,
      );
      _activePath = path;
    } catch (error) {
      _elapsed.stop();
      throw VoiceRecorderException(recordStartMessage, cause: error);
    }
  }

  @override
  Future<VoiceRecording> stop() async {
    _elapsed.stop();
    final int durationMs = _elapsed.elapsedMilliseconds;
    try {
      final String? stopped = await _recorder.stop();
      final String resolved = stopped ?? _activePath ?? '';
      if (resolved.isEmpty) {
        throw const VoiceRecorderException(recordStopMessage);
      }
      return VoiceRecording(
        media: CaptureFile(
          file: File(resolved),
          mime: voiceRecordingMime,
          durationMs: durationMs,
        ),
        durationMs: durationMs,
      );
    } on VoiceRecorderException {
      rethrow;
    } catch (error) {
      throw VoiceRecorderException(recordStopMessage, cause: error);
    }
  }

  @override
  Future<void> cancel() async {
    _elapsed.stop();
    await _recorder.cancel();
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
