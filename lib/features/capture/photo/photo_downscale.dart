import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'photo_intrinsics.dart';
import 'photo_picker.dart';

const int photoLongEdgeTarget = 2048;
const String downscaledPhotoMime = 'image/png';

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

  final PhotoIntrinsics target = downscaleTargetFor(intrinsics);
  ui.Codec? codec;
  ui.FrameInfo? frame;
  try {
    codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: target.width,
      targetHeight: target.height,
    );
    frame = await codec.getNextFrame();
    final ByteData? encoded =
        await frame.image.toByteData(format: ui.ImageByteFormat.png);
    if (encoded == null) {
      throw const PhotoPickException(undecodablePhotoMessage);
    }
    return DownscaledPhoto(
      bytes: encoded.buffer.asUint8List(
        encoded.offsetInBytes,
        encoded.lengthInBytes,
      ),
      mime: downscaledPhotoMime,
      width: frame.image.width,
      height: frame.image.height,
    );
  } on PhotoPickException {
    rethrow;
  } catch (error) {
    throw PhotoPickException(undecodablePhotoMessage, cause: error);
  } finally {
    frame?.image.dispose();
    codec?.dispose();
  }
}
