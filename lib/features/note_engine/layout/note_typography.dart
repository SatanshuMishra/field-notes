import 'package:flutter/painting.dart';

import 'package:field_notes/design/tokens/tokens.dart';

enum GapRole { listItem, heading, other }

double touchingBlockGapEm(GapRole previous, GapRole next) {
  if (previous == GapRole.listItem && next == GapRole.listItem) {
    return NoteTypography.listItemGapEm;
  }
  if (next == GapRole.heading) {
    return NoteTypography.headingGapEm;
  }
  return NoteTypography.paragraphGapEm;
}

abstract final class NoteTypography {
  static const double bodyFontSize = 16;

  static double emOf(TextScaler textScaler) => textScaler.scale(bodyFontSize);

  static const TextStyle body = TypographyTokens.noteBody;

  static TextStyle heading(int level) => switch (level) {
    1 => TypographyTokens.titleSerif,
    2 => TypographyTokens.headlineSerif,
    3 => TypographyTokens.bannerSerif,
    4 => TypographyTokens.bannerSerif.copyWith(fontSize: 18),
    5 => TypographyTokens.bannerSerif.copyWith(fontSize: 17),
    6 => TypographyTokens.bannerSerif.copyWith(fontSize: 16),
    _ => throw ArgumentError.value(level, 'level', 'must be 1 to 6'),
  };

  static TextStyle quoteOf(TextStyle style) =>
      style.copyWith(fontStyle: FontStyle.italic);

  static const TextStyle codeBlock = TextStyle(
    fontFamily: TypographyTokens.mono,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static TextStyle inlineCode(TextStyle base) => TextStyle(
    fontFamily: TypographyTokens.mono,
    fontSize: (base.fontSize ?? bodyFontSize) * codeScale,
  );

  static const TextStyle strong = TextStyle(fontWeight: FontWeight.w700);

  static const TextStyle emphasis = TextStyle(fontStyle: FontStyle.italic);

  static const TextStyle strikethrough = TextStyle(
    decoration: TextDecoration.lineThrough,
  );

  static const TextStyle link = TextStyle(decoration: TextDecoration.underline);

  static const TextStyle caption = TypographyTokens.captionSans;

  static TextStyle withBoldText(TextStyle style, {required bool boldText}) =>
      boldText
          ? style.merge(const TextStyle(fontWeight: FontWeight.bold))
          : style;

  static const double blankLineEm = 1.6;
  static const double listItemGapEm = 0.3;
  static const double headingGapEm = 1.2;
  static const double paragraphGapEm = 0.8;
  static const double listMarkerEm = 1.6;
  static const double minTextEm = 12;
  static const double quoteRuleWidth = 2;
  static const double quoteInsetEm = 0.9;
  static const double codeScale = 0.875;
  static const double codePaddingEm = 0.75;
  static const double codeRadius = Shapes.radiusXs;
  static const double dividerThickness = 1.5;
  static const double dividerPadding = 4;
  static const double dividerDashLength = Shapes.dashLength;
  static const double dividerDashGap = Shapes.dashGap;
  static const double tableGridLineWidth = 1;
  static const FontWeight tableHeaderWeight = FontWeight.w600;
}
