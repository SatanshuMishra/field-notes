import 'dart:async';

import 'package:field_notes/data/media/live_audio_channel.dart';
import 'package:field_notes/domain/settings/app_settings.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'record_voice_recorder.dart';
import 'voice_recorder.dart';

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

final Provider<VoiceRecorder> voiceRecorderProvider = Provider<VoiceRecorder>(
  (Ref ref) => RecordVoiceRecorder(
    encoder: ref.read(liveEncoderProvider),
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
