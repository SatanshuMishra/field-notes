import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/note_engine/layout/note_typography.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'heading levels four to six use banner serif at eighteen, seventeen and sixteen',
    () {
      const List<int> levels = <int>[4, 5, 6];
      const List<double> sizes = <double>[18, 17, 16];
      for (int i = 0; i < levels.length; i++) {
        final TextStyle style = NoteTypography.heading(levels[i]);
        expect(style, TypographyTokens.bannerSerif.copyWith(fontSize: sizes[i]));
        expect(style.fontFamily, TypographyTokens.serif);
        expect(style.fontWeight, FontWeight.w500);
        expect(style.color, Palette.ink);
      }
    },
  );

  test('highlight uses the palette highlight token', () {
    expect(Palette.highlight, const Color(0x8CF2D77E));
    expect(Palette.highlight.toARGB32() >> 24, 0x8C);
    expect(Palette.highlight.toARGB32() & 0x00FFFFFF, 0xF2D77E);
    expect(NoteTypography.highlight.backgroundColor, Palette.highlight);
  });

  test('block gaps between touching blocks follow the reader rules', () {
    expect(touchingBlockGapEm(GapRole.listItem, GapRole.listItem), 0.3);
    expect(touchingBlockGapEm(GapRole.other, GapRole.heading), 1.2);
    expect(touchingBlockGapEm(GapRole.listItem, GapRole.heading), 1.2);
    expect(touchingBlockGapEm(GapRole.heading, GapRole.heading), 1.2);
    expect(touchingBlockGapEm(GapRole.other, GapRole.other), 0.8);
    expect(touchingBlockGapEm(GapRole.heading, GapRole.other), 0.8);
    expect(touchingBlockGapEm(GapRole.listItem, GapRole.other), 0.8);
    expect(touchingBlockGapEm(GapRole.other, GapRole.listItem), 0.8);
    expect(
      NoteTypography.blankLineEm * NoteTypography.emOf(TextScaler.noScaling),
      closeTo(25.6, 1e-9),
    );
  });

  test('heading levels one to three equal the reader serif styles', () {
    expect(NoteTypography.heading(1), TypographyTokens.titleSerif);
    expect(NoteTypography.heading(2), TypographyTokens.headlineSerif);
    expect(NoteTypography.heading(3), TypographyTokens.bannerSerif);
  });

  test('heading throws for levels outside one to six', () {
    expect(() => NoteTypography.heading(0), throwsArgumentError);
    expect(() => NoteTypography.heading(7), throwsArgumentError);
  });

  test('body equals the reader body style', () {
    expect(NoteTypography.body, TypographyTokens.noteBody);
  });

  test('quote is italic Palette.inkSoft at sixteen with height 1.6', () {
    expect(NoteTypography.quote.fontStyle, FontStyle.italic);
    expect(NoteTypography.quote.color, Palette.inkSoft);
    expect(NoteTypography.quote.fontSize, 16);
    expect(NoteTypography.quote.height, 1.6);
  });

  test('quoteOf keeps the base size and weight and adds the quote look', () {
    final TextStyle style = NoteTypography.quoteOf(NoteTypography.heading(2));
    expect(style.fontSize, 21);
    expect(style.fontWeight, FontWeight.w500);
    expect(style.fontStyle, FontStyle.italic);
    expect(style.color, Palette.inkSoft);
  });

  test('codeBlock is monospace at fourteen with height 1.5', () {
    expect(NoteTypography.codeBlock.fontFamily, TypographyTokens.mono);
    expect(NoteTypography.codeBlock.fontSize, 14);
    expect(NoteTypography.codeBlock.fontWeight, FontWeight.w400);
    expect(NoteTypography.codeBlock.height, 1.5);
    expect(NoteTypography.codeBlock.color, Palette.ink);
  });

  test('inlineCode scales the base size by 0.875 with an ink08 background', () {
    final TextStyle style = NoteTypography.inlineCode(NoteTypography.heading(1));
    expect(style.fontFamily, TypographyTokens.mono);
    expect(style.fontSize, 21);
    expect(style.backgroundColor, Palette.ink08);
  });

  test('marker is drawn in Palette.ink34', () {
    expect(NoteTypography.marker.color, Palette.ink34);
  });

  test('checkedItem is Palette.muted with no strikethrough', () {
    expect(NoteTypography.checkedItem.color, Palette.muted);
    expect(NoteTypography.checkedItem.decoration, isNull);
  });

  test('caption equals the reader caption style', () {
    expect(NoteTypography.caption, TypographyTokens.captionSans);
  });

  test('inline formats equal the reader inline_span values', () {
    expect(NoteTypography.strong, const TextStyle(fontWeight: FontWeight.w700));
    expect(NoteTypography.emphasis, const TextStyle(fontStyle: FontStyle.italic));
    expect(
      NoteTypography.strikethrough,
      const TextStyle(decoration: TextDecoration.lineThrough),
    );
    expect(
      NoteTypography.link,
      const TextStyle(
        color: Palette.coralLink,
        decoration: TextDecoration.underline,
        decorationColor: Palette.coral30,
      ),
    );
  });

  test('withBoldText merges bold only when boldText is true', () {
    final TextStyle bold = NoteTypography.withBoldText(
      NoteTypography.body,
      boldText: true,
    );
    expect(bold.fontWeight, FontWeight.bold);

    final TextStyle unchanged = NoteTypography.withBoldText(
      NoteTypography.body,
      boldText: false,
    );
    expect(unchanged, NoteTypography.body);
  });

  test('emOf scales the sixteen point body em', () {
    expect(NoteTypography.emOf(TextScaler.linear(0.9)), closeTo(14.4, 1e-9));
    expect(NoteTypography.emOf(TextScaler.linear(1.15)), closeTo(18.4, 1e-9));
  });

  test('every layout number matches the reader values', () {
    expect(NoteTypography.blankLineEm, 1.6);
    expect(NoteTypography.listItemGapEm, 0.3);
    expect(NoteTypography.headingGapEm, 1.2);
    expect(NoteTypography.paragraphGapEm, 0.8);
    expect(NoteTypography.listMarkerEm, 1.6);
    expect(NoteTypography.minTextEm, 12);
    expect(NoteTypography.quoteRuleWidth, 2);
    expect(NoteTypography.quoteInsetEm, 0.9);
    expect(NoteTypography.codeScale, 0.875);
    expect(NoteTypography.codePaddingEm, 0.75);
    expect(NoteTypography.codeRadius, 6);
    expect(NoteTypography.dividerThickness, 1.5);
    expect(NoteTypography.dividerPadding, 4);
    expect(NoteTypography.dividerDashLength, 6);
    expect(NoteTypography.dividerDashGap, 4);
    expect(NoteTypography.tableGridLineWidth, 1);
    expect(NoteTypography.tableHeaderWeight, FontWeight.w600);
  });

  test('every paint colour matches the reader values', () {
    expect(NoteTypography.quoteRuleColor, Palette.dashMuted);
    expect(NoteTypography.codeBackground, Palette.ink08);
    expect(NoteTypography.dividerColor, Palette.dashMuted);
    expect(NoteTypography.tableGridColor, Palette.dashMuted);
    expect(NoteTypography.tableHeaderBackground, Palette.ink08);
  });
}
