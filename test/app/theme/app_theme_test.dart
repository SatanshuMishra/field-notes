import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/tokens/tokens.dart';

void main() {
  group('fieldNotesTheme', () {
    test('paints the page background and the coral primary', () {
      final ThemeData theme = fieldNotesTheme();

      expect(theme.scaffoldBackgroundColor, Palette.page);
      expect(theme.colorScheme.primary, Palette.coral);
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
    });

    test('maps body text onto the Instrument Sans UI font', () {
      final ThemeData theme = fieldNotesTheme();

      expect(theme.textTheme.bodyMedium?.fontFamily, TypographyTokens.sans);
      expect(theme.textTheme.bodyLarge?.fontFamily, TypographyTokens.serif);
    });

    test('passes the target platform through for adaptive layout', () {
      expect(
        fieldNotesTheme(platform: TargetPlatform.macOS).platform,
        TargetPlatform.macOS,
      );
      expect(
        fieldNotesTheme(platform: TargetPlatform.android).platform,
        TargetPlatform.android,
      );
    });
  });
}
