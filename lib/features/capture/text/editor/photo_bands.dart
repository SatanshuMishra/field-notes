import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const double photoBandFontSize = 0.01;
const Color _photoBandInk = Color(0x00000000);

@immutable
class PhotoBand {
  const PhotoBand({
    required this.start,
    required this.end,
    required this.height,
  });

  final int start;
  final int end;
  final double height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoBand &&
          start == other.start &&
          end == other.end &&
          height == other.height;

  @override
  int get hashCode => Object.hash(start, end, height);

  @override
  String toString() => 'PhotoBand([$start, $end), $height)';
}

enum PhotoSpacerRole { indent, trailing }

@immutable
class PhotoSpacer {
  const PhotoSpacer({
    required this.index,
    required this.width,
    required this.role,
    this.height = 0,
  });

  final int index;
  final double width;
  final double height;
  final PhotoSpacerRole role;

  int get start => index;

  int get end => index + 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoSpacer &&
          index == other.index &&
          width == other.width &&
          height == other.height &&
          role == other.role;

  @override
  int get hashCode => Object.hash(index, width, height, role);

  @override
  String toString() =>
      'PhotoSpacer($index, ${width.toStringAsFixed(1)}x'
      '${height.toStringAsFixed(1)}, ${role.name})';
}

@immutable
class PhotoKern {
  const PhotoKern({
    required this.start,
    required this.end,
    required this.spacing,
  });

  final int start;
  final int end;
  final double spacing;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoKern &&
          start == other.start &&
          end == other.end &&
          spacing == other.spacing;

  @override
  int get hashCode => Object.hash(start, end, spacing);

  @override
  String toString() => 'PhotoKern([$start, $end), $spacing)';
}

@immutable
class PhotoPatches {
  const PhotoPatches({
    this.bands = const <PhotoBand>[],
    this.spacers = const <PhotoSpacer>[],
    this.kerns = const <PhotoKern>[],
  });

  static const PhotoPatches none = PhotoPatches();

  final List<PhotoBand> bands;
  final List<PhotoSpacer> spacers;
  final List<PhotoKern> kerns;

  bool get isEmpty => bands.isEmpty && spacers.isEmpty && kerns.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoPatches &&
          listEquals(bands, other.bands) &&
          listEquals(spacers, other.spacers) &&
          listEquals(kerns, other.kerns);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(bands),
        Object.hashAll(spacers),
        Object.hashAll(kerns),
      );
}

class PhotoBandScope extends InheritedWidget {
  const PhotoBandScope({
    super.key,
    required this.patches,
    required super.child,
  });

  final PhotoPatches patches;

  static PhotoPatches of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<PhotoBandScope>()
            ?.patches ??
        PhotoPatches.none;
  }

  @override
  bool updateShouldNotify(PhotoBandScope oldWidget) =>
      patches != oldWidget.patches;
}

TextStyle photoBandStyle(double height, TextScaler scaler) {
  return TextStyle(
    color: _photoBandInk,
    fontSize: photoBandFontSize,
    height: height / scaler.scale(photoBandFontSize),
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    wordSpacing: 0,
    decoration: TextDecoration.none,
  );
}

PhotoPatches photoPatchesWithin(PhotoPatches patches, int length) {
  final List<(int, int)> spans = <(int, int)>[
    for (final PhotoBand band in patches.bands) (band.start, band.end),
    for (final PhotoSpacer spacer in patches.spacers)
      (spacer.start, spacer.end),
    for (final PhotoKern kern in patches.kerns) (kern.start, kern.end),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  int cursor = 0;
  for (final (int start, int end) in spans) {
    if (start < cursor || end > length || end <= start) {
      return PhotoPatches.none;
    }
    cursor = end;
  }
  return patches;
}
