import 'package:flutter/painting.dart';

import 'palette.dart';

abstract final class TypographyTokens {
  static const String serif = 'Newsreader';
  static const String sans = 'Instrument Sans';
  static const String accent = 'Caveat';

  static const TextStyle displaySerif = TextStyle(
    fontFamily: serif,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.15,
    color: Palette.ink,
  );

  static const TextStyle titleSerif = TextStyle(
    fontFamily: serif,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: Palette.ink,
  );

  static const TextStyle bodySerif = TextStyle(
    fontFamily: serif,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: Palette.ink,
  );

  static const TextStyle bodySerifItalic = TextStyle(
    fontFamily: serif,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    height: 1.5,
    color: Palette.ink,
  );

  static const TextStyle dateSerif = TextStyle(
    fontFamily: serif,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: Palette.mutedDeep,
  );

  static const TextStyle labelSans = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Palette.ink,
  );

  static const TextStyle buttonSans = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Palette.ink,
  );

  static const TextStyle captionSans = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Palette.muted,
  );

  static const TextStyle bodySans = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: Palette.ink,
  );

  static const TextStyle eyebrowAccent = TextStyle(
    fontFamily: accent,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Palette.sage,
  );

  static const TextStyle streakAccent = TextStyle(
    fontFamily: accent,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: Palette.coral,
  );

  static const TextStyle wordmarkAccent = TextStyle(
    fontFamily: accent,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: Palette.ink,
  );
}
