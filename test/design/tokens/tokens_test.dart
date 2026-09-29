import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';

const FieldNotesColors _light = FieldNotesColors.light;
const FieldNotesTextStyles _styles = FieldNotesTextStyles(_light);
const FieldNotesShadows _shadows = FieldNotesShadows(_light);

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
      expect(TypographyTokens.noteBody.fontFamily, TypographyTokens.serif);
      expect(TypographyTokens.noteBody.fontSize, 16);
      expect(TypographyTokens.noteBody.height, 1.6);
      expect(TypographyTokens.noteBody.fontWeight, FontWeight.w400);
      expect(_styles.noteBody.color, _light.ink);
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
      expect(_styles.monoMicroSans.color, _light.muted);

      expect(
          TypographyTokens.viewportMonoLabel.fontFamily, TypographyTokens.mono);
      expect(TypographyTokens.viewportMonoLabel.fontSize, 10);
      expect(TypographyTokens.viewportMonoLabel.fontWeight, FontWeight.w500);
      expect(TypographyTokens.viewportMonoLabel.letterSpacing, 1.0);
      expect(_styles.viewportMonoLabel.color, Palette.onDark30);
      expect(TypographyTokens.monoThumbSans.fontFamily, TypographyTokens.mono);
      expect(TypographyTokens.monoThumbSans.fontSize, 6);
      expect(_styles.monoThumbSans.color, _light.mutedDeep);
    });
  });

  group('sticker-cutout surface tokens', () {
    test('card and button shadows are hard non-blurred offsets', () {
      for (final shadow in <BoxShadow>[..._shadows.card, ..._shadows.button]) {
        expect(shadow.blurRadius, 0,
            reason: 'the sticker cutout uses a hard, non-blurred offset shadow');
      }
    });

    test('shadow offsets match the spec (3px card, 1.5px button)', () {
      expect(_shadows.card.single.offset, const Offset(3, 3));
      expect(_shadows.button.single.offset, const Offset(1.5, 1.5));
    });

    test('outline is a 1.5px ink border', () {
      expect(Shapes.outlineWidth, 1.5);
      expect(_shadows.outline.top.color, _light.ink);
    });
  });

  group('palette alpha ladders', () {
    test('every ink alpha token is the light ink at the documented opacity',
        () {
      final ladder = <(String, Color, int)>[
        ('ink08', _light.ink08, 0x14),
        ('ink12', _light.ink12, 0x1F),
        ('ink16', _light.ink16, 0x29),
        ('ink18', _light.ink18, 0x2E),
        ('ink20', _light.ink20, 0x33),
        ('ink22', _light.ink22, 0x38),
        ('ink25', _light.ink25, 0x40),
        ('ink30', _light.ink30, 0x4D),
        ('ink34', _light.ink34, 0x57),
        ('ink35', _light.ink35, 0x59),
        ('ink40', _light.ink40, 0x66),
      ];

      for (final (name, color, alpha) in ladder) {
        expect(color.toARGB32() >> 24, alpha,
            reason: 'FieldNotesColors.light.$name carries the wrong alpha');
        expect(color.toARGB32() & 0x00FFFFFF,
            _light.ink.toARGB32() & 0x00FFFFFF,
            reason: 'FieldNotesColors.light.$name must be the light ink at a '
                'reduced opacity');
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
      expect(_light.inkSoft, const Color(0xFF6A5C4A));
      expect(_light.windowTitle, const Color(0xFFA3866A));
      expect(Palette.recordFill, const Color(0xFFE0574A));
      expect(_light.dashMuted, const Color(0xFFC3B39A));
      expect(Palette.onAccent, const Color(0xFFFFFFFF));
      expect(_light.hatchLight, const Color(0xFFECDFC8));
      expect(_light.hatchMid, const Color(0xFFE2D3BA));
      expect(_light.hatchDark, const Color(0xFFD9C9AE));
      expect(Palette.viewportDark, const Color(0xFF3A352E));
      expect(Palette.viewportDarkAlt, const Color(0xFF443F37));
      expect(_light.composerPaper, const Color(0xFFFBF3E4));
      expect(_light.waveMid, const Color(0xFFDCAE9A));
      expect(_light.waveLight, const Color(0xFFE3C4B2));
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
      expect(_light.ink, const Color(0xFF4A3B2E));
      expect(Palette.coral, const Color(0xFFC76A54));
      expect(_light.cardWarm, const Color(0xFFF8EFE0));
      expect(_light.cardBright, const Color(0xFFFFFAF1));
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
      ('chip', _shadows.chip, 1.5, _light.ink16),
      ('cellFilled', _shadows.cellFilled, 1.5, _light.ink18),
      ('cellToday', Shadows.cellToday, 1.5, Palette.coral30),
      ('control', _shadows.control, 1.5, _light.ink),
      ('cardDefault', _shadows.cardDefault, 2.0, _light.ink16),
      ('emphasis', _shadows.emphasis, 2.0, _light.ink),
      ('tileSelected', Shadows.tileSelected, 2.0, Palette.coral30),
      ('phoneAction', _shadows.phoneAction, 2.5, _light.ink),
      ('hero', _shadows.hero, 3.0, _light.ink20),
      ('heroSoft', _shadows.heroSoft, 3.0, const Color(0x244A3B2E)),
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
      expect(_shadows.card.single.color, const Color(0x334A3B2E));
      expect(_shadows.card.single.offset, const Offset(3, 3));
      expect(_shadows.card.single.blurRadius, 0);
      expect(_shadows.card.single.spreadRadius, 0);

      expect(_shadows.button.single.color, _light.ink);
      expect(_shadows.button.single.offset, const Offset(1.5, 1.5));
      expect(_shadows.button.single.blurRadius, 0);
      expect(_shadows.button.single.spreadRadius, 0);
    });
  });

  group('typography roles', () {
    test('the two Caveat roles are distinct in size and colour', () {
      expect(TypographyTokens.pageEyebrowAccent.fontFamily,
          TypographyTokens.accent);
      expect(TypographyTokens.pageEyebrowAccent.fontSize, 16);
      expect(TypographyTokens.pageEyebrowAccent.fontWeight, FontWeight.w600);
      expect(_styles.pageEyebrowAccent.color, Palette.coral);

      expect(TypographyTokens.sectionHeaderAccent.fontFamily,
          TypographyTokens.accent);
      expect(TypographyTokens.sectionHeaderAccent.fontSize, 17);
      expect(TypographyTokens.sectionHeaderAccent.fontWeight, FontWeight.w600);
      expect(_styles.sectionHeaderAccent.color, _light.sage);

      expect(_styles.pageEyebrowAccent.color,
          isNot(_styles.sectionHeaderAccent.color),
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
      expect(_styles.captionSans.color, _light.muted);

      expect(TypographyTokens.streakAccent.fontSize, 24);
      expect(TypographyTokens.streakAccent.height, 1.0);
      expect(_styles.streakAccent.color, Palette.coral);

      expect(TypographyTokens.wordmarkAccent.fontSize, 23);
      expect(TypographyTokens.wordmarkAccent.height, 0.85);
      expect(_styles.wordmarkAccent.color, Palette.coral);

      expect(TypographyTokens.bodySerifItalic.fontSize,
          TypographyTokens.bodySerif.fontSize,
          reason: 'the italic body face shares the roman body metric');
      expect(TypographyTokens.bodySerifItalic.fontStyle, FontStyle.italic);

      expect(TypographyTokens.composerBodySerif, TypographyTokens.noteBody,
          reason: 'the composer writes in the exact style the reader reads');
      expect(TypographyTokens.composerBodySerif.fontFamily,
          TypographyTokens.serif);
      expect(TypographyTokens.composerBodySerif.fontSize, 16);
      expect(TypographyTokens.composerBodySerif.fontWeight, FontWeight.w400);
      expect(TypographyTokens.composerBodySerif.height, 1.6);
      expect(_styles.composerBodySerif.color, _light.ink);

      expect(TypographyTokens.composerPlaceholderSerif,
          TypographyTokens.noteBodyPlaceholder);
      expect(TypographyTokens.composerPlaceholderSerif.fontSize,
          TypographyTokens.composerBodySerif.fontSize);
      expect(TypographyTokens.composerPlaceholderSerif.height,
          TypographyTokens.composerBodySerif.height);
      expect(
          TypographyTokens.composerPlaceholderSerif.fontStyle,
          FontStyle.italic);
      expect(_styles.composerPlaceholderSerif.color, _light.ink34);
    });

    test('the note body family shares one metric across its three faces', () {
      for (final TextStyle style in <TextStyle>[
        TypographyTokens.noteBody,
        TypographyTokens.noteBodyItalic,
        TypographyTokens.noteBodyPlaceholder,
      ]) {
        expect(style.fontFamily, TypographyTokens.serif);
        expect(style.fontSize, TypographyTokens.noteBody.fontSize);
        expect(style.height, TypographyTokens.noteBody.height);
        expect(style.fontWeight, FontWeight.w400);
      }
      expect(TypographyTokens.noteBodyItalic.fontStyle, FontStyle.italic);
      expect(_styles.noteBodyItalic.color, _light.ink);
      expect(TypographyTokens.noteBodyPlaceholder.fontStyle, FontStyle.italic);
      expect(_styles.noteBodyPlaceholder.color, _light.ink34);
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
      expect(_styles.bodySerifSecondary.color, _light.mutedDeep);

      expect(TypographyTokens.timerSerif.fontFamily, TypographyTokens.serif);
      expect(TypographyTokens.timerSerif.fontSize, 38);
      expect(TypographyTokens.timerSerif.fontWeight, FontWeight.w400);
      expect(_styles.timerSerif.color, _light.ink);
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

      expect(_styles.caption11Sans.color, Palette.coral);
      expect(_styles.caption10Sans.color, _light.muted);
      expect(_styles.caption9Sans.color, _light.muted);
    });

    test('state-coloured tokens leave colour to the call site', () {
      expect(TypographyTokens.navLabelSans.color, isNull);
      expect(TypographyTokens.captureLabelSans.color, isNull);
      expect(TypographyTokens.caption8Sans.color, isNull);
    });

    test('the micro chip token carries 0.08em of tracking at 8px', () {
      expect(TypographyTokens.chipMicroSans.fontSize, 8);
      expect(TypographyTokens.chipMicroSans.letterSpacing, 0.64);
      expect(_styles.chipMicroSans.color, Palette.coral);
    });

    test('the accent roles carry their cited prototype metrics', () {
      expect(TypographyTokens.stampAccent.fontSize, 13);
      expect(_styles.stampAccent.color, _light.sage);
      expect(TypographyTokens.promptAccent.fontSize, 13);
      expect(_styles.promptAccent.color, _light.muted);
      expect(TypographyTokens.subtitleAccent.fontSize, 14);
      expect(_styles.subtitleAccent.color, _light.muted);
      expect(TypographyTokens.composerTitleAccent.fontSize, 16);
      expect(_styles.composerTitleAccent.color, Palette.coral);
      expect(TypographyTokens.hintAccent.fontFamily, TypographyTokens.accent);
      expect(TypographyTokens.hintAccent.fontSize, 15);
      expect(TypographyTokens.hintAccent.fontWeight, FontWeight.w600);
      expect(_styles.hintAccent.color, _light.muted);
      expect(TypographyTokens.windowTitleAccent.fontSize, 14);
      expect(_styles.windowTitleAccent.color, _light.windowTitle);

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
      expect(_styles.syncPrimarySans.color, _light.ink);

      expect(TypographyTokens.syncSecondarySans.fontSize, 8);
      expect(TypographyTokens.syncSecondarySans.fontWeight, FontWeight.w400);
      expect(_styles.syncSecondarySans.color, _light.muted);
    });
  });
}
