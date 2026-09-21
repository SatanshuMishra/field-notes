import 'dart:math' as math;

const int decodeBucketPixels = 64;

int? decodeTargetWidth({
  required double? logicalWidth,
  required double devicePixelRatio,
}) {
  final double? width = logicalWidth;
  if (width == null || !width.isFinite || width <= 0) {
    return null;
  }
  final double ratio =
      devicePixelRatio.isFinite && devicePixelRatio > 0 ? devicePixelRatio : 1;
  final double physical = width * ratio;
  final int buckets = math.max(1, (physical / decodeBucketPixels).ceil());
  return buckets * decodeBucketPixels;
}
