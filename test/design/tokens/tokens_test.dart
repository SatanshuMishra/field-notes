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
      expect(TypographyTokens.sectionHeaderAccent.fontFamily,
          TypographyTokens.accent);
      expect(TypographyTokens.pageEyebrowAccent.fontFamily,
          TypographyTokens.accent);
    });

    test('the mono tokens use the generic family, not a vendored one', () {
      expect(TypographyTokens.mono, 'monospace');
      expect(pubspec, isNot(contains('family: monospace')),
          reason: 'monospace is the CSS generic, never a vendored family');
      expect(TypographyTokens.monoMicroSans.fontFamily, TypographyTokens.mono);
      expect(TypographyTokens.monoMicroSans.fontSize, 7);
      expect(TypographyTokens.monoMicroSans.color, Palette.muted);

      expect(
          TypographyTokens.viewportMonoLabel.fontFamily, TypographyTokens.mono);
      expect(TypographyTokens.viewportMonoLabel.fontSize, 10);
      expect(TypographyTokens.viewportMonoLabel.fontWeight, FontWeight.w500);
      expect(TypographyTokens.viewportMonoLabel.letterSpacing, 1.0);
      expect(TypographyTokens.viewportMonoLabel.color, Palette.onDark30);
      expect(TypographyTokens.monoThumbSans.fontFamily, TypographyTokens.mono);
      expect(TypographyTokens.monoThumbSans.fontSize, 6);
      expect(TypographyTokens.monoThumbSans.color, Palette.mutedDeep);
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
        ('ink34', Palette.ink34, 0x57),
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
      expect(Palette.composerPaper, const Color(0xFFFBF3E4));
      expect(Palette.waveMid, const Color(0xFFDCAE9A));
      expect(Palette.toastInk, const Color(0xFFF6EAD6));
      expect(Palette.viewportAmber, const Color(0xFFF0B34A));
      expect(Palette.viewportAmber, isNot(Palette.statusAmber));
      expect(Palette.viewportScrim, const Color(0x800F0D0B));

      final List<(String, Color, int)> onDark = <(String, Color, int)>[
        ('onDark30', Palette.onDark30, 0x4D),
        ('onDark40', Palette.onDark40, 0x66),
        ('onDark72', Palette.onDark72, 0xB8),
        ('onDark85', Palette.onDark85, 0xD9),
      ];

      for (final (name, color, alpha) in onDark) {
        expect(color.toARGB32() >> 24, alpha,
            reason: 'Palette.$name carries the wrong alpha');
        expect(color.toARGB32() & 0x00FFFFFF,
            Palette.onAccent.toARGB32() & 0x00FFFFFF,
            reason: 'Palette.$name must be white at a reduced opacity');
      }
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

      expect(Shadows.toastLift.single.color, const Color(0x80000000));
      expect(Shadows.toastLift.single.offset, const Offset(0, 10));
      expect(Shadows.toastLift.single.blurRadius, 24);
      expect(Shadows.toastLift.single.spreadRadius, -8);
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

  group('typography roles', () {
    test('the two Caveat roles are distinct in size and colour', () {
      expect(TypographyTokens.pageEyebrowAccent.fontFamily,
          TypographyTokens.accent);
      expect(TypographyTokens.pageEyebrowAccent.fontSize, 16);
      expect(TypographyTokens.pageEyebrowAccent.fontWeight, FontWeight.w600);
      expect(TypographyTokens.pageEyebrowAccent.color, Palette.coral);

      expect(TypographyTokens.sectionHeaderAccent.fontFamily,
          TypographyTokens.accent);
      expect(TypographyTokens.sectionHeaderAccent.fontSize, 17);
      expect(TypographyTokens.sectionHeaderAccent.fontWeight, FontWeight.w600);
      expect(TypographyTokens.sectionHeaderAccent.color, Palette.sage);

      expect(TypographyTokens.pageEyebrowAccent.color,
          isNot(TypographyTokens.sectionHeaderAccent.color),
          reason: 'the page eyebrow and the section header are two roles');
      expect(TypographyTokens.pageEyebrowAccent.fontSize,
          isNot(TypographyTokens.sectionHeaderAccent.fontSize));
    });

    test('the retuned tokens carry their prototype metrics', () {
      expect(TypographyTokens.bodySerif.fontSize, 13.5);
      expect(TypographyTokens.bodySerif.fontWeight, FontWeight.w400);
      expect(TypographyTokens.bodySerif.height, 1.5);

      expect(TypographyTokens.displaySerif.fontSize, 32);
      expect(TypographyTokens.displaySerif.fontWeight, FontWeight.w500);
      expect(TypographyTokens.displaySerif.height, 1.0);

      expect(TypographyTokens.captionSans.fontSize, 12);
      expect(TypographyTokens.captionSans.fontWeight, FontWeight.w400);
      expect(TypographyTokens.captionSans.color, Palette.muted);

      expect(TypographyTokens.streakAccent.fontSize, 24);
      expect(TypographyTokens.streakAccent.height, 1.0);
      expect(TypographyTokens.streakAccent.color, Palette.coral);

      expect(TypographyTokens.wordmarkAccent.fontSize, 23);
      expect(TypographyTokens.wordmarkAccent.height, 0.85);
      expect(TypographyTokens.wordmarkAccent.color, Palette.coral);

      expect(TypographyTokens.bodySerifItalic.fontSize,
          TypographyTokens.bodySerif.fontSize,
          reason: 'the italic body face shares the roman body metric');
      expect(TypographyTokens.bodySerifItalic.fontStyle, FontStyle.italic);

      expect(TypographyTokens.composerBodySerif.fontFamily,
          TypographyTokens.serif);
      expect(TypographyTokens.composerBodySerif.fontSize, 19);
      expect(TypographyTokens.composerBodySerif.fontWeight, FontWeight.w400);
      expect(TypographyTokens.composerBodySerif.height, 2.0);
      expect(TypographyTokens.composerBodySerif.color, Palette.ink);

      expect(TypographyTokens.composerPlaceholderSerif.fontSize,
          TypographyTokens.composerBodySerif.fontSize);
      expect(TypographyTokens.composerPlaceholderSerif.height,
          TypographyTokens.composerBodySerif.height);
      expect(
          TypographyTokens.composerPlaceholderSerif.fontStyle,
          FontStyle.italic);
      expect(TypographyTokens.composerPlaceholderSerif.color, Palette.ink34);
    });

    test('the serif ladder descends through every prototype size', () {
      expect(
        <double?>[
          TypographyTokens.displaySerifToday.fontSize,
          TypographyTokens.headlineSerif.fontSize,
          TypographyTokens.bannerSerif.fontSize,
          TypographyTokens.sectionSerif.fontSize,
          TypographyTokens.bodySerifSecondary.fontSize,
          TypographyTokens.memoryTitleSerif.fontSize,
        ],
        <double>[34, 21, 19, 17, 12, 12],
      );

      for (final TextStyle style in <TextStyle>[
        TypographyTokens.displaySerifToday,
        TypographyTokens.headlineSerif,
        TypographyTokens.bannerSerif,
        TypographyTokens.sectionSerif,
        TypographyTokens.bodySerifSecondary,
        TypographyTokens.memoryTitleSerif,
      ]) {
        expect(style.fontFamily, TypographyTokens.serif);
      }

      expect(TypographyTokens.displaySerifToday.height, 1.0);
      expect(TypographyTokens.bodySerifSecondary.color, Palette.mutedDeep);

      expect(TypographyTokens.timerSerif.fontFamily, TypographyTokens.serif);
      expect(TypographyTokens.timerSerif.fontSize, 38);
      expect(TypographyTokens.timerSerif.fontWeight, FontWeight.w400);
      expect(TypographyTokens.timerSerif.color, Palette.ink);
    });

    test('the caption ladder descends and stays on the sans family', () {
      final List<(TextStyle, double)> ladder = <(TextStyle, double)>[
        (TypographyTokens.caption11Sans, 11),
        (TypographyTokens.caption10Sans, 10),
        (TypographyTokens.caption9Sans, 9),
        (TypographyTokens.caption8Sans, 8),
      ];

      for (final (TextStyle style, double size) in ladder) {
        expect(style.fontFamily, TypographyTokens.sans);
        expect(style.fontSize, size);
      }

      expect(TypographyTokens.caption11Sans.color, Palette.coral);
      expect(TypographyTokens.caption10Sans.color, Palette.muted);
      expect(TypographyTokens.caption9Sans.color, Palette.muted);
    });

    test('state-coloured tokens leave colour to the call site', () {
      expect(TypographyTokens.navLabelSans.color, isNull);
      expect(TypographyTokens.captureLabelSans.color, isNull);
      expect(TypographyTokens.caption8Sans.color, isNull);
    });

    test('the micro chip token carries 0.08em of tracking at 8px', () {
      expect(TypographyTokens.chipMicroSans.fontSize, 8);
      expect(TypographyTokens.chipMicroSans.letterSpacing, 0.64);
      expect(TypographyTokens.chipMicroSans.color, Palette.coral);
    });

    test('the accent roles carry their cited prototype metrics', () {
      expect(TypographyTokens.stampAccent.fontSize, 13);
      expect(TypographyTokens.stampAccent.color, Palette.sage);
      expect(TypographyTokens.promptAccent.fontSize, 13);
      expect(TypographyTokens.promptAccent.color, Palette.muted);
      expect(TypographyTokens.subtitleAccent.fontSize, 14);
      expect(TypographyTokens.subtitleAccent.color, Palette.muted);
      expect(TypographyTokens.composerTitleAccent.fontSize, 16);
      expect(TypographyTokens.composerTitleAccent.color, Palette.coral);
      expect(TypographyTokens.hintAccent.fontFamily, TypographyTokens.accent);
      expect(TypographyTokens.hintAccent.fontSize, 15);
      expect(TypographyTokens.hintAccent.fontWeight, FontWeight.w600);
      expect(TypographyTokens.hintAccent.color, Palette.muted);
      expect(TypographyTokens.windowTitleAccent.fontSize, 14);
      expect(TypographyTokens.windowTitleAccent.color, Palette.windowTitle);

      for (final TextStyle style in <TextStyle>[
        TypographyTokens.stampAccent,
        TypographyTokens.promptAccent,
        TypographyTokens.subtitleAccent,
        TypographyTokens.composerTitleAccent,
        TypographyTokens.windowTitleAccent,
      ]) {
        expect(style.fontFamily, TypographyTokens.accent);
        expect(style.fontWeight, FontWeight.w600);
      }
    });

    test('the sync pair splits weight and colour by rank', () {
      expect(TypographyTokens.syncPrimarySans.fontSize, 10);
      expect(TypographyTokens.syncPrimarySans.fontWeight, FontWeight.w600);
      expect(TypographyTokens.syncPrimarySans.color, Palette.ink);

      expect(TypographyTokens.syncSecondarySans.fontSize, 8);
      expect(TypographyTokens.syncSecondarySans.fontWeight, FontWeight.w400);
      expect(TypographyTokens.syncSecondarySans.color, Palette.muted);
    });
  });
}
