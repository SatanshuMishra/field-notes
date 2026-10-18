import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/data/media/live_audio_channel.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_processing.dart';

import 'video_recorder.dart';

final Provider<VideoRecorder> videoRecorderProvider = Provider<VideoRecorder>(
  (Ref ref) => createPlatformVideoRecorder(
    encoder: ref.read(liveEncoderProvider),
    audioJoiner: ref.read(audioJoinerProvider),
    resolveInput: () {
      ref.invalidate(selectedAudioInputProvider);
      return ref.read(selectedAudioInputProvider.future);
    },
    resolveProcessing: voiceProcessingFromSettings(ref),
  ),
);
