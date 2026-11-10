import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Role = ({
  TextStyle style,
  String family,
  double size,
  FontWeight weight,
  double height,
  Color color,
});

List<(String, _Role)> _roles(FieldNotesColors colors) {
  final FieldNotesTextStyles styles = FieldNotesTextStyles(colors);
  const String serif = TypographyTokens.serif;
  const String sans = TypographyTokens.sans;
  const String hand = TypographyTokens.accent;
  const FontWeight w4 = FontWeight.w400;
  const FontWeight w5 = FontWeight.w500;
  const FontWeight w6 = FontWeight.w600;
  final Color ink = colors.ink;
  final Color muted = colors.muted;
  return <(String, _Role)>[
    (
      'display',
      (
        style: styles.display,
        family: serif,
        size: 34,
        weight: w5,
        height: 1.05,
        color: ink,
      ),
    ),
    (
      'title',
      (
        style: styles.title,
        family: serif,
        size: 24,
        weight: w5,
        height: 1.2,
        color: ink,
      ),
    ),
    (
      'heading',
      (
        style: styles.heading,
        family: serif,
        size: 17,
        weight: w5,
        height: 1.3,
        color: ink,
      ),
    ),
    (
      'body',
      (
        style: styles.body,
        family: serif,
        size: 15,
        weight: w4,
        height: 1.5,
        color: ink,
      ),
    ),
    (
      'ui',
      (
        style: styles.ui,
        family: sans,
        size: 14,
        weight: w5,
        height: 1.4,
        color: ink,
      ),
    ),
    (
      'label',
      (
        style: styles.label,
        family: sans,
        size: 13,
        weight: w6,
        height: 1.4,
        color: ink,
      ),
    ),
    (
      'caption',
      (
        style: styles.caption,
        family: sans,
        size: 12,
        weight: w4,
        height: 1.4,
        color: muted,
      ),
    ),
    (
      'micro',
      (
        style: styles.micro,
        family: sans,
        size: 11,
        weight: w6,
        height: 1.3,
        color: muted,
      ),
    ),
    (
      'accent',
      (
        style: styles.accent,
        family: hand,
        size: 18,
        weight: w6,
        height: 1.15,
        color: colors.accentInk,
      ),
    ),
    (
      'section',
      (
        style: styles.section,
        family: hand,
        size: 19,
        weight: w6,
        height: 1.1,
        color: colors.sage,
      ),
    ),
  ];
}

Map<String, Color> _mediaTokens(FieldNotesColors colors) => <String, Color>{
  'mediaRail': colors.mediaRail,
  'mediaPlayed': colors.mediaPlayed,
  'mediaBubble': colors.mediaBubble,
  'mediaBubbleInk': colors.mediaBubbleInk,
  'mediaCta': colors.mediaCta,
  'mediaCtaInk': colors.mediaCtaInk,
  'mediaCtaHover': colors.mediaCtaHover,
  'viewerRail': colors.viewerRail,
  'viewerWaveform': colors.viewerWaveform,
  'viewerStage': colors.viewerStage,
  'viewerStageEdge': colors.viewerStageEdge,
  'viewerFadeStart': colors.viewerFadeStart,
  'viewerFadeEnd': colors.viewerFadeEnd,
};

