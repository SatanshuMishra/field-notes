import 'dart:io';

import 'package:field_notes/domain/models/media_kind.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

abstract interface class MediaDurationProbe {
  Future<Duration?> duration({required File file, required MediaKind kind});
}

class PlatformMediaDurationProbe implements MediaDurationProbe {
  const PlatformMediaDurationProbe();

  @override
  Future<Duration?> duration({required File file, required MediaKind kind}) =>
      switch (kind) {
        MediaKind.video => _videoDuration(file),
        MediaKind.audio => _audioDuration(file),
        MediaKind.photo => Future<Duration?>.value(),
      };

  Future<Duration?> _videoDuration(File file) async {
    final VideoPlayerController controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      return controller.value.duration;
    } finally {
      await controller.dispose();
    }
  }

  Future<Duration?> _audioDuration(File file) async {
    final AudioPlayer player = AudioPlayer(
      handleInterruptions: false,
      androidApplyAudioAttributes: false,
      handleAudioSessionActivation: false,
    );
    try {
      return await player.setFilePath(file.path);
    } finally {
      await player.dispose();
    }
  }
}
