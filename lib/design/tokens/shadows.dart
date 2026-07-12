import 'package:flutter/painting.dart';

import 'palette.dart';

abstract final class Shadows {
  static const Color _cardShadowColor = Color(0x334A3B2E);

  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: _cardShadowColor,
      offset: Offset(3, 3),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> button = <BoxShadow>[
    BoxShadow(
      color: Palette.ink,
      offset: Offset(1.5, 1.5),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];
}
