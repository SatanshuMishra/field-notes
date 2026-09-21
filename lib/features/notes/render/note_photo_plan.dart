import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../model/photo_placement.dart';

const double photoGutterEm = 1;
const double photoBandResidualEm = 19.4;
const double photoMinFloatEm = 8.5;
const double photoHeightClamp = 1.6;
const double photoFallbackAspect = 3 / 2;

@immutable
final class PhotoPlan {
  const PhotoPlan({
    required this.side,
    required this.size,
    required this.measure,
    required this.width,
    required this.height,
    required this.isStacked,
    required this.measureCanFloat,
  });

  final PhotoSide side;
  final PhotoSize size;
  final double measure;
  final double width;
  final double height;
  final bool isStacked;
  final bool measureCanFloat;

  bool get sideApplies => measureCanFloat && size != PhotoSize.full;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoPlan &&
          side == other.side &&
          size == other.size &&
          measure == other.measure &&
          width == other.width &&
          height == other.height &&
          isStacked == other.isStacked &&
          measureCanFloat == other.measureCanFloat;

  @override
  int get hashCode => Object.hash(
        side,
        size,
        measure,
        width,
        height,
        isStacked,
        measureCanFloat,
      );

  @override
  String toString() => 'PhotoPlan(${side.name} ${size.name}, '
      '${width.toStringAsFixed(1)}x${height.toStringAsFixed(1)} of '
      '${measure.toStringAsFixed(1)}, '
      '${isStacked ? 'stacked' : 'floated'})';
}

bool canFloatAt({required double measure, required double em}) {
  if (!measure.isFinite || !em.isFinite || em <= 0) {
    return false;
  }
  final double cap = measure - (photoGutterEm + photoBandResidualEm) * em;
  return cap >= photoMinFloatEm * em;
}

double? photoAspectOf(int? width, int? height) {
  if (width == null || height == null || width <= 0 || height <= 0) {
    return null;
  }
  return width / height;
}

PhotoPlan planFloat({
  required double measure,
  required double em,
  required PhotoSide side,
  required PhotoSize size,
  double? aspect,
}) {
  final double column = measure.isFinite && measure > 0 ? measure : 0;
  final double ratio = aspect != null && aspect.isFinite && aspect > 0
      ? aspect
      : photoFallbackAspect;
  final double width = column * size.measureFraction;
  return PhotoPlan(
    side: side,
    size: size,
    measure: column,
    width: width,
    height: math.min(width / ratio, photoHeightClamp * width),
    isStacked: true,
    measureCanFloat: canFloatAt(measure: column, em: em),
  );
}
