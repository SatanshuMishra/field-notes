import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/data/media/live_audio_channel.dart';
import 'package:field_notes/domain/settings/app_settings.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/state/settings_providers.dart';

import 'video_recorder.dart';

const Duration _settingsWait = Duration(seconds: 1);

Future<AppSettings> _currentSettings(Ref ref) async {
  final AppSettings? loaded = ref.read(appSettingsProvider).value;
  if (loaded != null) {
    return loaded;
  }
  try {
    return await ref.read(appSettingsProvider.future).timeout(_settingsWait);
  } catch (_) {
    return AppSettings.defaults;
  }
}

final Provider<VideoRecorder> videoRecorderProvider = Provider<VideoRecorder>(
  (Ref ref) => createPlatformVideoRecorder(
    encoder: ref.read(liveEncoderProvider),
    audioJoiner: ref.read(audioJoinerProvider),
    resolveInput: () {
      ref.invalidate(selectedAudioInputProvider);
      return ref.read(selectedAudioInputProvider.future);
    },
    resolveProcessing: () async {
      final AppSettings settings = await _currentSettings(ref);
      return (profile: settings.inputProfile, volume: settings.inputVolume);
    },
  ),
);
