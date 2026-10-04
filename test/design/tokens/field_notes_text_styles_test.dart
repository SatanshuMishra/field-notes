import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';

Map<String, TextStyle> _styles(FieldNotesTextStyles styles) =>
    <String, TextStyle>{
      'timerSerif': styles.timerSerif,
      'displaySerifToday': styles.displaySerifToday,
      'displaySerif': styles.displaySerif,
      'titleSerif': styles.titleSerif,
      'headlineSerif': styles.headlineSerif,
      'bannerSerif': styles.bannerSerif,
      'dateSerif': styles.dateSerif,
      'sectionSerif': styles.sectionSerif,
      'bodySerif': styles.bodySerif,
      'bodySerifItalic': styles.bodySerifItalic,
      'noteBody': styles.noteBody,
      'noteBodyItalic': styles.noteBodyItalic,
      'noteBodyPlaceholder': styles.noteBodyPlaceholder,
      'composerBodySerif': styles.composerBodySerif,
      'composerPlaceholderSerif': styles.composerPlaceholderSerif,
      'bodySerifSecondary': styles.bodySerifSecondary,
      'memoryTitleSerif': styles.memoryTitleSerif,
      'wordmarkAccent': styles.wordmarkAccent,
      'streakAccent': styles.streakAccent,
      'sectionHeaderAccent': styles.sectionHeaderAccent,
      'pageEyebrowAccent': styles.pageEyebrowAccent,
      'composerTitleAccent': styles.composerTitleAccent,
      'hintAccent': styles.hintAccent,
      'subtitleAccent': styles.subtitleAccent,
      'windowTitleAccent': styles.windowTitleAccent,
      'stampAccent': styles.stampAccent,
      'promptAccent': styles.promptAccent,
      'buttonSans': styles.buttonSans,
      'labelSans': styles.labelSans,
      'navLabelSans': styles.navLabelSans,
      'bodySans': styles.bodySans,
      'captionSans': styles.captionSans,
      'captureLabelSans': styles.captureLabelSans,
      'toastSans': styles.toastSans,
      'caption11Sans': styles.caption11Sans,
      'toolbarSans': styles.toolbarSans,
      'caption10Sans': styles.caption10Sans,
      'syncPrimarySans': styles.syncPrimarySans,
      'caption9Sans': styles.caption9Sans,
      'caption8Sans': styles.caption8Sans,
      'syncSecondarySans': styles.syncSecondarySans,
      'chipMicroSans': styles.chipMicroSans,
      'viewportMonoLabel': styles.viewportMonoLabel,
      'monoMicroSans': styles.monoMicroSans,
      'monoThumbSans': styles.monoThumbSans,
    };

