import 'package:flutter/animation.dart';

abstract final class Motion {
  static const Duration press = Duration(milliseconds: 120);
  static const Duration stage = Duration(milliseconds: 420);

  static const Duration blink = Duration(milliseconds: 900);
  static const Duration pulse = Duration(milliseconds: 1500);
  static const Duration bob = Duration(milliseconds: 700);
  static const Duration fade = Duration(milliseconds: 260);
  static const Duration toastRise = Duration(milliseconds: 220);
  static const Duration modalPop = Duration(milliseconds: 220);
  static const Duration sheetSlide = Duration(milliseconds: 300);

  static const Curve blinkCurve = Curves.easeInOut;
  static const Curve pulseCurve = Curves.easeInOut;
  static const Curve bobCurve = Curves.easeInOut;
  static const Curve fadeCurve = Curves.easeOut;
  static const Curve entranceCurve = Curves.easeOutCubic;

  static const List<Duration> all = <Duration>[
    blink,
    pulse,
    bob,
    fade,
    toastRise,
    modalPop,
    sheetSlide,
  ];
}
