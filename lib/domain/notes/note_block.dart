final class SourceRange {
  const SourceRange(this.start, this.end)
      : assert(start >= 0, 'start must not be negative'),
        assert(end >= start, 'end must not precede start');

  final int start;
  final int end;

  int get length => end - start;

  bool get isEmpty => start == end;

  String sliceOf(String source) => source.substring(start, end);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'SourceRange($start, $end)';
}

enum InlineStyle { bold, italic, strike }

sealed class InlineNode {
  const InlineNode({required this.sourceRange});

  final SourceRange sourceRange;

  String get plainText;
}

final class PlainNode extends InlineNode {
  const PlainNode({required this.text, required super.sourceRange});

  final String text;

  @override
  String get plainText => text;

  @override
  String toString() => 'PlainNode(${_quote(text)}, $sourceRange)';
}

final class CodeNode extends InlineNode {
  const CodeNode({
    required this.text,
    required super.sourceRange,
    required this.contentRange,
  });

  final String text;
  final SourceRange contentRange;

  @override
  String get plainText => text;

  @override
  String toString() => 'CodeNode(${_quote(text)}, $sourceRange)';
}

final class StyledNode extends InlineNode {
  const StyledNode({
    required this.style,
    required this.children,
    required super.sourceRange,
    required this.contentRange,
  });

  final InlineStyle style;
  final List<InlineNode> children;
  final SourceRange contentRange;

  @override
  String get plainText => plainTextOfNodes(children);

  @override
  String toString() => 'StyledNode(${style.name}, $children, $sourceRange)';
}

final class LinkNode extends InlineNode {
  const LinkNode({
    required this.children,
    required this.url,
    required super.sourceRange,
    required this.contentRange,
    required this.urlRange,
  });

  final List<InlineNode> children;
  final String url;
  final SourceRange contentRange;
  final SourceRange urlRange;

  @override
  String get plainText => plainTextOfNodes(children);

  @override
  String toString() => 'LinkNode($children, ${_quote(url)}, $sourceRange)';
}

String plainTextOfNodes(List<InlineNode> nodes) {
  final StringBuffer buffer = StringBuffer();
  for (final InlineNode node in nodes) {
    buffer.write(node.plainText);
  }
  return buffer.toString();
}

sealed class NoteBlock {
  const NoteBlock({required this.sourceRange, required this.markerRanges});

  final SourceRange sourceRange;
  final List<SourceRange> markerRanges;

  String get plainText;
}

sealed class InlineBlock extends NoteBlock {
  const InlineBlock({
    required this.inlines,
    required super.sourceRange,
    required super.markerRanges,
  });

  final List<InlineNode> inlines;

  @override
  String get plainText => plainTextOfNodes(inlines);
}

final class ParagraphBlock extends InlineBlock {
  const ParagraphBlock({
    required super.inlines,
    required super.sourceRange,
    super.markerRanges = const <SourceRange>[],
  });

  @override
  String toString() => 'ParagraphBlock($inlines, $sourceRange)';
}

final class HeadingBlock extends InlineBlock {
  const HeadingBlock({
    required this.level,
    required super.inlines,
    required super.sourceRange,
    required super.markerRanges,
  }) : assert(level >= 1 && level <= 3, 'headings run from 1 to 3');

  final int level;

  @override
  String toString() => 'HeadingBlock($level, $inlines, $sourceRange)';
}

final class BulletBlock extends InlineBlock {
  const BulletBlock({
    required super.inlines,
    required super.sourceRange,
    required super.markerRanges,
  });

  @override
  String toString() => 'BulletBlock($inlines, $sourceRange)';
}

final class NumberBlock extends InlineBlock {
  const NumberBlock({
    required this.ordinal,
    required super.inlines,
    required super.sourceRange,
    required super.markerRanges,
  });

  final int ordinal;

  @override
  String toString() => 'NumberBlock($ordinal, $inlines, $sourceRange)';
}

final class QuoteBlock extends InlineBlock {
  const QuoteBlock({
    required super.inlines,
    required super.sourceRange,
    required super.markerRanges,
  });

  @override
  String toString() => 'QuoteBlock($inlines, $sourceRange)';
}

final class CodeBlock extends NoteBlock {
  const CodeBlock({
    required this.text,
    required this.language,
    required this.contentRange,
    required super.sourceRange,
    required super.markerRanges,
  });

  final String text;
  final String language;
  final SourceRange contentRange;

  @override
  String get plainText => text;

  @override
  String toString() => 'CodeBlock(${_quote(language)}, ${_quote(text)}, '
      '$sourceRange)';
}

final class DividerBlock extends NoteBlock {
  const DividerBlock({required super.sourceRange, required super.markerRanges});

  @override
  String get plainText => '';

  @override
  String toString() => 'DividerBlock($sourceRange)';
}

final class PhotoBlock extends NoteBlock {
  const PhotoBlock({
    required this.alt,
    required this.reference,
    required this.attributes,
    required this.altRange,
    required this.referenceRange,
    required this.attributesRange,
    required super.sourceRange,
    required super.markerRanges,
  });

  final String alt;
  final String reference;
  final String attributes;
  final SourceRange altRange;
  final SourceRange referenceRange;
  final SourceRange? attributesRange;

  @override
  String get plainText => alt;

  @override
  String toString() => 'PhotoBlock(${_quote(alt)}, $reference, '
      '${_quote(attributes)}, $sourceRange)';
}

String _quote(String text) => "'${text.replaceAll('\n', r'\n')}'";
