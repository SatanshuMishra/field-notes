import 'dart:async';
import 'dart:io';

import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'voice_level.dart';
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
  RecordVoiceRecorder({
    AudioRecorder? recorder,
    Future<Directory> Function()? temporaryDirectory,
    Future<AudioInput> Function()? resolveInput,
  }) : _recorder = recorder ?? AudioRecorder(),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _resolveInput = resolveInput ?? _systemDefaultInput;

  static Future<AudioInput> _systemDefaultInput() async =>
      const AudioInput(id: null, label: systemDefaultInputLabel);

  final AudioRecorder _recorder;
  final Future<AudioInput> Function() _resolveInput;
  final Future<Directory> Function() _temporaryDirectory;
  final Stopwatch _elapsed = Stopwatch();
  String? _activePath;
  Map<String, VoiceRecording> _owned = const <String, VoiceRecording>{};

  late final StreamController<double> _levels =
      StreamController<double>.broadcast(
        onListen: _listenToAmplitude,
        onCancel: _stopListeningToAmplitude,
      );
  late final Stream<double> _levelStream = _levels.stream;
  Stream<Amplitude>? _amplitudes;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  void _listenToAmplitude() {
    final Stream<Amplitude> amplitudes = _amplitudes ??= _recorder
        .onAmplitudeChanged(voiceLevelInterval);
    _amplitudeSubscription = amplitudes.listen(
      (Amplitude amplitude) =>
          _levels.add(voiceLevelFromDbfs(amplitude.current)),
    );
  }

  Future<void> _stopListeningToAmplitude() async {
    final StreamSubscription<Amplitude>? subscription = _amplitudeSubscription;
    _amplitudeSubscription = null;
    await subscription?.cancel();
  }

  @override
  Stream<double> get level => _levelStream;

  @override
  Duration get elapsed => _elapsed.elapsed;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<AudioInput> _resolveInputOrDefault() async {
    try {
      return await _resolveInput();
    } catch (_) {
      return _systemDefaultInput();
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
      final String? inputId = input.id;
      _elapsed
        ..reset()
        ..start();
      await _recorder.start(
        RecordConfig(
          encoder: voiceRecordingEncoder,
          numChannels: 1,
          bitRate: 48000,
          device: inputId == null
              ? null
              : InputDevice(id: inputId, label: input.label),
        ),
        path: path,
      );
      _activePath = path;
    } catch (error) {
      _elapsed.stop();
      throw VoiceRecorderException(recordStartMessage, cause: error);
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _recorder.pause();
      _elapsed.stop();
    } catch (error) {
      throw VoiceRecorderException(recordPauseMessage, cause: error);
    }
  }

  @override
  Future<void> resume() async {
    try {
      await _recorder.resume();
      _elapsed.start();
    } catch (error) {
      throw VoiceRecorderException(recordPauseMessage, cause: error);
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
      final VoiceRecording recording = VoiceRecording(
        media: CaptureFile(
          file: File(resolved),
          mime: voiceRecordingMime,
          durationMs: durationMs,
        ),
        durationMs: durationMs,
      );
      _owned = <String, VoiceRecording>{..._owned, resolved: recording};
      return recording;
    } on VoiceRecorderException {
      rethrow;
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
    await _recorder.cancel();
  }

  @override
  Future<void> dispose() async {
    await _stopListeningToAmplitude();
    await _levels.close();
    await _recorder.dispose();
  }
}
