import 'dart:io';
import 'dart:ui';

import 'package:field_notes/domain/models/media_kind.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

@immutable
final class MediaMeasure {
  const MediaMeasure({this.duration, this.width, this.height});

  final Duration? duration;
  final int? width;
  final int? height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaMeasure &&
          duration == other.duration &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(duration, width, height);

  @override
  String toString() =>
      'MediaMeasure(duration: $duration, width: $width, height: $height)';
}

abstract interface class MediaProbe {
  Future<MediaMeasure?> measure({required File file, required MediaKind kind});
}

Size? uprightSizeOf(Size coded, int rotationDegrees) {
  if (coded.isEmpty || !coded.isFinite) {
    return null;
  }
  final int turn = rotationDegrees % 360;
  if (turn == 90 || turn == 270) {
    return coded.flipped;
  }
  return coded;
}

class PlatformMediaProbe implements MediaProbe {
  const PlatformMediaProbe();

  @override
  Future<MediaMeasure?> measure({
    required File file,
    required MediaKind kind,
  }) => switch (kind) {
    MediaKind.video => _measureVideo(file),
    MediaKind.audio => _measureAudio(file),
    MediaKind.photo => Future<MediaMeasure?>.value(),
  };

  Future<MediaMeasure?> _measureVideo(File file) async {
    final VideoPlayerController controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      final VideoPlayerValue value = controller.value;
      final Size? upright = uprightSizeOf(value.size, value.rotationCorrection);
      return MediaMeasure(
        duration: value.duration,
        width: upright?.width.round(),
        height: upright?.height.round(),
      );
    } finally {
      await controller.dispose();
    }
  }

  Future<MediaMeasure?> _measureAudio(File file) async {
    final AudioPlayer player = AudioPlayer(
      handleInterruptions: false,
      androidApplyAudioAttributes: false,
      handleAudioSessionActivation: false,
    );
    try {
      return MediaMeasure(duration: await player.setFilePath(file.path));
    } finally {
      await player.dispose();
    }
  }
}
