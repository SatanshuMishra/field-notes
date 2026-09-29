import 'package:flutter/material.dart';

import '../../design/tokens/tokens.dart';

ThemeData fieldNotesTheme({
  TargetPlatform? platform,
  Brightness brightness = Brightness.light,
}) {
  final FieldNotesColors colors = switch (brightness) {
    Brightness.light => FieldNotesColors.light,
    Brightness.dark => FieldNotesColors.dark,
  };

  final ColorScheme scheme =
      ColorScheme.fromSeed(
        seedColor: Palette.coral,
        brightness: brightness,
      ).copyWith(
        primary: Palette.coral,
        onPrimary: FieldNotesColors.light.cardBright,
        secondary: colors.sage,
        surface: colors.cardWarm,
        onSurface: colors.ink,
        error: colors.dangerInk,
        onError: FieldNotesColors.light.cardBright,
      );

  return ThemeData(
    useMaterial3: true,
    platform: platform,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.page,
    fontFamily: TypographyTokens.sans,
    textTheme: _textTheme(FieldNotesTextStyles(colors)),
    iconTheme: IconThemeData(color: colors.ink),
    timePickerTheme: TimePickerThemeData(
      dayPeriodColor: WidgetStateColor.resolveWith(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? Palette.coral
            : const Color(0x00000000),
      ),
      dayPeriodTextColor: WidgetStateColor.resolveWith(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? Palette.onAccent
            : colors.ink,
      ),
    ),
    extensions: <ThemeExtension<dynamic>>[colors],
  );
}

TextTheme _textTheme(FieldNotesTextStyles styles) => TextTheme(
  displayLarge: styles.displaySerif,
  displayMedium: styles.displaySerif,
  headlineMedium: styles.titleSerif,
  headlineSmall: styles.titleSerif,
  titleLarge: styles.titleSerif,
  titleMedium: styles.labelSans,
  bodyLarge: styles.bodySerif,
  bodyMedium: styles.bodySans,
  labelLarge: styles.buttonSans,
  labelMedium: styles.captionSans,
  bodySmall: styles.captionSans,
);
