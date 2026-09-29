import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/tokens/tokens.dart';

void main() {
  group('fieldNotesTheme', () {
    test('paints the page background and the coral primary', () {
      final ThemeData theme = fieldNotesTheme();

      expect(theme.scaffoldBackgroundColor, FieldNotesColors.light.page);
      expect(theme.colorScheme.primary, Palette.coral);
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
      expect(theme.extension<FieldNotesColors>(), FieldNotesColors.light);
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

    test(
      'the dark theme paints the dark page and carries the dark colours',
      () {
        final ThemeData theme = fieldNotesTheme(
          platform: TargetPlatform.macOS,
          brightness: Brightness.dark,
        );

        expect(theme.brightness, Brightness.dark);
        expect(theme.scaffoldBackgroundColor, const Color(0xFF0E0C0A));
        expect(theme.colorScheme.primary, const Color(0xFFC76A54));
        expect(theme.colorScheme.surface, const Color(0xFF29221B));
        expect(theme.colorScheme.onSurface, const Color(0xFFEFE3CE));
        expect(theme.extension<FieldNotesColors>(), FieldNotesColors.dark);
        expect(theme.textTheme.bodyMedium?.color, const Color(0xFFEFE3CE));
        expect(theme.textTheme.bodyMedium?.fontFamily, TypographyTokens.sans);
        expect(theme.iconTheme.color, const Color(0xFFEFE3CE));
        expect(theme.useMaterial3, isTrue);
        expect(theme.platform, TargetPlatform.macOS);
      },
    );
  });
}
