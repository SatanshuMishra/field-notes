import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';

import '../../support/theme_harness.dart';

Map<String, Color> _roles(FieldNotesColors colors) => <String, Color>{
  'page': colors.page,
  'pageGradientInner': colors.pageGradientInner,
  'pageGradientOuter': colors.pageGradientOuter,
  'panelTop': colors.panelTop,
  'panelBottom': colors.panelBottom,
  'cardWarm': colors.cardWarm,
  'cardLight': colors.cardLight,
  'cardBright': colors.cardBright,
  'cardAlt': colors.cardAlt,
  'composerPaper': colors.composerPaper,
  'paperShade': colors.paperShade,
  'titleBar': colors.titleBar,
  'hatchLight': colors.hatchLight,
  'hatchMid': colors.hatchMid,
  'hatchDark': colors.hatchDark,
  'dangerSurface': colors.dangerSurface,
  'ink': colors.ink,
  'line': colors.line,
  'shadow': colors.shadow,
  'shadowTintBase': colors.shadowTintBase,
  'pill': colors.pill,
  'inkSoft': colors.inkSoft,
  'muted': colors.muted,
  'mutedDeep': colors.mutedDeep,
  'noticeInk': colors.noticeInk,
  'noticeBodyInk': colors.noticeBodyInk,
  'placeholder': colors.placeholder,
  'dashMuted': colors.dashMuted,
  'windowTitle': colors.windowTitle,
  'sage': colors.sage,
  'accentInk': colors.accentInk,
  'coralLink': colors.coralLink,
  'coralHover': colors.coralHover,
  'dangerInk': colors.dangerInk,
  'waveMid': colors.waveMid,
  'waveLight': colors.waveLight,
};

Map<String, Color> _rolesExcept(FieldNotesColors colors, Set<String> names) =>
    <String, Color>{
      for (final MapEntry<String, Color> role in _roles(colors).entries)
        if (!names.contains(role.key)) role.key: role.value,
    };

Map<String, Color> _inkAlphas(FieldNotesColors colors) => <String, Color>{
  'ink08': colors.ink08,
  'ink12': colors.ink12,
  'ink14': colors.ink14,
  'ink16': colors.ink16,
  'ink18': colors.ink18,
  'ink20': colors.ink20,
  'ink22': colors.ink22,
  'ink25': colors.ink25,
  'ink28': colors.ink28,
  'ink30': colors.ink30,
  'ink32': colors.ink32,
  'ink34': colors.ink34,
  'ink35': colors.ink35,
  'ink40': colors.ink40,
};

double _channel(double value) => value <= 0.03928
    ? value / 12.92
    : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color color) =>
    0.2126 * _channel(color.r) +
    0.7152 * _channel(color.g) +
    0.0722 * _channel(color.b);

