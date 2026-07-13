import 'package:flutter/material.dart';

import '../../design/tokens/tokens.dart';

ThemeData fieldNotesTheme({TargetPlatform? platform}) {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: Palette.coral,
    brightness: Brightness.light,
  ).copyWith(
    primary: Palette.coral,
    onPrimary: Palette.cardBright,
    secondary: Palette.sage,
    surface: Palette.cardWarm,
    onSurface: Palette.ink,
    error: Palette.danger,
    onError: Palette.cardBright,
  );

  return ThemeData(
    useMaterial3: true,
    platform: platform,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.page,
    fontFamily: TypographyTokens.sans,
    textTheme: _textTheme,
    iconTheme: const IconThemeData(color: Palette.ink),
  );
}

const TextTheme _textTheme = TextTheme(
  displayLarge: TypographyTokens.displaySerif,
  displayMedium: TypographyTokens.displaySerif,
  headlineMedium: TypographyTokens.titleSerif,
  headlineSmall: TypographyTokens.titleSerif,
  titleLarge: TypographyTokens.titleSerif,
  titleMedium: TypographyTokens.labelSans,
  bodyLarge: TypographyTokens.bodySerif,
  bodyMedium: TypographyTokens.bodySans,
  labelLarge: TypographyTokens.buttonSans,
  labelMedium: TypographyTokens.captionSans,
  bodySmall: TypographyTokens.captionSans,
);
