import 'block_parser.dart';
import 'inline_parser.dart';
import 'source_lines.dart';
import 'syntax_tree.dart';

const Set<MdBlockKind> _inlineHosts = <MdBlockKind>{
  MdBlockKind.heading,
  MdBlockKind.paragraph,
  MdBlockKind.tableCell,
};

MdTree parseNoteTree(String source, {bool tables = true}) {
  final MdSourceLines lines = MdSourceLines.split(source);
  final List<MdBlock> blocks = MdBlockParser(tables: tables).parse(source);
  return MdTree(
    sourceLength: source.length,
    blocks: <MdBlock>[
      for (final MdBlock block in blocks) _assemble(source, lines, block, null),
    ],
  );
}

final class _Ancestry {
  const _Ancestry(this.block, this.parent, this.depth);

  final MdBlock block;
  final _Ancestry? parent;
  final int depth;

  List<MdBlock> toList() {
    final List<MdBlock?> outermostFirst = List<MdBlock?>.filled(depth, null);
    _Ancestry? link = this;
    while (link != null) {
      outermostFirst[link.depth - 1] = link.block;
      link = link.parent;
    }
    return List<MdBlock>.unmodifiable(outermostFirst.cast<MdBlock>());
  }
}

MdBlock _assemble(
  String source,
  MdSourceLines lines,
  MdBlock block,
  _Ancestry? ancestry,
) {
  final _Ancestry inner = _Ancestry(
    block,
    ancestry,
    ancestry == null ? 1 : ancestry.depth + 1,
  );
  return MdBlock(
    kind: block.kind,
    sourceRange: block.sourceRange,
    contentRange: block.contentRange,
    markerRanges: block.markerRanges,
    blocks: <MdBlock>[
      for (final MdBlock child in block.blocks)
        _assemble(source, lines, child, inner),
    ],
    inlines: _inlineHosts.contains(block.kind)
        ? const MdInlineParser().parse(
            source,
            MdBlockParser.inlineSegments(
              lines,
              block,
              ancestry?.toList() ?? const <MdBlock>[],
            ),
          )
        : const <MdInline>[],
    data: block.data,
  );
}
