import 'package:field_notes/domain/settings/app_settings.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef VoiceProcessing = ({InputProfile profile, int volume});

const Duration _settingsWait = Duration(seconds: 1);

Future<VoiceProcessing> defaultVoiceProcessing() async => (
  profile: AppSettings.defaults.inputProfile,
  volume: AppSettings.defaults.inputVolume,
);

Future<AudioInput> systemDefaultAudioInput() async =>
    const AudioInput(id: null, label: systemDefaultInputLabel);

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

Future<VoiceProcessing> Function() voiceProcessingFromSettings(Ref ref) =>
    () async {
      final AppSettings settings = await _currentSettings(ref);
      return (profile: settings.inputProfile, volume: settings.inputVolume);
    };
