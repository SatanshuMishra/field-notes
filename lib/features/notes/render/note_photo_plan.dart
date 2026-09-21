import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import '../model/photo_placement.dart';

const double photoGutterEm = 1;
const double photoBandResidualEm = 19.4;
const double photoMinFloatEm = 8.5;
const double photoHeightClamp = 1.6;
const double photoFallbackAspect = 3 / 2;

final double photoLineEm = TypographyTokens.noteBody.height ?? 1;

extension PhotoSizeFloat on PhotoSize {
  double? get floatEm => switch (this) {
        PhotoSize.small => 8.5,
        PhotoSize.medium => 12,
        PhotoSize.large => 14.5,
        PhotoSize.full => null,
      };
}

@immutable
final class PhotoPlan {
  const PhotoPlan({
    required this.side,
    required this.size,
    required this.measure,
    required this.width,
    required this.height,
    required this.band,
    required this.gutter,
    required this.isStacked,
    required this.measureCanFloat,
  });

  final PhotoSide side;
  final PhotoSize size;
  final double measure;
  final double width;
  final double height;
  final double band;
  final double gutter;
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
          band == other.band &&
          gutter == other.gutter &&
          isStacked == other.isStacked &&
          measureCanFloat == other.measureCanFloat;

  @override
  int get hashCode => Object.hash(
        side,
        size,
        measure,
        width,
        height,
        band,
        gutter,
        isStacked,
        measureCanFloat,
      );

  @override
  String toString() => 'PhotoPlan(${side.name} ${size.name}, '
      '${width.toStringAsFixed(1)}x${height.toStringAsFixed(1)} of '
      '${measure.toStringAsFixed(1)}, '
      '${isStacked ? 'stacked' : 'floated beside ${band.toStringAsFixed(1)}'})';
}

double noteMeasureFor({required double maxWidth, required double em}) {
  final double pinned = NoteColumn.measureEm * em;
  return maxWidth.isFinite ? math.min(maxWidth, pinned) : pinned;
}

double photoFloatCap({required double measure, required double em}) =>
    measure - (photoGutterEm + photoBandResidualEm) * em;

bool canFloatAt({required double measure, required double em}) {
  if (!measure.isFinite || !em.isFinite || em <= 0) {
    return false;
  }
  return photoFloatCap(measure: measure, em: em) >= photoMinFloatEm * em;
}

double? photoAspectOf(int? width, int? height) {
  if (width == null || height == null || width <= 0 || height <= 0) {
    return null;
  }
  return width / height;
}

double? _readableAspect(double? aspect) =>
    aspect != null && aspect.isFinite && aspect > 0 ? aspect : null;

double _clampedHeight(double width, double aspect) =>
    math.min(width / aspect, photoHeightClamp * width);

PhotoPlan planFloat({
  required double measure,
  required double em,
  required PhotoSide side,
  required PhotoSize size,
  double? aspect,
  bool nextIsParagraph = false,
}) {
  final double column = measure.isFinite && measure > 0 ? measure : 0;
  final double? ratio = _readableAspect(aspect);
  final bool measureCanFloat = canFloatAt(measure: column, em: em);
  final double gutter = em.isFinite && em > 0 ? photoGutterEm * em : 0;
  final double? floatEm = size.floatEm;
  if (floatEm != null && nextIsParagraph && ratio != null && gutter > 0) {
    final double width = math.min(
      floatEm * em,
      photoFloatCap(measure: column, em: em),
    );
    final double height = _clampedHeight(width, ratio);
    if (width >= photoMinFloatEm * em && height >= photoLineEm * em) {
      return PhotoPlan(
        side: side,
        size: size,
        measure: column,
        width: width,
        height: height,
        band: column - gutter - width,
        gutter: gutter,
        isStacked: false,
        measureCanFloat: measureCanFloat,
      );
    }
  }
  final double width = column * size.measureFraction;
  return PhotoPlan(
    side: side,
    size: size,
    measure: column,
    width: width,
    height: _clampedHeight(width, ratio ?? photoFallbackAspect),
    band: column,
    gutter: gutter,
    isStacked: true,
    measureCanFloat: measureCanFloat,
  );
}