double _contrast(Color first, Color second) {
  final double a = first.computeLuminance();
  final double b = second.computeLuminance();
  final double lighter = a > b ? a : b;
  final double darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('the seven named radii carry the agreed sizes', () {
    expect(
      <double>[
        Shapes.radius8,
        Shapes.radius10,
        Shapes.radius12,
        Shapes.radius14,
        Shapes.radius16,
        Shapes.radius22,
        Shapes.radiusFull,
      ],
      <double>[8, 10, 12, 14, 16, 22, 999],
    );
  });

  test('spacing climbs in steps of four', () {
    final List<double> scale = <double>[
      Spacing.space4,
      Spacing.space8,
      Spacing.space12,
      Spacing.space16,
      Spacing.space24,
      Spacing.space32,
      Spacing.space48,
    ];

    expect(scale, <double>[4, 8, 12, 16, 24, 32, 48]);
    expect(scale.every((double gap) => gap % Spacing.step == 0), isTrue);
  });

  test('press, fade and stage carry the three shared durations', () {
    expect(Motion.press, const Duration(milliseconds: 120));
    expect(Motion.fade, const Duration(milliseconds: 260));
    expect(Motion.stage, const Duration(milliseconds: 420));
  });

  for (final (String theme, FieldNotesColors colors)
      in const <(String, FieldNotesColors)>[
        ('light', FieldNotesColors.light),
        ('dark', FieldNotesColors.dark),
      ]) {
    test('every type role matches the system sheet in $theme', () {
      for (final (String name, _Role role) in _roles(colors)) {
        expect(role.style.fontFamily, role.family, reason: name);
        expect(role.style.fontSize, role.size, reason: name);
        expect(role.style.fontWeight, role.weight, reason: name);
        expect(role.style.height, role.height, reason: name);
        expect(role.style.color, role.color, reason: name);
      }
    });

    test('media text and call to action stay readable in $theme', () {
      final Color bubble = Color.alphaBlend(
        colors.mediaBubble,
        colors.viewerStage,
      );

      expect(_contrast(colors.mediaBubbleInk, bubble), greaterThan(4.5));
      expect(_contrast(colors.mediaCtaInk, colors.mediaCta), greaterThan(4.5));
      expect(
        _contrast(colors.mediaCtaInk, colors.mediaCtaHover),
        greaterThan(4.5),
      );
    });
  }

  test('the display role tracks in by one percent of its size', () {
    const FieldNotesTextStyles styles = FieldNotesTextStyles(
      FieldNotesColors.light,
    );

    expect(styles.display.letterSpacing, closeTo(-0.34, 0.001));
  });

  test('light media tokens equal the player sheet', () {
    expect(_mediaTokens(FieldNotesColors.light), const <String, Color>{
      'mediaRail': Color(0x3D4A3B2E),
      'mediaPlayed': Color(0xFFA84A5E),
      'mediaBubble': Color(0xFFFFFAF1),
      'mediaBubbleInk': Color(0xFF4A3B2E),
      'mediaCta': Color(0xFF4A3B2E),
      'mediaCtaInk': Color(0xFFFBF3E4),
      'mediaCtaHover': Color(0xFF33271D),
      'viewerRail': Color(0x4D4A3B2E),
      'viewerWaveform': Color(0xFFC4929B),
      'viewerStage': Color(0xFFE6D8BF),
      'viewerStageEdge': Color(0xFFCDBD9F),
      'viewerFadeStart': Color(0x00FBF3E4),
      'viewerFadeEnd': Color(0xF5FBF3E4),
    });
  });

  test('dark media tokens equal the player sheet', () {
    expect(_mediaTokens(FieldNotesColors.dark), const <String, Color>{
      'mediaRail': Color(0x38EDE1E1),
      'mediaPlayed': Color(0xFFE3889A),
      'mediaBubble': Color(0xEB0E0B09),
      'mediaBubbleInk': Color(0xFFF3E6D1),
      'mediaCta': Color(0xFFF3E6D1),
      'mediaCtaInk': Color(0xFF1C1713),
      'mediaCtaHover': Color(0xFFFFF4E2),
      'viewerRail': Color(0x52EDE1E1),
      'viewerWaveform': Color(0xFF8C5C63),
      'viewerStage': Color(0xFF1C1713),
      'viewerStageEdge': Color(0xFF0E0B09),
      'viewerFadeStart': Color(0x001C1919),
      'viewerFadeEnd': Color(0xF01C1919),
    });
  });

  test('copyWith and lerp carry the media tokens', () {
    const FieldNotesColors light = FieldNotesColors.light;
    const FieldNotesColors dark = FieldNotesColors.dark;
    const Color replacement = Color(0xFF123456);
    final FieldNotesColors changed = light.copyWith(viewerFadeEnd: replacement);

    expect(changed.viewerFadeEnd, replacement);
    expect(changed, isNot(light));
    expect(_mediaTokens(light.lerp(dark, 0)), _mediaTokens(light));
    expect(_mediaTokens(light.lerp(dark, 1)), _mediaTokens(dark));
  });
}
