import 'dart:math' as math;
import 'dart:typed_data';

import 'package:field_notes/data/media/jpeg_resize.dart';

import 'photo_intrinsics.dart';
import 'photo_picker.dart';

const int photoLongEdgeTarget = 2048;
const String downscaledPhotoMime = 'image/jpeg';
const int photoJpegQuality = 82;

class DownscaledPhoto {
  const DownscaledPhoto({
    required this.bytes,
    required this.mime,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final String mime;
  final int width;
  final int height;
}

bool photoNeedsDownscale(PhotoIntrinsics intrinsics) =>
    intrinsics.longEdge > photoLongEdgeTarget;

PhotoIntrinsics downscaleTargetFor(PhotoIntrinsics intrinsics) {
  if (!photoNeedsDownscale(intrinsics)) {
    return intrinsics;
  }
  final double scale = photoLongEdgeTarget / intrinsics.longEdge;
  return PhotoIntrinsics(
    width: math.max(1, (intrinsics.width * scale).round()),
    height: math.max(1, (intrinsics.height * scale).round()),
  );
}

Future<DownscaledPhoto> downscalePhoto({
  required Uint8List bytes,
  required String mime,
  required PhotoIntrinsics intrinsics,
}) async {
  if (!photoNeedsDownscale(intrinsics)) {
    return DownscaledPhoto(
      bytes: bytes,
      mime: mime,
      width: intrinsics.width,
      height: intrinsics.height,
    );
  }

  try {
    final ResizedJpeg resized = await resizeToJpeg(
      bytes: bytes,
      sourceWidth: intrinsics.width,
      sourceHeight: intrinsics.height,
      longEdge: photoLongEdgeTarget,
      quality: photoJpegQuality,
    );
    return DownscaledPhoto(
      bytes: resized.bytes,
      mime: downscaledPhotoMime,
      width: resized.width,
      height: resized.height,
    );
  } catch (error) {
    throw PhotoPickException(undecodablePhotoMessage, cause: error);
  }
}
