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

class PhotoBandScope extends InheritedWidget {
  const PhotoBandScope({
    super.key,
    required this.bands,
    required super.child,
  });

  final List<PhotoBand> bands;

  static List<PhotoBand> of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<PhotoBandScope>()
            ?.bands ??
        const <PhotoBand>[];
  }

  @override
  bool updateShouldNotify(PhotoBandScope oldWidget) =>
      !listEquals(bands, oldWidget.bands);
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

List<PhotoBand> photoBandsWithin(List<PhotoBand> bands, int length) {
  int cursor = 0;
  final List<PhotoBand> kept = <PhotoBand>[];
  for (final PhotoBand band in bands) {
    if (band.start < cursor || band.end > length || band.end <= band.start) {
      return const <PhotoBand>[];
    }
    kept.add(band);
    cursor = band.end;
  }
  return kept;
}
