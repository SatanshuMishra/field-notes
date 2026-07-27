import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';

void main() {
  group('typography to pubspec family consistency', () {
    late String pubspec;

    setUpAll(() {
      pubspec = File('pubspec.yaml').readAsStringSync();
    });

    test('every typography family is a registered pubspec family', () {
      for (final family in <String>[
        TypographyTokens.serif,
        TypographyTokens.sans,
        TypographyTokens.accent,
      ]) {
        expect(pubspec, contains('family: $family'),
            reason: '$family must be registered in the pubspec fonts block');
      }
    });

    test('scale styles reference the declared families', () {
      expect(TypographyTokens.bodySerif.fontFamily, TypographyTokens.serif);
      expect(TypographyTokens.labelSans.fontFamily, TypographyTokens.sans);
      expect(TypographyTokens.eyebrowAccent.fontFamily, TypographyTokens.accent);
    });
  });

  group('sticker-cutout surface tokens', () {
    test('card and button shadows are hard non-blurred offsets', () {
      for (final shadow in <BoxShadow>[...Shadows.card, ...Shadows.button]) {
        expect(shadow.blurRadius, 0,
            reason: 'the sticker cutout uses a hard, non-blurred offset shadow');
      }
    });

    test('shadow offsets match the spec (3px card, 1.5px button)', () {
      expect(Shadows.card.single.offset, const Offset(3, 3));
      expect(Shadows.button.single.offset, const Offset(1.5, 1.5));
    });

    test('outline is a 1.5px ink border', () {
      expect(Shapes.outlineWidth, 1.5);
      expect(Shapes.outline.top.color, Palette.ink);
    });
  });

  group('palette alpha ladders', () {
    test('every ink alpha token is Palette.ink at the documented opacity', () {
      final ladder = <(String, Color, int)>[
        ('ink08', Palette.ink08, 0x14),
        ('ink12', Palette.ink12, 0x1F),
        ('ink16', Palette.ink16, 0x29),
        ('ink18', Palette.ink18, 0x2E),
        ('ink20', Palette.ink20, 0x33),
        ('ink22', Palette.ink22, 0x38),
        ('ink25', Palette.ink25, 0x40),
        ('ink30', Palette.ink30, 0x4D),
        ('ink35', Palette.ink35, 0x59),
        ('ink40', Palette.ink40, 0x66),
      ];

      for (final (name, color, alpha) in ladder) {
        expect(color.toARGB32() >> 24, alpha,
            reason: 'Palette.$name carries the wrong alpha');
        expect(color.toARGB32() & 0x00FFFFFF,
            Palette.ink.toARGB32() & 0x00FFFFFF,
            reason: 'Palette.$name must be Palette.ink at a reduced opacity');
      }
    });

    test('every coral alpha token is Palette.coral at the documented opacity',
        () {
      final ladder = <(String, Color, int)>[
        ('coral12', Palette.coral12, 0x1F),
        ('coral30', Palette.coral30, 0x4D),
      ];

      for (final (name, color, alpha) in ladder) {
        expect(color.toARGB32() >> 24, alpha,
            reason: 'Palette.$name carries the wrong alpha');
        expect(color.toARGB32() & 0x00FFFFFF,
            Palette.coral.toARGB32() & 0x00FFFFFF,
            reason: 'Palette.$name must be Palette.coral at a reduced opacity');
      }
    });

    test('prototype named colours match their cited source values', () {
      expect(Palette.inkSoft, const Color(0xFF6A5C4A));
      expect(Palette.windowTitle, const Color(0xFFA3866A));
      expect(Palette.recordFill, const Color(0xFFE0574A));
      expect(Palette.dashMuted, const Color(0xFFC3B39A));
      expect(Palette.onAccent, const Color(0xFFFFFFFF));
      expect(Palette.hatchLight, const Color(0xFFECDFC8));
      expect(Palette.hatchMid, const Color(0xFFE2D3BA));
      expect(Palette.hatchDark, const Color(0xFFD9C9AE));
      expect(Palette.viewportDark, const Color(0xFF3A352E));
      expect(Palette.viewportDarkAlt, const Color(0xFF443F37));
    });

    test('pre-existing palette members keep their values', () {
      expect(Palette.ink, const Color(0xFF4A3B2E));
      expect(Palette.coral, const Color(0xFFC76A54));
      expect(Palette.cardWarm, const Color(0xFFF8EFE0));
      expect(Palette.cardBright, const Color(0xFFFFFAF1));
      expect(Palette.panelCoralTint, const Color(0x12C76A54));
      expect(Palette.sunGlow, const Color(0x8CF4C960));
    });
  });

  group('radius ladder', () {
    test('the ladder exposes every prototype step in ascending order', () {
      expect(
        <double>[
          Shapes.radiusXs,
          Shapes.radiusIconButton,
          Shapes.radiusThumb,
          Shapes.radiusCell,
          Shapes.radiusSm,
          Shapes.radiusControl,
          Shapes.radiusPill,
          Shapes.radiusMd,
          Shapes.radiusLg,
          Shapes.radiusXl,
          Shapes.radiusSheet,
        ],
        <double>[6, 8, 9, 10, 11, 12, 13, 14, 16, 20, 22],
      );
    });

    test('derived shapes and dash metrics are unchanged', () {
      expect(Shapes.cardRadius, const Radius.circular(16));
      expect(Shapes.cardBorderRadius, BorderRadius.circular(16));
      expect(Shapes.buttonBorderRadius, BorderRadius.circular(11));
      expect(Shapes.dashLength, 6);
      expect(Shapes.dashGap, 4);
    });
  });

  group('shadow scale', () {
    final hardScale = <(String, List<BoxShadow>, double, Color)>[
      ('chip', Shadows.chip, 1.5, Palette.ink16),
      ('cellFilled', Shadows.cellFilled, 1.5, Palette.ink18),
      ('cellToday', Shadows.cellToday, 1.5, Palette.coral30),
      ('control', Shadows.control, 1.5, Palette.ink),
      ('cardDefault', Shadows.cardDefault, 2.0, Palette.ink16),
      ('emphasis', Shadows.emphasis, 2.0, Palette.ink),
      ('tileSelected', Shadows.tileSelected, 2.0, Palette.coral30),
      ('phoneAction', Shadows.phoneAction, 2.5, Palette.ink),
      ('hero', Shadows.hero, 3.0, Palette.ink20),
      ('heroSoft', Shadows.heroSoft, 3.0, const Color(0x244A3B2E)),
    ];

    test('every hard shadow is one square zero-blur offset in its cited colour',
        () {
      for (final (name, shadow, offset, color) in hardScale) {
        expect(shadow, hasLength(1),
            reason: 'Shadows.$name must be a single hard shadow');
        expect(shadow.single.offset, Offset(offset, offset),
            reason: 'Shadows.$name offset');
        expect(shadow.single.color, color, reason: 'Shadows.$name colour');
        expect(shadow.single.blurRadius, 0, reason: 'Shadows.$name blur');
        expect(shadow.single.spreadRadius, 0, reason: 'Shadows.$name spread');
      }
    });

    test('the blurred lifts carry their cited geometry', () {
      expect(Shadows.softLift.single.color, const Color(0x99322314));
      expect(Shadows.softLift.single.offset, const Offset(0, 20));
      expect(Shadows.softLift.single.blurRadius, 50);
      expect(Shadows.softLift.single.spreadRadius, -16);

      expect(Shadows.panelLift.single.color, const Color(0xB81E140A));
      expect(Shadows.panelLift.single.offset, const Offset(0, 44));
      expect(Shadows.panelLift.single.blurRadius, 96);
      expect(Shadows.panelLift.single.spreadRadius, -30);
    });

    test('the picker and chooser sheet lifts are two distinct tokens', () {
      expect(Shadows.pickerSheetLift.single.color, const Color(0x80322314));
      expect(Shadows.pickerSheetLift.single.offset, const Offset(0, -12));
      expect(Shadows.pickerSheetLift.single.blurRadius, 30);
      expect(Shadows.pickerSheetLift.single.spreadRadius, -12);

      expect(Shadows.chooserSheetLift.single.color, const Color(0x8C322314));
      expect(Shadows.chooserSheetLift.single.offset, const Offset(0, -14));
      expect(Shadows.chooserSheetLift.single.blurRadius, 34);
      expect(Shadows.chooserSheetLift.single.spreadRadius, -14);

      expect(Shadows.pickerSheetLift, isNot(Shadows.chooserSheetLift));
    });

    test('card and button aliases keep their pre-expansion values', () {
      expect(Shadows.card.single.color, const Color(0x334A3B2E));
      expect(Shadows.card.single.offset, const Offset(3, 3));
      expect(Shadows.card.single.blurRadius, 0);
      expect(Shadows.card.single.spreadRadius, 0);

      expect(Shadows.button.single.color, Palette.ink);
      expect(Shadows.button.single.offset, const Offset(1.5, 1.5));
      expect(Shadows.button.single.blurRadius, 0);
      expect(Shadows.button.single.spreadRadius, 0);
    });
  });
}
