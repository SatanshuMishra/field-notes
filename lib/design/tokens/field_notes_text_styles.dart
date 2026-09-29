import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'field_notes_colors.dart';
import 'palette.dart';
import 'typography.dart';

@immutable
class FieldNotesTextStyles {
  const FieldNotesTextStyles(this.colors);

  final FieldNotesColors colors;

  TextStyle get timerSerif =>
      TypographyTokens.timerSerif.copyWith(color: colors.ink);

  TextStyle get displaySerifToday =>
      TypographyTokens.displaySerifToday.copyWith(color: colors.ink);

  TextStyle get displaySerif =>
      TypographyTokens.displaySerif.copyWith(color: colors.ink);

  TextStyle get titleSerif =>
      TypographyTokens.titleSerif.copyWith(color: colors.ink);

  TextStyle get headlineSerif =>
      TypographyTokens.headlineSerif.copyWith(color: colors.ink);

  TextStyle get bannerSerif =>
      TypographyTokens.bannerSerif.copyWith(color: colors.ink);

  TextStyle get dateSerif =>
      TypographyTokens.dateSerif.copyWith(color: colors.mutedDeep);

  TextStyle get sectionSerif =>
      TypographyTokens.sectionSerif.copyWith(color: colors.ink);

  TextStyle get bodySerif =>
      TypographyTokens.bodySerif.copyWith(color: colors.ink);

  TextStyle get bodySerifItalic =>
      TypographyTokens.bodySerifItalic.copyWith(color: colors.ink);

  TextStyle get noteBody =>
      TypographyTokens.noteBody.copyWith(color: colors.ink);

  TextStyle get noteBodyItalic =>
      TypographyTokens.noteBodyItalic.copyWith(color: colors.ink);

  TextStyle get noteBodyPlaceholder =>
      TypographyTokens.noteBodyPlaceholder.copyWith(color: colors.ink34);

  TextStyle get composerBodySerif => noteBody;

  TextStyle get composerPlaceholderSerif => noteBodyPlaceholder;

  TextStyle get bodySerifSecondary =>
      TypographyTokens.bodySerifSecondary.copyWith(color: colors.mutedDeep);

  TextStyle get memoryTitleSerif =>
      TypographyTokens.memoryTitleSerif.copyWith(color: colors.ink);

  TextStyle get wordmarkAccent =>
      TypographyTokens.wordmarkAccent.copyWith(color: colors.accentInk);

  TextStyle get streakAccent =>
      TypographyTokens.streakAccent.copyWith(color: colors.accentInk);

  TextStyle get sectionHeaderAccent =>
      TypographyTokens.sectionHeaderAccent.copyWith(color: colors.sage);

  TextStyle get pageEyebrowAccent =>
      TypographyTokens.pageEyebrowAccent.copyWith(color: colors.accentInk);

  TextStyle get composerTitleAccent =>
      TypographyTokens.composerTitleAccent.copyWith(color: colors.accentInk);

  TextStyle get hintAccent =>
      TypographyTokens.hintAccent.copyWith(color: colors.muted);

  TextStyle get subtitleAccent =>
      TypographyTokens.subtitleAccent.copyWith(color: colors.muted);

  TextStyle get windowTitleAccent =>
      TypographyTokens.windowTitleAccent.copyWith(color: colors.windowTitle);

  TextStyle get stampAccent =>
      TypographyTokens.stampAccent.copyWith(color: colors.sage);

  TextStyle get promptAccent =>
      TypographyTokens.promptAccent.copyWith(color: colors.muted);

  TextStyle get buttonSans =>
      TypographyTokens.buttonSans.copyWith(color: colors.ink);

  TextStyle get labelSans =>
      TypographyTokens.labelSans.copyWith(color: colors.ink);

  TextStyle get navLabelSans => TypographyTokens.navLabelSans;

  TextStyle get bodySans =>
      TypographyTokens.bodySans.copyWith(color: colors.ink);

  TextStyle get captionSans =>
      TypographyTokens.captionSans.copyWith(color: colors.muted);

  TextStyle get captureLabelSans => TypographyTokens.captureLabelSans;

  TextStyle get toastSans => TypographyTokens.toastSans;

  TextStyle get caption11Sans =>
      TypographyTokens.caption11Sans.copyWith(color: colors.accentInk);

  TextStyle get toolbarSans =>
      TypographyTokens.toolbarSans.copyWith(color: Palette.toolbarLabel);

  TextStyle get caption10Sans =>
      TypographyTokens.caption10Sans.copyWith(color: colors.muted);

  TextStyle get syncPrimarySans =>
      TypographyTokens.syncPrimarySans.copyWith(color: colors.ink);

  TextStyle get caption9Sans =>
      TypographyTokens.caption9Sans.copyWith(color: colors.muted);

  TextStyle get caption8Sans => TypographyTokens.caption8Sans;

  TextStyle get syncSecondarySans =>
      TypographyTokens.syncSecondarySans.copyWith(color: colors.muted);

  TextStyle get chipMicroSans =>
      TypographyTokens.chipMicroSans.copyWith(color: colors.accentInk);

  TextStyle get viewportMonoLabel =>
      TypographyTokens.viewportMonoLabel.copyWith(color: Palette.onDark30);

  TextStyle get monoMicroSans =>
      TypographyTokens.monoMicroSans.copyWith(color: colors.muted);

  TextStyle get monoThumbSans =>
      TypographyTokens.monoThumbSans.copyWith(color: colors.mutedDeep);
}
