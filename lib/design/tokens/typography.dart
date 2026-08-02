import 'package:flutter/painting.dart';

import 'palette.dart';

abstract final class TypographyTokens {
  static const String serif = 'Newsreader';
  static const String sans = 'Instrument Sans';
  static const String accent = 'Caveat';
  static const String mono = 'monospace';

  static const TextStyle timerSerif = TextStyle(
    fontFamily: serif,
    fontSize: 38,
    fontWeight: FontWeight.w400,
    height: 1.0,
    color: Palette.ink,
  );

  static const TextStyle displaySerifToday = TextStyle(
    fontFamily: serif,
    fontSize: 34,
    fontWeight: FontWeight.w500,
    height: 1.0,
    color: Palette.ink,
  );

  static const TextStyle displaySerif = TextStyle(
    fontFamily: serif,
    fontSize: 32,
    fontWeight: FontWeight.w500,
    height: 1.0,
    color: Palette.ink,
  );

  static const TextStyle titleSerif = TextStyle(
    fontFamily: serif,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: Palette.ink,
  );

  static const TextStyle headlineSerif = TextStyle(
    fontFamily: serif,
    fontSize: 21,
    fontWeight: FontWeight.w500,
    color: Palette.ink,
  );

  static const TextStyle bannerSerif = TextStyle(
    fontFamily: serif,
    fontSize: 19,
    fontWeight: FontWeight.w500,
    color: Palette.ink,
  );

  static const TextStyle dateSerif = TextStyle(
    fontFamily: serif,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: Palette.mutedDeep,
  );

  static const TextStyle sectionSerif = TextStyle(
    fontFamily: serif,
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: Palette.ink,
  );

  static const TextStyle bodySerif = TextStyle(
    fontFamily: serif,
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: Palette.ink,
  );

  static const TextStyle bodySerifItalic = TextStyle(
    fontFamily: serif,
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    height: 1.5,
    color: Palette.ink,
  );

  static const TextStyle composerBodySerif = TextStyle(
    fontFamily: serif,
    fontSize: 19,
    fontWeight: FontWeight.w400,
    height: 2.0,
    color: Palette.ink,
  );

  static const TextStyle composerPlaceholderSerif = TextStyle(
    fontFamily: serif,
    fontSize: 19,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    height: 2.0,
    color: Palette.ink34,
  );

  static const TextStyle bodySerifSecondary = TextStyle(
    fontFamily: serif,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: Palette.mutedDeep,
  );

  static const TextStyle memoryTitleSerif = TextStyle(
    fontFamily: serif,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Palette.ink,
  );

  static const TextStyle wordmarkAccent = TextStyle(
    fontFamily: accent,
    fontSize: 23,
    fontWeight: FontWeight.w700,
    height: 0.85,
    color: Palette.coral,
  );

  static const TextStyle streakAccent = TextStyle(
    fontFamily: accent,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.0,
    color: Palette.coral,
  );

  static const TextStyle sectionHeaderAccent = TextStyle(
    fontFamily: accent,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: Palette.sage,
  );

  static const TextStyle pageEyebrowAccent = TextStyle(
    fontFamily: accent,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Palette.coral,
  );

  static const TextStyle composerTitleAccent = TextStyle(
    fontFamily: accent,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Palette.coral,
  );

  static const TextStyle hintAccent = TextStyle(
    fontFamily: accent,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Palette.muted,
  );

  static const TextStyle subtitleAccent = TextStyle(
    fontFamily: accent,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Palette.muted,
  );

  static const TextStyle windowTitleAccent = TextStyle(
    fontFamily: accent,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Palette.windowTitle,
  );

  static const TextStyle stampAccent = TextStyle(
    fontFamily: accent,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Palette.sage,
  );

  static const TextStyle promptAccent = TextStyle(
    fontFamily: accent,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Palette.muted,
  );

  static const TextStyle buttonSans = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Palette.ink,
  );

  static const TextStyle labelSans = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Palette.ink,
  );

  static const TextStyle navLabelSans = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodySans = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: Palette.ink,
  );

  static const TextStyle captionSans = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Palette.muted,
  );

  static const TextStyle captureLabelSans = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle caption11Sans = TextStyle(
    fontFamily: sans,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Palette.coral,
  );

  static const TextStyle caption10Sans = TextStyle(
    fontFamily: sans,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: Palette.muted,
  );

  static const TextStyle syncPrimarySans = TextStyle(
    fontFamily: sans,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: Palette.ink,
  );

  static const TextStyle caption9Sans = TextStyle(
    fontFamily: sans,
    fontSize: 9,
    fontWeight: FontWeight.w400,
    color: Palette.muted,
  );

  static const TextStyle caption8Sans = TextStyle(
    fontFamily: sans,
    fontSize: 8,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle syncSecondarySans = TextStyle(
    fontFamily: sans,
    fontSize: 8,
    fontWeight: FontWeight.w400,
    color: Palette.muted,
  );

  static const TextStyle chipMicroSans = TextStyle(
    fontFamily: sans,
    fontSize: 8,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.64,
    color: Palette.coral,
  );

  static const TextStyle viewportMonoLabel = TextStyle(
    fontFamily: mono,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.0,
    color: Palette.onDark30,
  );

  static const TextStyle monoMicroSans = TextStyle(
    fontFamily: mono,
    fontSize: 7,
    fontWeight: FontWeight.w500,
    color: Palette.muted,
  );

  static const TextStyle monoThumbSans = TextStyle(
    fontFamily: mono,
    fontSize: 6,
    fontWeight: FontWeight.w500,
    color: Palette.mutedDeep,
  );
}
