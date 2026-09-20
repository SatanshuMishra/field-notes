import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/widgets.dart';
import '../../../domain/notes/notes.dart';
import 'note_inline_span.dart';

const double noteParagraphGapEm = 0.8;
const double noteListItemGapEm = 0.3;
const double noteHeadingGapEm = 1.2;
const double noteListMarkerEm = 1.6;
const double noteQuoteRuleWidth = 2;
const double noteQuoteInsetEm = 0.9;
const double noteCodePaddingEm = 0.75;
const double noteCodeScale = 0.875;
const double notePhotoStubWidthFraction = 0.75;
const double notePhotoStubAspectRatio = 3 / 2;

double noteBlockGapEm(NoteBlock previous, NoteBlock next) {
  if (_isListItem(previous) && _isListItem(next)) {
    return noteListItemGapEm;
  }
  if (next is HeadingBlock) {
    return noteHeadingGapEm;
  }
  return noteParagraphGapEm;
}

bool _isListItem(NoteBlock block) => block is BulletBlock || block is NumberBlock;

double noteEmOf(BuildContext context, TextStyle style) =>
    MediaQuery.textScalerOf(context)
        .scale(style.fontSize ?? TypographyTokens.noteBody.fontSize!);

TextStyle noteHeadingStyle(int level) => switch (level) {
      1 => TypographyTokens.titleSerif,
      2 => TypographyTokens.headlineSerif,
      _ => TypographyTokens.bannerSerif,
    };

TextStyle noteQuoteStyle(TextStyle base) =>
    base.copyWith(fontStyle: FontStyle.italic, color: Palette.inkSoft);

TextStyle noteCodeBlockStyle(TextStyle base) => base.copyWith(
      fontFamily: TypographyTokens.mono,
      fontSize:
          (base.fontSize ?? TypographyTokens.noteBody.fontSize!) * noteCodeScale,
      height: 1.5,
    );

class NoteBlockView extends StatelessWidget {
  const NoteBlockView({super.key, required this.block, required this.style});

  final NoteBlock block;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => switch (block) {
        final ParagraphBlock paragraph =>
          NoteParagraphView(block: paragraph, style: style),
        final HeadingBlock heading => NoteHeadingView(block: heading),
        final BulletBlock bullet =>
          NoteBulletView(block: bullet, style: style),
        final NumberBlock number =>
          NoteNumberView(block: number, style: style),
        final QuoteBlock quote => NoteQuoteView(block: quote, style: style),
        final CodeBlock code => NoteCodeView(block: code, style: style),
        final DividerBlock _ => const NoteDividerView(),
        final PhotoBlock photo => NotePhotoStub(block: photo),
      };
}

class NoteParagraphView extends StatelessWidget {
  const NoteParagraphView({super.key, required this.block, required this.style});

  final ParagraphBlock block;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      buildNoteInlineSpan(block.inlines, style),
      softWrap: true,
      overflow: TextOverflow.clip,
    );
  }
}

class NoteHeadingView extends StatelessWidget {
  const NoteHeadingView({super.key, required this.block});

  final HeadingBlock block;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      buildNoteInlineSpan(block.inlines, noteHeadingStyle(block.level)),
      softWrap: true,
      overflow: TextOverflow.clip,
    );
  }
}

class NoteBulletView extends StatelessWidget {
  const NoteBulletView({super.key, required this.block, required this.style});

  final BulletBlock block;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return NoteListItem(
      marker: '•',
      inlines: block.inlines,
      style: style,
    );
  }
}

class NoteNumberView extends StatelessWidget {
  const NoteNumberView({super.key, required this.block, required this.style});

  final NumberBlock block;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return NoteListItem(
      marker: '${block.ordinal}.',
      inlines: block.inlines,
      style: style,
    );
  }
}

class NoteListItem extends StatelessWidget {
  const NoteListItem({
    super.key,
    required this.marker,
    required this.inlines,
    required this.style,
  });

  final String marker;
  final List<InlineNode> inlines;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final double em = noteEmOf(context, style);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SelectionContainer.disabled(
          child: SizedBox(
            width: noteListMarkerEm * em,
            child: Text(marker, style: style, textAlign: TextAlign.left),
          ),
        ),
        Expanded(
          child: Text.rich(
            buildNoteInlineSpan(inlines, style),
            softWrap: true,
            overflow: TextOverflow.clip,
          ),
        ),
      ],
    );
  }
}

class NoteQuoteView extends StatelessWidget {
  const NoteQuoteView({super.key, required this.block, required this.style});

  final QuoteBlock block;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final double em = noteEmOf(context, style);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Palette.dashMuted, width: noteQuoteRuleWidth),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(left: noteQuoteInsetEm * em),
        child: Text.rich(
          buildNoteInlineSpan(block.inlines, noteQuoteStyle(style)),
          softWrap: true,
          overflow: TextOverflow.clip,
        ),
      ),
    );
  }
}

class NoteCodeView extends StatelessWidget {
  const NoteCodeView({super.key, required this.block, required this.style});

  final CodeBlock block;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final double em = noteEmOf(context, style);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Palette.ink08,
        borderRadius: BorderRadius.all(Radius.circular(Shapes.radiusXs)),
      ),
      child: Padding(
        padding: EdgeInsets.all(noteCodePaddingEm * em),
        child: Text(
          block.text,
          style: noteCodeBlockStyle(style),
          softWrap: true,
          overflow: TextOverflow.clip,
        ),
      ),
    );
  }
}

class NoteDividerView extends StatelessWidget {
  const NoteDividerView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: DashedDivider(color: Palette.dashMuted),
    );
  }
}

class NotePhotoStub extends StatelessWidget {
  const NotePhotoStub({super.key, required this.block});

  final PhotoBlock block;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const FractionallySizedBox(
          widthFactor: notePhotoStubWidthFraction,
          child: AspectRatio(
            aspectRatio: notePhotoStubAspectRatio,
            child: CrossHatchPlaceholder(),
          ),
        ),
        if (block.alt.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              block.alt,
              style: TypographyTokens.captionSans,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
