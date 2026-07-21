import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';

import 'video_recorder.dart';

final Provider<VideoRecorder> videoRecorderProvider =
    Provider<VideoRecorder>((Ref ref) => createPlatformVideoRecorder());
