import 'package:field_notes/data/media/live_audio_channel.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'record_voice_recorder.dart';
import 'voice_processing.dart';
import 'voice_recorder.dart';

final Provider<VoiceRecorder> voiceRecorderProvider = Provider<VoiceRecorder>(
  (Ref ref) => RecordVoiceRecorder(
    encoder: ref.read(liveEncoderProvider),
    resolveInput: () {
      ref.invalidate(selectedAudioInputProvider);
      return ref.read(selectedAudioInputProvider.future);
    },
    resolveProcessing: voiceProcessingFromSettings(ref),
  ),
);
