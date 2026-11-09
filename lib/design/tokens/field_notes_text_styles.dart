import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'field_notes_colors.dart';
import 'palette.dart';
import 'typography.dart';

const TextStyle _displayRole = TextStyle(
  fontFamily: TypographyTokens.serif,
  fontSize: 34,
  fontWeight: FontWeight.w500,
  height: 1.05,
  letterSpacing: -0.34,
);

const TextStyle _titleRole = TextStyle(
  fontFamily: TypographyTokens.serif,
  fontSize: 24,
  fontWeight: FontWeight.w500,
  height: 1.2,
);

const TextStyle _headingRole = TextStyle(
  fontFamily: TypographyTokens.serif,
  fontSize: 17,
  fontWeight: FontWeight.w500,
  height: 1.3,
);

const TextStyle _bodyRole = TextStyle(
  fontFamily: TypographyTokens.serif,
  fontSize: 15,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const TextStyle _uiRole = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 14,
  fontWeight: FontWeight.w500,
  height: 1.4,
);

const TextStyle _labelRole = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 13,
  fontWeight: FontWeight.w600,
  height: 1.4,
);

const TextStyle _captionRole = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.4,
);

const TextStyle _microRole = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  height: 1.3,
);

const TextStyle _accentRole = TextStyle(
  fontFamily: TypographyTokens.accent,
  fontSize: 18,
  fontWeight: FontWeight.w600,
  height: 1.15,
);

const TextStyle _sectionRole = TextStyle(
  fontFamily: TypographyTokens.accent,
  fontSize: 19,
  fontWeight: FontWeight.w600,
  height: 1.1,
);

@immutable
class FieldNotesTextStyles {
  const FieldNotesTextStyles(this.colors);

  final FieldNotesColors colors;

  TextStyle get display => _displayRole.copyWith(color: colors.ink);

  TextStyle get title => _titleRole.copyWith(color: colors.ink);

  TextStyle get heading => _headingRole.copyWith(color: colors.ink);

  TextStyle get body => _bodyRole.copyWith(color: colors.ink);

  TextStyle get ui => _uiRole.copyWith(color: colors.ink);

  TextStyle get label => _labelRole.copyWith(color: colors.ink);

  TextStyle get caption => _captionRole.copyWith(color: colors.muted);

  TextStyle get micro => _microRole.copyWith(color: colors.muted);

  TextStyle get accent => _accentRole.copyWith(color: colors.accentInk);

  TextStyle get section => _sectionRole.copyWith(color: colors.sage);

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