double _contrast(Color first, Color second) {
  final double a = _luminance(first);
  final double b = _luminance(second);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  group('FieldNotesColors', () {
    test('light colours equal the live palette values', () {
      const FieldNotesColors colors = FieldNotesColors.light;

      expect(_roles(colors), const <String, Color>{
        'page': Color(0xFFD9CBB2),
        'pageGradientInner': Color(0xFFE6D8BF),
        'pageGradientOuter': Color(0xFFCDBD9F),
        'panelTop': Color(0xFFEFE2CE),
        'panelBottom': Color(0xFFE9DCC4),
        'cardWarm': Color(0xFFF8EFE0),
        'cardLight': Color(0xFFFFF5EA),
        'cardBright': Color(0xFFFFFAF1),
        'cardAlt': Color(0xFFF6EFE0),
        'composerPaper': Color(0xFFFBF3E4),
        'paperShade': Color(0xFFF3E7D4),
        'titleBar': Color(0xFFE4D6BF),
        'hatchLight': Color(0xFFECDFC8),
        'hatchMid': Color(0xFFE2D3BA),
        'hatchDark': Color(0xFFD9C9AE),
        'dangerSurface': Color(0xFFFBECEA),
        'ink': Color(0xFF4A3B2E),
        'line': Color(0xFF4A3B2E),
        'shadow': Color(0xFF4A3B2E),
        'shadowTintBase': Color(0xFF4A3B2E),
        'pill': Color(0xFF4A3B2E),
        'inkSoft': Color(0xFF6A5C4A),
        'muted': Color(0xFFA08A70),
        'mutedDeep': Color(0xFF8A7358),
        'noticeInk': Color(0xFF7D6A52),
        'noticeBodyInk': Color(0xFF6F6254),
        'placeholder': Color(0xFFB3A58C),
        'dashMuted': Color(0xFFC3B39A),
        'windowTitle': Color(0xFFA3866A),
        'sage': Color(0xFF7D8450),
        'accentInk': Color(0xFFC76A54),
        'coralLink': Color(0xFFB45C44),
        'coralHover': Color(0xFF9A4832),
        'dangerInk': Color(0xFFC0392B),
        'waveMid': Color(0xFFDCAE9A),
        'waveLight': Color(0xFFE3C4B2),
      });
      expect(_inkAlphas(colors), const <String, Color>{
        'ink08': Color(0x144A3B2E),
        'ink12': Color(0x1F4A3B2E),
        'ink14': Color(0x244A3B2E),
        'ink16': Color(0x294A3B2E),
        'ink18': Color(0x2E4A3B2E),
        'ink20': Color(0x334A3B2E),
        'ink22': Color(0x384A3B2E),
        'ink25': Color(0x404A3B2E),
        'ink28': Color(0x474A3B2E),
        'ink30': Color(0x4D4A3B2E),
        'ink32': Color(0x524A3B2E),
        'ink34': Color(0x574A3B2E),
        'ink35': Color(0x594A3B2E),
        'ink40': Color(0x664A3B2E),
      });
      expect(colors.shadowTint(0x29), const Color(0x294A3B2E));
    });

    test("dark colours equal the design's dark palette", () {
      const FieldNotesColors colors = FieldNotesColors.dark;

      expect(_roles(colors), const <String, Color>{
        'page': Color(0xFF0E0C0A),
        'pageGradientInner': Color(0xFF1B1612),
        'pageGradientOuter': Color(0xFF0B0907),
        'panelTop': Color(0xFF1E1914),
        'panelBottom': Color(0xFF191511),
        'cardWarm': Color(0xFF29221B),
        'cardLight': Color(0xFF342A20),
        'cardBright': Color(0xFF211B16),
        'cardAlt': Color(0xFF26201A),
        'composerPaper': Color(0xFF2B241C),
        'paperShade': Color(0xFF2D261E),
        'titleBar': Color(0xFF241E19),
        'hatchLight': Color(0xFF2E261F),
        'hatchMid': Color(0xFF352C24),
        'hatchDark': Color(0xFF3C3229),
        'dangerSurface': Color(0xFF3B2320),
        'ink': Color(0xFFEFE3CE),
        'line': Color(0xFF9D8870),
        'shadow': Color(0xFF070504),
        'shadowTintBase': Color(0xFF000000),
        'pill': Color(0xFF3D3229),
        'inkSoft': Color(0xFFC4B39A),
        'muted': Color(0xFFA6917A),
        'mutedDeep': Color(0xFFBFAA8E),
        'noticeInk': Color(0xFFB09C80),
        'noticeBodyInk': Color(0xFFC4B39A),
        'placeholder': Color(0xFF6E604F),
        'dashMuted': Color(0xFF5C4F42),
        'windowTitle': Color(0xFF8A7560),
        'sage': Color(0xFFADB670),
        'accentInk': Color(0xFFE8927A),
        'coralLink': Color(0xFFE5907A),
        'coralHover': Color(0xFFF0A58E),
        'dangerInk': Color(0xFFEF7466),
        'waveMid': Color(0xFF8A5C4B),
        'waveLight': Color(0xFF5C4339),
      });
      expect(colors.ink25, const Color(0x40EFE3CE));
      expect(colors.shadowTint(0x29), const Color(0x29000000));
    });

    test('dark text roles reach 4.5 to 1 on every dark surface', () {
      const FieldNotesColors colors = FieldNotesColors.dark;
      final Map<String, Color> textRoles = <String, Color>{
        'ink': colors.ink,
        'inkSoft': colors.inkSoft,
        'muted': colors.muted,
        'mutedDeep': colors.mutedDeep,
        'accentInk': colors.accentInk,
        'coralLink': colors.coralLink,
        'dangerInk': colors.dangerInk,
        'sage': colors.sage,
      };
      final Map<String, Color> surfaces = <String, Color>{
        'page': colors.page,
        'panelTop': colors.panelTop,
        'panelBottom': colors.panelBottom,
        'cardWarm': colors.cardWarm,
        'cardLight': colors.cardLight,
        'cardBright': colors.cardBright,
        'cardAlt': colors.cardAlt,
        'composerPaper': colors.composerPaper,
      };

      final List<String> failures = <String>[
        for (final MapEntry<String, Color> text in textRoles.entries)
          for (final MapEntry<String, Color> surface in surfaces.entries)
            if (_contrast(text.value, surface.value) < 4.5)
              '${text.key} on ${surface.key}: '
                  '${_contrast(text.value, surface.value).toStringAsFixed(2)}',
      ];

      expect(failures, isEmpty);
      expect(_contrast(colors.muted, colors.cardLight), closeTo(4.64, 0.01));
    });

    testWidgets('of falls back to the light colours outside a themed app', (
      WidgetTester tester,
    ) async {
      FieldNotesColors? resolved;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (BuildContext context) {
              resolved = FieldNotesColors.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, same(FieldNotesColors.light));
    });

    testWidgets('the context getters read the themed dark tokens', (
      WidgetTester tester,
    ) async {
      FieldNotesColors? colors;
      FieldNotesTextStyles? textStyles;
      FieldNotesShadows? shadows;
      await pumpThemed(
        tester,
        Builder(
          builder: (BuildContext context) {
            colors = context.colors;
            textStyles = context.textStyles;
            shadows = context.shadows;
            return const SizedBox.shrink();
          },
        ),
        brightness: Brightness.dark,
      );

      expect(colors, FieldNotesColors.dark);
      expect(textStyles!.bodySans.color, const Color(0xFFEFE3CE));
      expect(shadows!.emphasis.single.color, const Color(0xFF070504));
    });

    test('lerp returns the start at 0 and the end at 1', () {
      expect(
        FieldNotesColors.light.lerp(FieldNotesColors.dark, 0),
        FieldNotesColors.light,
      );
      expect(
        FieldNotesColors.light.lerp(FieldNotesColors.dark, 1),
        FieldNotesColors.dark,
      );
      expect(
        FieldNotesColors.light.lerp(null, 0.5),
        same(FieldNotesColors.light),
      );
    });

    test('copyWith replaces only the named colours', () {
      final FieldNotesColors changed = FieldNotesColors.light.copyWith(
        ink: const Color(0xFF000001),
        waveLight: const Color(0xFF000002),
      );

      expect(changed.ink, const Color(0xFF000001));
      expect(changed.waveLight, const Color(0xFF000002));
      expect(
        _rolesExcept(changed, const <String>{'ink', 'waveLight'}),
        _rolesExcept(FieldNotesColors.light, const <String>{
          'ink',
          'waveLight',
        }),
      );
      expect(FieldNotesColors.light.copyWith(), FieldNotesColors.light);
    });
  });
}