void main() {
  group('FieldNotesTextStyles', () {
    test('light text styles equal the live typography tokens', () {
      const Color ink = Color(0xFF4A3B2E);
      const Color mutedDeep = Color(0xFF8A7358);
      const Color coral = Color(0xFFB8566A);
      const Color sage = Color(0xFF6D876D);
      const Color muted = Color(0xFFA08A70);

      expect(_styles(const FieldNotesTextStyles(FieldNotesColors.light)), <
        String,
        TextStyle
      >{
        'timerSerif': TypographyTokens.timerSerif.copyWith(color: ink),
        'displaySerifToday': TypographyTokens.displaySerifToday.copyWith(
          color: ink,
        ),
        'displaySerif': TypographyTokens.displaySerif.copyWith(color: ink),
        'titleSerif': TypographyTokens.titleSerif.copyWith(color: ink),
        'headlineSerif': TypographyTokens.headlineSerif.copyWith(color: ink),
        'bannerSerif': TypographyTokens.bannerSerif.copyWith(color: ink),
        'dateSerif': TypographyTokens.dateSerif.copyWith(color: mutedDeep),
        'sectionSerif': TypographyTokens.sectionSerif.copyWith(color: ink),
        'bodySerif': TypographyTokens.bodySerif.copyWith(color: ink),
        'bodySerifItalic': TypographyTokens.bodySerifItalic.copyWith(
          color: ink,
        ),
        'noteBody': TypographyTokens.noteBody.copyWith(color: ink),
        'noteBodyItalic': TypographyTokens.noteBodyItalic.copyWith(color: ink),
        'noteBodyPlaceholder': TypographyTokens.noteBodyPlaceholder.copyWith(
          color: const Color(0x574A3B2E),
        ),
        'composerBodySerif': TypographyTokens.composerBodySerif.copyWith(
          color: ink,
        ),
        'composerPlaceholderSerif': TypographyTokens.composerPlaceholderSerif
            .copyWith(color: const Color(0x574A3B2E)),
        'bodySerifSecondary': TypographyTokens.bodySerifSecondary.copyWith(
          color: mutedDeep,
        ),
        'memoryTitleSerif': TypographyTokens.memoryTitleSerif.copyWith(
          color: ink,
        ),
        'wordmarkAccent': TypographyTokens.wordmarkAccent.copyWith(
          color: coral,
        ),
        'streakAccent': TypographyTokens.streakAccent.copyWith(color: coral),
        'sectionHeaderAccent': TypographyTokens.sectionHeaderAccent.copyWith(
          color: sage,
        ),
        'pageEyebrowAccent': TypographyTokens.pageEyebrowAccent.copyWith(
          color: coral,
        ),
        'composerTitleAccent': TypographyTokens.composerTitleAccent.copyWith(
          color: coral,
        ),
        'hintAccent': TypographyTokens.hintAccent.copyWith(color: muted),
        'subtitleAccent': TypographyTokens.subtitleAccent.copyWith(
          color: muted,
        ),
        'windowTitleAccent': TypographyTokens.windowTitleAccent.copyWith(
          color: const Color(0xFFA3866A),
        ),
        'stampAccent': TypographyTokens.stampAccent.copyWith(color: sage),
        'promptAccent': TypographyTokens.promptAccent.copyWith(color: muted),
        'buttonSans': TypographyTokens.buttonSans.copyWith(color: ink),
        'labelSans': TypographyTokens.labelSans.copyWith(color: ink),
        'navLabelSans': TypographyTokens.navLabelSans,
        'bodySans': TypographyTokens.bodySans.copyWith(color: ink),
        'captionSans': TypographyTokens.captionSans.copyWith(color: muted),
        'captureLabelSans': TypographyTokens.captureLabelSans,
        'toastSans': TypographyTokens.toastSans,
        'caption11Sans': TypographyTokens.caption11Sans.copyWith(color: coral),
        'toolbarSans': TypographyTokens.toolbarSans.copyWith(
          color: const Color(0xFFE9DCC6),
        ),
        'caption10Sans': TypographyTokens.caption10Sans.copyWith(color: muted),
        'syncPrimarySans': TypographyTokens.syncPrimarySans.copyWith(
          color: ink,
        ),
        'caption9Sans': TypographyTokens.caption9Sans.copyWith(color: muted),
        'caption8Sans': TypographyTokens.caption8Sans,
        'syncSecondarySans': TypographyTokens.syncSecondarySans.copyWith(
          color: muted,
        ),
        'chipMicroSans': TypographyTokens.chipMicroSans.copyWith(color: coral),
        'viewportMonoLabel': TypographyTokens.viewportMonoLabel.copyWith(
          color: const Color(0x4DFFFFFF),
        ),
        'monoMicroSans': TypographyTokens.monoMicroSans.copyWith(color: muted),
        'monoThumbSans': TypographyTokens.monoThumbSans.copyWith(
          color: mutedDeep,
        ),
      });
    });

    test('dark text styles take the dark role colours', () {
      const FieldNotesTextStyles styles = FieldNotesTextStyles(
        FieldNotesColors.dark,
      );

      expect(
        styles.bodySans,
        TypographyTokens.bodySans.copyWith(color: const Color(0xFFEDE1E1)),
      );
      expect(
        styles.dateSerif,
        TypographyTokens.dateSerif.copyWith(color: const Color(0xFFB9A9A9)),
      );
      expect(
        styles.pageEyebrowAccent,
        TypographyTokens.pageEyebrowAccent.copyWith(
          color: const Color(0xFFE692A0),
        ),
      );
      expect(
        styles.sectionHeaderAccent,
        TypographyTokens.sectionHeaderAccent.copyWith(
          color: const Color(0xFFA0B9A0),
        ),
      );
      expect(
        styles.captionSans,
        TypographyTokens.captionSans.copyWith(color: const Color(0xFF9F9191)),
      );
      expect(
        styles.windowTitleAccent,
        TypographyTokens.windowTitleAccent.copyWith(
          color: const Color(0xFF837675),
        ),
      );
      expect(
        styles.noteBodyPlaceholder,
        TypographyTokens.noteBodyPlaceholder.copyWith(
          color: const Color(0x57EDE1E1),
        ),
      );
      expect(
        styles.toolbarSans,
        const FieldNotesTextStyles(FieldNotesColors.light).toolbarSans,
      );
      expect(styles.toolbarSans.color, const Color(0xFFE9DCC6));
    });
  });
}
