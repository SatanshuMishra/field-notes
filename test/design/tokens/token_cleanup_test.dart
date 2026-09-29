import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';

import '../../support/theme_harness.dart';

const String _palettePath = 'lib/design/tokens/palette.dart';
const String _typographyPath = 'lib/design/tokens/typography.dart';
const String _shadowsPath = 'lib/design/tokens/shadows.dart';
const String _shapesPath = 'lib/design/tokens/shapes.dart';

const Set<String> _lightOnlyPalette = <String>{
  'page',
  'pageGradientInner',
  'pageGradientOuter',
  'panelTop',
  'panelBottom',
  'cardWarm',
  'cardLight',
  'cardBright',
  'cardAlt',
  'composerPaper',
  'ink',
  'inkSoft',
  'ink08',
  'ink12',
  'ink16',
  'ink18',
  'ink20',
  'ink22',
  'ink25',
  'ink30',
  'ink34',
  'ink35',
  'ink40',
  'coralHover',
  'coralLink',
  'waveMid',
  'waveLight',
  'sage',
  'muted',
  'mutedDeep',
  'placeholder',
  'dashMuted',
  'dangerSurface',
  'focusRing',
  'titleBar',
  'windowTitle',
  'hatchLight',
  'hatchMid',
  'hatchDark',
};

const Set<String> _inkShadows = <String>{
  'chip',
  'cellFilled',
  'control',
  'cardDefault',
  'emphasis',
  'phoneAction',
  'hero',
  'heroSoft',
  'card',
  'button',
};

const Map<String, TextStyle> _typography = <String, TextStyle>{
  'timerSerif': TypographyTokens.timerSerif,
  'displaySerifToday': TypographyTokens.displaySerifToday,
  'displaySerif': TypographyTokens.displaySerif,
  'titleSerif': TypographyTokens.titleSerif,
  'headlineSerif': TypographyTokens.headlineSerif,
  'bannerSerif': TypographyTokens.bannerSerif,
  'dateSerif': TypographyTokens.dateSerif,
  'sectionSerif': TypographyTokens.sectionSerif,
  'bodySerif': TypographyTokens.bodySerif,
  'bodySerifItalic': TypographyTokens.bodySerifItalic,
  'noteBody': TypographyTokens.noteBody,
  'noteBodyItalic': TypographyTokens.noteBodyItalic,
  'noteBodyPlaceholder': TypographyTokens.noteBodyPlaceholder,
  'composerBodySerif': TypographyTokens.composerBodySerif,
  'composerPlaceholderSerif': TypographyTokens.composerPlaceholderSerif,
  'bodySerifSecondary': TypographyTokens.bodySerifSecondary,
  'memoryTitleSerif': TypographyTokens.memoryTitleSerif,
  'wordmarkAccent': TypographyTokens.wordmarkAccent,
  'streakAccent': TypographyTokens.streakAccent,
  'sectionHeaderAccent': TypographyTokens.sectionHeaderAccent,
  'pageEyebrowAccent': TypographyTokens.pageEyebrowAccent,
  'composerTitleAccent': TypographyTokens.composerTitleAccent,
  'hintAccent': TypographyTokens.hintAccent,
  'subtitleAccent': TypographyTokens.subtitleAccent,
  'windowTitleAccent': TypographyTokens.windowTitleAccent,
  'stampAccent': TypographyTokens.stampAccent,
  'promptAccent': TypographyTokens.promptAccent,
  'buttonSans': TypographyTokens.buttonSans,
  'labelSans': TypographyTokens.labelSans,
  'navLabelSans': TypographyTokens.navLabelSans,
  'bodySans': TypographyTokens.bodySans,
  'captionSans': TypographyTokens.captionSans,
  'captureLabelSans': TypographyTokens.captureLabelSans,
  'toastSans': TypographyTokens.toastSans,
  'caption11Sans': TypographyTokens.caption11Sans,
  'toolbarSans': TypographyTokens.toolbarSans,
  'caption10Sans': TypographyTokens.caption10Sans,
  'syncPrimarySans': TypographyTokens.syncPrimarySans,
  'caption9Sans': TypographyTokens.caption9Sans,
  'caption8Sans': TypographyTokens.caption8Sans,
  'syncSecondarySans': TypographyTokens.syncSecondarySans,
  'chipMicroSans': TypographyTokens.chipMicroSans,
  'viewportMonoLabel': TypographyTokens.viewportMonoLabel,
  'monoMicroSans': TypographyTokens.monoMicroSans,
  'monoThumbSans': TypographyTokens.monoThumbSans,
};

final RegExp _declaration = RegExp(r'\bstatic\s+const\s+([\w<>]+)\s+(\w+)\s*=');

Map<String, String> _declared(String path) => <String, String>{
  for (final Match match in _declaration.allMatches(
    File(path).readAsStringSync(),
  ))
    match[2]!: match[1]!,
};

void main() {
  test('the palette keeps only colours that are the same in both themes', () {
    final Map<String, String> palette = _declared(_palettePath);

    expect(palette.keys, isNot(isEmpty));
    expect(palette.keys.toSet().intersection(_lightOnlyPalette), isEmpty);
  });

  test('typography tokens carry no colour', () {
    final Map<String, String> declared = _declared(_typographyPath);
    final Set<String> styles = <String>{
      for (final MapEntry<String, String> entry in declared.entries)
        if (entry.value == 'TextStyle') entry.key,
    };

    expect(_typography.keys.toSet(), styles);
    expect(<String, Color?>{
      for (final MapEntry<String, TextStyle> entry in _typography.entries)
        if (entry.value.color != null) entry.key: entry.value.color,
    }, isEmpty);
  });

  test('shadows and shapes carry no ink shadow or outline', () {
    final Map<String, String> shadows = _declared(_shadowsPath);
    final Map<String, String> shapes = _declared(_shapesPath);

    expect(shadows.keys, isNot(isEmpty));
    expect(shadows.keys.toSet().intersection(_inkShadows), isEmpty);
    expect(shapes.keys, contains('outlineWidth'));
    expect(shapes.keys, isNot(contains('outline')));
  });

  test('no source outside the theme names a light-only colour', () {
    expect(lightOnlyTokenUses(<String>['lib']), isEmpty);
  });
}
