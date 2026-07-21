import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'record_voice_recorder.dart';
import 'voice_recorder.dart';

final Provider<VoiceRecorder> voiceRecorderProvider =
    Provider<VoiceRecorder>((Ref ref) => RecordVoiceRecorder());
