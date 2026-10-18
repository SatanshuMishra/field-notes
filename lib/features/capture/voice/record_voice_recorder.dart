import 'dart:async';
import 'dart:io';

import 'package:field_notes/data/media/live_audio_channel.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/live_audio_capture.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'voice_processing.dart';
import 'voice_recorder.dart';

const String voiceRecordingMime = 'audio/mp4';
const String voiceRecordingExtension = 'm4a';

String voiceRecordingFileName(int nowMs) =>
    'voice_$nowMs.$voiceRecordingExtension';

Future<String> resolveVoiceRecordingPath(Directory directory, int nowMs) async {
  await directory.create(recursive: true);
  return p.join(directory.path, voiceRecordingFileName(nowMs));
}

class RecordVoiceRecorder implements VoiceRecorder {
  RecordVoiceRecorder({
    AudioRecorder? recorder,
    LiveEncoder encoder = const LiveEncoder(),
    VoiceChainRunner chainRunner = runVoiceChainInIsolate,
    Future<Directory> Function()? temporaryDirectory,
    Future<AudioInput> Function()? resolveInput,
    Future<VoiceProcessing> Function()? resolveProcessing,
  }) : _capture = LiveAudioCapture(
         recorderFactory: () => recorder ?? AudioRecorder(),
         encoder: encoder,
         chainRunner: chainRunner,
       ),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _resolveInput = resolveInput ?? systemDefaultAudioInput,
       _resolveProcessing = resolveProcessing ?? defaultVoiceProcessing;

  final LiveAudioCapture _capture;
  final Future<AudioInput> Function() _resolveInput;
  final Future<VoiceProcessing> Function() _resolveProcessing;
  final Future<Directory> Function() _temporaryDirectory;
  final Stopwatch _elapsed = Stopwatch();
  LiveAudioTake? _lastTake;
  Map<String, VoiceRecording> _owned = const <String, VoiceRecording>{};

  @override
  Stream<double> get level => _capture.level;

  @override
  Duration get elapsed => _elapsed.elapsed;

  @override
  Future<bool> hasPermission() => _capture.hasPermission();

  Future<AudioInput> _resolveInputOrDefault() async {
    try {
      return await _resolveInput();
    } catch (_) {
      return systemDefaultAudioInput();
    }
  }

  Future<VoiceProcessing> _resolveProcessingOrDefault() async {
    try {
      return await _resolveProcessing();
    } catch (_) {
      return defaultVoiceProcessing();
    }
  }

  @override
  Future<void> start() async {
    try {
      final Directory directory = await _temporaryDirectory();
      final String path = await resolveVoiceRecordingPath(
        directory,
        DateTime.now().millisecondsSinceEpoch,
      );
      final AudioInput input = await _resolveInputOrDefault();
      final VoiceProcessing processing = await _resolveProcessingOrDefault();
      _elapsed.reset();
      _lastTake = null;
      await _capture.start(
        input: input,
        profile: processing.profile,
        volume: processing.volume,
        path: path,
      );
      _elapsed.start();
    } catch (error) {
      _elapsed.stop();
      throw VoiceRecorderException(recordStartMessage, cause: error);
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _capture.pause();
      _elapsed.stop();
    } catch (error) {
      throw VoiceRecorderException(recordPauseMessage, cause: error);
    }
  }

  @override
  Future<void> resume() async {
    try {
      await _capture.resume();
      _elapsed.start();
    } catch (error) {
      throw VoiceRecorderException(recordPauseMessage, cause: error);
    }
  }

  Future<LiveAudioTake> _finishedTake() async {
    final LiveAudioTake? last = _lastTake;
    if (!_capture.running && last != null) {
      return last;
    }
    final LiveAudioTake take = await _capture.stop();
    _lastTake = take;
    return take;
  }

  @override
  Future<VoiceRecording> stop() async {
    _elapsed.stop();
    try {
      final LiveAudioTake take = await _finishedTake();
      final VoiceRecording recording = VoiceRecording(
        media: CaptureFile(
          file: File(take.path),
          mime: voiceRecordingMime,
          durationMs: take.durationMs,
        ),
        durationMs: take.durationMs,
      );
      _owned = <String, VoiceRecording>{..._owned, take.path: recording};
      return recording;
    } catch (error) {
      throw VoiceRecorderException(recordStopMessage, cause: error);
    }
  }

  @override
  Future<void> releaseSaved(VoiceRecording recording) async {
    final CaptureMedia media = recording.media;
    if (media is! CaptureFile ||
        !identical(_owned[media.file.path], recording)) {
      return;
    }
    _owned = <String, VoiceRecording>{
      for (final MapEntry<String, VoiceRecording> entry in _owned.entries)
        if (entry.key != media.file.path) entry.key: entry.value,
    };
    try {
      if (await media.file.exists()) {
        await media.file.delete();
      }
    } catch (error, stackTrace) {
      debugPrint('Saved recording delete failed: $error\n$stackTrace');
    }
  }

  @override
  Future<void> cancel() async {
    _elapsed.stop();
    _lastTake = null;
    await _capture.cancel();
  }

  @override
  Future<void> dispose() async {
    _elapsed.stop();
    await _capture.dispose();
  }
}
