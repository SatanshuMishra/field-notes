import 'package:flutter/painting.dart';

abstract final class Shapes {
  static const double outlineWidth = 1.5;

  static const double radiusXs = 6;
  static const double radiusIconButton = 8;
  static const double radiusThumb = 9;
  static const double radiusCell = 10;
  static const double radiusSm = 11;
  static const double radiusControl = 12;
  static const double radiusPill = 13;
  static const double radiusMd = 14;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusSheet = 22;

  static const double radius8 = 8;
  static const double radius10 = 10;
  static const double radius12 = 12;
  static const double radius14 = 14;
  static const double radius16 = 16;
  static const double radius22 = 22;
  static const double radiusFull = 999;

  static const Radius cardRadius = Radius.circular(radiusLg);
  static const BorderRadius cardBorderRadius = BorderRadius.all(cardRadius);
  static const BorderRadius buttonBorderRadius = BorderRadius.all(
    Radius.circular(radiusSm),
  );

  static const double dashLength = 6;
  static const double dashGap = 4;
}

abstract final class Spacing {
  static const double step = 4;

  static const double space4 = step;
  static const double space8 = step * 2;
  static const double space12 = step * 3;
  static const double space16 = step * 4;
  static const double space24 = step * 6;
  static const double space32 = step * 8;
  static const double space48 = step * 12;
}
