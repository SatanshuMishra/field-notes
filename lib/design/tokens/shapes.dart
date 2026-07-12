import 'package:flutter/painting.dart';

import 'palette.dart';

abstract final class Shapes {
  static const double outlineWidth = 1.5;

  static const double radiusSm = 11;
  static const double radiusMd = 14;
  static const double radiusLg = 16;
  static const double radiusXl = 20;

  static const Radius cardRadius = Radius.circular(radiusLg);
  static const BorderRadius cardBorderRadius = BorderRadius.all(cardRadius);
  static const BorderRadius buttonBorderRadius =
      BorderRadius.all(Radius.circular(radiusSm));

  static const Border outline = Border.fromBorderSide(
    BorderSide(color: Palette.ink, width: outlineWidth),
  );

  static const double dashLength = 6;
  static const double dashGap = 4;
}
