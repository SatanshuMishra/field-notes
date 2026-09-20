import 'package:flutter/painting.dart';

import '../../../design/tokens/tokens.dart';
import '../../../domain/notes/notes.dart';

const double noteInlineCodeScale = 0.875;

const TextStyle noteBoldStyle = TextStyle(fontWeight: FontWeight.w700);

const TextStyle noteItalicStyle = TextStyle(fontStyle: FontStyle.italic);

const TextStyle noteStrikeStyle = TextStyle(
  decoration: TextDecoration.lineThrough,
);

const TextStyle noteLinkStyle = TextStyle(
  color: Palette.coralLink,
  decoration: TextDecoration.underline,
  decorationColor: Palette.coral30,
);

TextStyle noteInlineCodeStyle(TextStyle base) => TextStyle(
      fontFamily: TypographyTokens.mono,
      fontSize: (base.fontSize ?? TypographyTokens.noteBody.fontSize!) *
          noteInlineCodeScale,
      backgroundColor: Palette.ink08,
    );

TextStyle noteStyleFor(InlineStyle style) => switch (style) {
      InlineStyle.bold => noteBoldStyle,
      InlineStyle.italic => noteItalicStyle,
      InlineStyle.strike => noteStrikeStyle,
    };

TextSpan buildNoteInlineSpan(List<InlineNode> nodes, TextStyle base) =>
    TextSpan(style: base, children: _spansOf(nodes, base));

List<InlineSpan> _spansOf(List<InlineNode> nodes, TextStyle base) =>
    <InlineSpan>[for (final InlineNode node in nodes) _spanOf(node, base)];

InlineSpan _spanOf(InlineNode node, TextStyle base) => switch (node) {
      PlainNode(:final String text) => TextSpan(text: text),
      CodeNode(:final String text) =>
        TextSpan(text: text, style: noteInlineCodeStyle(base)),
      StyledNode(:final InlineStyle style, :final List<InlineNode> children) =>
        TextSpan(style: noteStyleFor(style), children: _spansOf(children, base)),
      LinkNode(:final List<InlineNode> children) =>
        TextSpan(style: noteLinkStyle, children: _spansOf(children, base)),
    };
