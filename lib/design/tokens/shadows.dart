import 'package:flutter/painting.dart';

import 'palette.dart';

abstract final class Shadows {
  static const List<BoxShadow> cellToday = <BoxShadow>[
    BoxShadow(
      color: Palette.coral30,
      offset: Offset(1.5, 1.5),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> tileSelected = <BoxShadow>[
    BoxShadow(
      color: Palette.coral30,
      offset: Offset(2, 2),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> softLift = <BoxShadow>[
    BoxShadow(
      color: Color(0x99322314),
      offset: Offset(0, 20),
      blurRadius: 50,
      spreadRadius: -16,
    ),
  ];

  static const List<BoxShadow> panelLift = <BoxShadow>[
    BoxShadow(
      color: Color(0xB81E140A),
      offset: Offset(0, 44),
      blurRadius: 96,
      spreadRadius: -30,
    ),
  ];

  static const List<BoxShadow> pickerSheetLift = <BoxShadow>[
    BoxShadow(
      color: Color(0x80322314),
      offset: Offset(0, -12),
      blurRadius: 30,
      spreadRadius: -12,
    ),
  ];

  static const List<BoxShadow> chooserSheetLift = <BoxShadow>[
    BoxShadow(
      color: Color(0x8C322314),
      offset: Offset(0, -14),
      blurRadius: 34,
      spreadRadius: -14,
    ),
  ];

  static const List<BoxShadow> toastLift = <BoxShadow>[
    BoxShadow(
      color: Color(0x80000000),
      offset: Offset(0, 10),
      blurRadius: 24,
      spreadRadius: -8,
    ),
  ];
}
