import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/layout/note_typography.dart';
import 'package:flutter/painting.dart';

const double desktopColumnEm = 30;
const double floatGutterEm = 1;
const double minFloatBandEm = 12;
const double photoMaxHeightFactor = 1.6;
const double photoPlaceholderAspect = 3 / 2;
const double photoCaptionGap = 8;
const double photoUnavailableHeight = 56;

const double _tolerance = 1e-9;

enum PhotoMode { floatLeft, floatRight, centred }

final class PhotoLayoutPlan {
  const PhotoLayoutPlan({
    required this.mode,
    required this.width,
    required this.photoHeight,
    this.captionHeight = 0,
    this.bandWidth = 0,
    this.isPlaceholder = false,
    this.isUnavailable = false,
  });

  final PhotoMode mode;
  final double width;
  final double photoHeight;
  final double captionHeight;
  final double bandWidth;
  final bool isPlaceholder;
  final bool isUnavailable;

  bool get floats => mode != PhotoMode.centred;

  double get figureHeight =>
      photoHeight + (captionHeight > 0 ? photoCaptionGap + captionHeight : 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoLayoutPlan &&
          mode == other.mode &&
          width == other.width &&
          photoHeight == other.photoHeight &&
          captionHeight == other.captionHeight &&
          bandWidth == other.bandWidth &&
          isPlaceholder == other.isPlaceholder &&
          isUnavailable == other.isUnavailable;

  @override
  int get hashCode => Object.hash(
    mode,
    width,
    photoHeight,
    captionHeight,
    bandWidth,
    isPlaceholder,
    isUnavailable,
  );

  @override
  String toString() =>
      'PhotoLayoutPlan(${mode.name}, $width x $photoHeight, '
      'caption: $captionHeight, band: $bandWidth'
      '${isPlaceholder ? ', placeholder' : ''}'
      '${isUnavailable ? ', unavailable' : ''})';
}

typedef PhotoPlanner =
    PhotoLayoutPlan Function({
      required MdPhotoPlacement placement,
      required double columnWidth,
      required TextScaler textScaler,
      double? aspect,
      bool unavailable,
      String caption,
      bool boldText,
      Locale? locale,
    });

bool isDesktopColumn({required double columnWidth, required double em}) =>
    columnWidth >= desktopColumnEm * em - _tolerance;

double photoWidthFor(
  MdPhotoSize size, {
  required double columnWidth,
  required double em,
}) => isDesktopColumn(columnWidth: columnWidth, em: em)
    ? columnWidth * size.fraction
    : columnWidth;

double photoHeightFor({required double width, double? aspect}) {
  if (aspect == null) {
    return width / photoPlaceholderAspect;
  }
  return math.max(1, math.min(width / aspect, photoMaxHeightFactor * width));
}

double? photoAspectFor(Size? dimensions) {
  if (dimensions == null || dimensions.width <= 0 || dimensions.height <= 0) {
    return null;
  }
  return dimensions.width / dimensions.height;
}

bool photoCanFloat({
  required MdPhotoSize size,
  required double columnWidth,
  required double em,
}) {
  if (!isDesktopColumn(columnWidth: columnWidth, em: em) ||
      size == MdPhotoSize.full) {
    return false;
  }
  final double band =
      columnWidth -
      photoWidthFor(size, columnWidth: columnWidth, em: em) -
      floatGutterEm * em;
  return band >= minFloatBandEm * em - _tolerance;
}

PhotoLayoutPlan planPhoto({
  required MdPhotoPlacement placement,
  required double columnWidth,
  required TextScaler textScaler,
  double? aspect,
  bool unavailable = false,
  String caption = '',
  bool boldText = false,
  Locale? locale,
}) {
  final double em = NoteTypography.emOf(textScaler);
  final (PhotoMode mode, double width) = _modeAndWidth(
    placement: placement,
    columnWidth: columnWidth,
    em: em,
  );
  final double captionHeight = _captionHeight(
    caption: caption,
    width: width,
    textScaler: textScaler,
    boldText: boldText,
    locale: locale,
  );
  if (unavailable) {
    return PhotoLayoutPlan(
      mode: PhotoMode.centred,
      width: width,
      photoHeight: photoUnavailableHeight,
      captionHeight: captionHeight,
      isUnavailable: true,
    );
  }
  return PhotoLayoutPlan(
    mode: mode,
    width: width,
    photoHeight: photoHeightFor(width: width, aspect: aspect),
    captionHeight: captionHeight,
    bandWidth: mode == PhotoMode.centred
        ? 0
        : columnWidth - width - floatGutterEm * em,
    isPlaceholder: aspect == null,
  );
}

(PhotoMode, double) _modeAndWidth({
  required MdPhotoPlacement placement,
  required double columnWidth,
  required double em,
}) {
  if (!isDesktopColumn(columnWidth: columnWidth, em: em)) {
    return (PhotoMode.centred, columnWidth);
  }
  if (!placement.isValid) {
    return (PhotoMode.centred, columnWidth * MdPhotoSize.medium.fraction);
  }
  final double width = photoWidthFor(
    placement.size,
    columnWidth: columnWidth,
    em: em,
  );
  final bool canFloat = photoCanFloat(
    size: placement.size,
    columnWidth: columnWidth,
    em: em,
  );
  return switch (placement.side) {
    MdPhotoSide.left when canFloat => (PhotoMode.floatLeft, width),
    MdPhotoSide.right when canFloat => (PhotoMode.floatRight, width),
    _ => (PhotoMode.centred, width),
  };
}

double _captionHeight({
  required String caption,
  required double width,
  required TextScaler textScaler,
  required bool boldText,
  required Locale? locale,
}) {
  if (caption.isEmpty) {
    return 0;
  }
  final TextStyle style = NoteTypography.withBoldText(
    NoteTypography.caption,
    boldText: boldText,
  ).copyWith(locale: locale);
  final ui.ParagraphBuilder builder =
      ui.ParagraphBuilder(
          style.getParagraphStyle(
            textAlign: TextAlign.center,
            textScaler: textScaler,
            locale: locale,
          ),
        )
        ..pushStyle(style.getTextStyle(textScaler: textScaler))
        ..addText(caption);
  final ui.Paragraph paragraph = builder.build()
    ..layout(ui.ParagraphConstraints(width: width));
  final double height = paragraph.height;
  paragraph.dispose();
  return height;
}
