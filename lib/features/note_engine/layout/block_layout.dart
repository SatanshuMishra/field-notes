import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_typography.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/painting.dart';

const double noteColumnEm = 45;

const double _tolerance = 1e-9;
const int _lineFeed = 0x0A;
const int _carriageReturn = 0x0D;
const int _space = 0x20;
const int _tab = 0x09;

double noteColumnWidth({
  required double availableWidth,
  required TextScaler textScaler,
  bool fillsWidth = false,
}) {
  if (fillsWidth && availableWidth.isFinite) {
    return availableWidth;
  }
  final double cap = noteColumnEm * NoteTypography.emOf(textScaler);
  return availableWidth < cap ? availableWidth : cap;
}

enum LayoutRowKind { text, blankLine, code, divider, photo, table }

final class LayoutRow {
  const LayoutRow({
    required this.index,
    required this.blockIndex,
    required this.kind,
    required this.gapRole,
    required this.sourceRange,
    required this.visibleRange,
    required this.layoutContext,
    this.block,
    this.activeLineInRow,
    this.gapBefore = 0,
    this.continuedQuoteLevels = 0,
  });

  final int index;
  final int blockIndex;
  final LayoutRowKind kind;
  final GapRole gapRole;
  final MdBlock? block;
  final TextRange sourceRange;
  final TextRange visibleRange;
  final int? activeLineInRow;
  final double gapBefore;
  final int continuedQuoteLevels;
  final Object layoutContext;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayoutRow &&
          index == other.index &&
          blockIndex == other.blockIndex &&
          kind == other.kind &&
          gapRole == other.gapRole &&
          sourceRange == other.sourceRange &&
          visibleRange == other.visibleRange &&
          activeLineInRow == other.activeLineInRow &&
          gapBefore == other.gapBefore &&
          continuedQuoteLevels == other.continuedQuoteLevels &&
          layoutContext == other.layoutContext &&
          block == other.block;

  @override
  int get hashCode => Object.hash(
    index,
    blockIndex,
    kind,
    gapRole,
    block,
    sourceRange,
    visibleRange,
    activeLineInRow,
    gapBefore,
    continuedQuoteLevels,
    layoutContext,
  );

  @override
  String toString() =>
      'LayoutRow($index, ${kind.name}, block $blockIndex, '
      's[${sourceRange.start}, ${sourceRange.end}), '
      'v[${visibleRange.start}, ${visibleRange.end}), gap: $gapBefore'
      '${activeLineInRow == null ? '' : ', active: $activeLineInRow'})';
}

final class RowRegion {
  const RowRegion({
    required this.top,
    required this.left,
    required this.width,
    this.besideFloat = false,
  });

  final double top;
  final double left;
  final double width;
  final bool besideFloat;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RowRegion &&
          top == other.top &&
          left == other.left &&
          width == other.width &&
          besideFloat == other.besideFloat;

  @override
  int get hashCode => Object.hash(top, left, width, besideFloat);

  @override
  String toString() =>
      'RowRegion(top: $top, left: $left, width: $width'
      '${besideFloat ? ', besideFloat' : ''})';
}

typedef RowLayouter =
    LaidOutRow Function(
      LayoutInputs inputs,
      LayoutRow row,
      RowRegion region, {
      int? visibleFrom,
      int? visibleTo,
    });

double touchingGap(LayoutRow previous, LayoutRow next, double em) =>
    _gapBetween(previous.kind, previous.gapRole, next.kind, next.gapRole, em);

List<LayoutRow> layoutRowsOf(LayoutInputs inputs) {
  final MdTree tree = inputs.tree;
  final MdSourceLines split = MdSourceLines.split(inputs.source);
  final List<MdSourceLine> lines = split.lines;
  final double em = NoteTypography.emOf(inputs.textScaler);
  final _SeedCollector collector = _SeedCollector(split);
  for (int i = 0; i < tree.blocks.length; i++) {
    collector.visit(tree.blocks[i], i, const <MdBlock>[]);
  }
  final List<_Seed> seeds = collector.seeds();
  final List<VisibleLine> visibleLines = inputs.visibleText.lines;
  final List<LayoutRow> rows = <LayoutRow>[];
  List<MdBlock> previousChain = const <MdBlock>[];
  int seedIndex = 0;
  int visibleIndex = 0;
  int line = 0;
  while (line < lines.length) {
    final _Seed seed =
        seedIndex < seeds.length && seeds[seedIndex].firstLine == line
        ? seeds[seedIndex++]
        : _blankSeed(tree, lines[line]);
    final int lastLine = math.max(line, seed.lastLine);
    while (visibleIndex < visibleLines.length &&
        visibleLines[visibleIndex].sourceLine < line) {
      visibleIndex++;
    }
    final int firstVisible = visibleIndex;
    while (visibleIndex < visibleLines.length &&
        visibleLines[visibleIndex].sourceLine <= lastLine) {
      visibleIndex++;
    }
    final TextRange visibleRange = _visibleRangeOf(
      inputs.visibleText,
      visibleLines.sublist(firstVisible, visibleIndex),
      seed.sourceRange.start,
    );
    final int? activeLine = inputs.activeLine;
    final int? activeLineInRow =
        activeLine != null && activeLine >= line && activeLine <= lastLine
        ? activeLine - line
        : null;
    final List<_Frame> frames = _framesOf(seed.chain, em, inputs.columnWidth);
    final GapRole gapRole = seed.chain.any(_isListItem)
        ? GapRole.listItem
        : seed.block?.kind == MdBlockKind.heading
        ? GapRole.heading
        : GapRole.other;
    final LayoutRow? previous = rows.isEmpty ? null : rows.last;
    final double gapBefore = previous == null
        ? 0
        : _gapBetween(previous.kind, previous.gapRole, seed.kind, gapRole, em);
    final int continuedQuoteLevels = previous == null
        ? 0
        : _sharedQuoteLevels(_quotesOf(previousChain), _quotesOf(seed.chain));
    final int rowLineStart = lines[line].start;
    final int rowLineEnd = lines[lastLine].end;
    rows.add(
      LayoutRow(
        index: rows.length,
        blockIndex: seed.blockIndex,
        kind: seed.kind,
        gapRole: gapRole,
        block: seed.block,
        sourceRange: seed.sourceRange,
        visibleRange: visibleRange,
        activeLineInRow: activeLineInRow,
        gapBefore: gapBefore,
        continuedQuoteLevels: continuedQuoteLevels,
        layoutContext: _contextOf(
          tree: tree,
          seed: seed,
          frames: frames,
          em: em,
          gapBefore: gapBefore,
          continuedQuoteLevels: continuedQuoteLevels,
          activeLineInRow: activeLineInRow,
          rowLineStart: rowLineStart,
          rowLineEnd: rowLineEnd,
        ),
      ),
    );
    previousChain = seed.chain;
    line = lastLine + 1;
  }
  return List<LayoutRow>.unmodifiable(rows);
}

List<LaidOutRow> stackRows(LayoutInputs inputs, List<LayoutRow> rows) {
  for (final LayoutRow row in rows) {
    _requireTextRow(row);
  }
  final List<LaidOutRow> laidOut = <LaidOutRow>[];
  double bottom = 0;
  for (final LayoutRow row in rows) {
    final LaidOutRow result = layoutRow(
      inputs,
      row,
      RowRegion(
        top: laidOut.isEmpty ? 0 : bottom + row.gapBefore,
        left: 0,
        width: inputs.columnWidth,
      ),
    );
    laidOut.add(result);
    bottom = result.bottom;
  }
  return List<LaidOutRow>.unmodifiable(laidOut);
}

LaidOutRow layoutRow(
  LayoutInputs inputs,
  LayoutRow row,
  RowRegion region, {
  int? visibleFrom,
  int? visibleTo,
}) {
  _requireTextRow(row);
  final _RowScope scope = _RowScope(inputs, row, region);
  final (List<_Part>, int) split = scope.parts(visibleFrom, visibleTo);
  final List<_Part> parts =
      split.$1.isEmpty && visibleFrom == null && visibleTo == null
      ? <_Part>[scope.collapsedPart]
      : split.$1;
  final _Assembly assembly = switch (row.kind) {
    LayoutRowKind.code => scope.layoutCode(parts),
    LayoutRowKind.divider when row.activeLineInRow == null =>
      scope.layoutDivider(split.$1),
    LayoutRowKind.blankLine => scope.layoutText(
      parts,
      contentKind: FragmentKind.blankLine,
      contentBase: scope.markerBase,
      strutBase: NoteTypography.body,
    ),
    _ => scope.layoutText(
      parts,
      contentKind: FragmentKind.text,
      contentBase: scope.contentBase,
    ),
  };
  final bool includesHead = visibleFrom == null || visibleFrom <= split.$2;
  return LaidOutRow(
    row: row,
    fragments: assembly.fragments,
    decorations: <RowDecoration>[
      ...assembly.decorations,
      ...scope.quoteRules(assembly.bottom, extendUp: includesHead),
    ],
    top: region.top,
    bottom: assembly.bottom,
    contentWidth: region.width,
    styleRuns: _styleRunsOf(inputs, row),
  );
}

ui.Paragraph buildVisibleParagraph(
  LayoutInputs inputs,
  TextRange visibleRange, {
  required TextStyle base,
  required double width,
  TextAlign textAlign = TextAlign.start,
}) => _buildParagraph(
  inputs,
  visibleRange,
  base: base,
  width: width,
  textAlign: textAlign,
  strutBase: visibleRange.isCollapsed ? base : null,
);

ui.Paragraph _buildParagraph(
  LayoutInputs inputs,
  TextRange visibleRange, {
  required TextStyle base,
  required double width,
  TextAlign textAlign = TextAlign.start,
  TextStyle? strutBase,
}) {
  final TextStyle style = NoteTypography.withBoldText(
    base,
    boldText: inputs.boldText,
  ).copyWith(locale: inputs.locale);
  final TextStyle? strut = strutBase == null
      ? null
      : NoteTypography.withBoldText(strutBase, boldText: inputs.boldText);
  final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
    style.getParagraphStyle(
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      textScaler: inputs.textScaler,
      locale: inputs.locale,
      strutStyle: strut == null
          ? null
          : StrutStyle.fromTextStyle(strut, forceStrutHeight: true),
    ),
  );
  TextSpan(
    style: style,
    children: _styledSegments(inputs, visibleRange, style),
  ).build(builder, textScaler: inputs.textScaler);
  final ui.Paragraph paragraph = builder.build();
  paragraph.layout(ui.ParagraphConstraints(width: math.max(0, width)));
  return paragraph;
}

List<InlineSpan> _styledSegments(
  LayoutInputs inputs,
  TextRange range,
  TextStyle base,
) {
  if (range.isCollapsed) {
    return const <InlineSpan>[];
  }
  final VisibleText visible = inputs.visibleText;
  final List<_Layer> layers = _inlineLayers(inputs, range);
  final List<TextRange> dimmed = _dimmedRanges(visible, range);
  final List<int> cuts = <int>[
    range.start,
    range.end,
    for (final _Layer layer in layers) ...<int>[layer.start, layer.end],
    for (final TextRange marker in dimmed) ...<int>[marker.start, marker.end],
  ]..sort();
  final List<InlineSpan> spans = <InlineSpan>[];
  final List<_Layer> open = <_Layer>[];
  int nextLayer = 0;
  int nextDimmed = 0;
  int previous = range.start;
  for (final int cut in cuts) {
    if (cut <= previous) {
      continue;
    }
    while (open.isNotEmpty && open.last.end <= previous) {
      open.removeLast();
    }
    while (nextLayer < layers.length && layers[nextLayer].start <= previous) {
      final _Layer layer = layers[nextLayer++];
      if (layer.end > previous) {
        open.add(layer);
      }
    }
    while (nextDimmed < dimmed.length && dimmed[nextDimmed].end <= previous) {
      nextDimmed++;
    }
    TextStyle style = base;
    for (final _Layer layer in open) {
      style = _applyInline(style, layer.kind);
    }
    if (nextDimmed < dimmed.length && dimmed[nextDimmed].start <= previous) {
      style = style.merge(NoteTypography.marker);
    }
    spans.add(
      TextSpan(
        text: visible.text.substring(previous, cut).replaceAll('\r', ' '),
        style: style,
      ),
    );
    previous = cut;
  }
  return spans;
}

TextStyle _applyInline(TextStyle style, MdInlineKind kind) => switch (kind) {
  MdInlineKind.strong => style.merge(NoteTypography.strong),
  MdInlineKind.emphasis => style.merge(NoteTypography.emphasis),
  MdInlineKind.strikethrough => _withDecoration(
    style,
    NoteTypography.strikethrough,
  ),
  MdInlineKind.highlight => style.merge(NoteTypography.highlight),
  MdInlineKind.codeSpan => style.merge(NoteTypography.inlineCode(style)),
  MdInlineKind.link ||
  MdInlineKind.autolink => _withDecoration(style, NoteTypography.link),
  MdInlineKind.text ||
  MdInlineKind.softBreak ||
  MdInlineKind.hardBreak ||
  MdInlineKind.escape => style,
};

TextStyle _withDecoration(TextStyle style, TextStyle layer) {
  final TextDecoration? current = style.decoration;
  final TextDecoration? added = layer.decoration;
  final TextStyle merged = style.merge(layer);
  if (current == null || current == TextDecoration.none || added == null) {
    return merged;
  }
  return merged.copyWith(
    decoration: TextDecoration.combine(<TextDecoration>[current, added]),
  );
}

final class _Layer {
  const _Layer(this.start, this.end, this.kind);

  final int start;
  final int end;
  final MdInlineKind kind;
}

const Set<MdInlineKind> _styledInlines = <MdInlineKind>{
  MdInlineKind.strong,
  MdInlineKind.emphasis,
  MdInlineKind.strikethrough,
  MdInlineKind.highlight,
  MdInlineKind.codeSpan,
  MdInlineKind.link,
  MdInlineKind.autolink,
};

List<_Layer> _inlineLayers(LayoutInputs inputs, TextRange range) {
  final OffsetMap map = inputs.visibleText.map;
  final int sourceStart = map.visibleToSource(range.start).upstream;
  final int sourceEnd = map.visibleToSource(range.end).downstream;
  final List<MdBlock> hosts = <MdBlock>[];
  _collectHosts(inputs.tree.blocks, sourceStart, sourceEnd, hosts);
  final List<_Layer> layers = <_Layer>[];
  void visit(MdInline node) {
    if (node.sourceRange.end < sourceStart ||
        node.sourceRange.start > sourceEnd) {
      return;
    }
    if (_styledInlines.contains(node.kind)) {
      final int start = math.max(
        range.start,
        map.sourceToVisible(node.contentRange.start),
      );
      final int end = math.min(
        range.end,
        map.sourceToVisible(node.contentRange.end),
      );
      if (end > start) {
        layers.add(_Layer(start, end, node.kind));
      }
    }
    for (final MdInline child in node.children) {
      visit(child);
    }
  }

  for (final MdBlock host in hosts) {
    for (final MdInline inline in host.inlines) {
      visit(inline);
    }
  }
  return layers;
}

void _collectHosts(
  List<MdBlock> blocks,
  int sourceStart,
  int sourceEnd,
  List<MdBlock> hosts,
) {
  int low = 0;
  int high = blocks.length;
  while (low < high) {
    final int mid = (low + high) >> 1;
    if (blocks[mid].sourceRange.end < sourceStart) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  for (
    int i = low;
    i < blocks.length && blocks[i].sourceRange.start <= sourceEnd;
    i++
  ) {
    final MdBlock block = blocks[i];
    if (block.inlines.isNotEmpty) {
      hosts.add(block);
    }
    if (block.blocks.isNotEmpty) {
      _collectHosts(block.blocks, sourceStart, sourceEnd, hosts);
    }
  }
}

List<TextRange> _dimmedRanges(VisibleText visible, TextRange range) {
  final List<VisibleLine> lines = visible.lines;
  int low = 0;
  int high = lines.length;
  while (low < high) {
    final int mid = (low + high) >> 1;
    if (lines[mid].visibleRange.end <= range.start) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  final List<TextRange> dimmed = <TextRange>[];
  for (
    int i = low;
    i < lines.length && lines[i].visibleRange.start < range.end;
    i++
  ) {
    for (final VisibleSpan span in lines[i].spans) {
      if (!span.dimmed) {
        continue;
      }
      final int start = math.max(range.start, span.visibleRange.start);
      final int end = math.min(range.end, span.visibleRange.end);
      if (end > start) {
        dimmed.add(TextRange(start: start, end: end));
      }
    }
  }
  return dimmed;
}

List<({TextRange visibleRange, String styleKind})> _styleRunsOf(
  LayoutInputs inputs,
  LayoutRow row,
) {
  final MdTree tree = inputs.tree;
  final OffsetMap map = inputs.visibleText.map;
  final MdBlock? top = tree.blocks.isEmpty ? null : tree.blocks[row.blockIndex];
  final bool outside =
      row.kind == LayoutRowKind.blankLine &&
      (top == null || !_containsLine(top.sourceRange, row.sourceRange));
  final List<({TextRange visibleRange, String styleKind})> runs =
      <({TextRange visibleRange, String styleKind})>[
        (
          visibleRange: row.visibleRange,
          styleKind: outside || top == null ? 'blankLine' : top.kind.name,
        ),
      ];
  void visit(MdInline node) {
    runs.add((
      visibleRange: TextRange(
        start: map.sourceToVisible(node.sourceRange.start),
        end: map.sourceToVisible(node.sourceRange.end),
      ),
      styleKind: node.kind.name,
    ));
    for (final MdInline child in node.children) {
      visit(child);
    }
  }

  final MdBlock? block = row.block;
  if (block != null) {
    for (final MdInline inline in block.inlines) {
      visit(inline);
    }
  }
  return runs;
}

void _requireTextRow(LayoutRow row) {
  if (row.kind == LayoutRowKind.photo || row.kind == LayoutRowKind.table) {
    throw ArgumentError.value(
      row.kind,
      'row.kind',
      'only text, blank line, code and divider rows lay out here',
    );
  }
}

double _gapBetween(
  LayoutRowKind previousKind,
  GapRole previousRole,
  LayoutRowKind nextKind,
  GapRole nextRole,
  double em,
) =>
    previousKind == LayoutRowKind.blankLine ||
        nextKind == LayoutRowKind.blankLine
    ? 0
    : touchingBlockGapEm(previousRole, nextRole) * em;

TextRange _visibleRangeOf(
  VisibleText visible,
  List<VisibleLine> lines,
  int sourceStart,
) {
  if (lines.isEmpty) {
    return TextRange.collapsed(visible.map.sourceToVisible(sourceStart));
  }
  return TextRange(
    start: lines.first.visibleRange.start,
    end: _endWithoutBreak(lines.last),
  );
}

int _endWithoutBreak(VisibleLine line) =>
    line.spans.isNotEmpty && line.spans.last.kind == VisibleSpanKind.lineBreak
    ? line.spans.last.visibleRange.start
    : line.visibleRange.end;

bool _isListItem(MdBlock block) => block.kind == MdBlockKind.listItem;

bool _isContainer(MdBlock block) =>
    block.kind == MdBlockKind.blockQuote || block.kind == MdBlockKind.listItem;

bool _isList(MdBlock block) =>
    block.kind == MdBlockKind.bulletList ||
    block.kind == MdBlockKind.orderedList;

bool _containsLine(MdRange block, TextRange line) =>
    block.start <= line.start &&
    line.end <= block.end &&
    (line.start < block.end || line.end > line.start);

bool _containsRange(MdRange outer, MdRange inner) =>
    outer.start <= inner.start && inner.end <= outer.end;

bool _sameBlock(MdBlock a, MdBlock b) =>
    identical(a, b) || a.kind == b.kind && a.sourceRange == b.sourceRange;

List<MdBlock> _quotesOf(List<MdBlock> chain) => <MdBlock>[
  for (final MdBlock block in chain)
    if (block.kind == MdBlockKind.blockQuote) block,
];

int _sharedQuoteLevels(List<MdBlock> previous, List<MdBlock> next) {
  int shared = 0;
  while (shared < previous.length &&
      shared < next.length &&
      _sameBlock(previous[shared], next[shared])) {
    shared++;
  }
  return shared;
}

List<MdBlock> _chainOf(MdTree tree, LayoutRow row) {
  if (tree.blocks.isEmpty || row.blockIndex >= tree.blocks.length) {
    return const <MdBlock>[];
  }
  final MdBlock top = tree.blocks[row.blockIndex];
  final MdBlock? target = row.block;
  if (target == null) {
    return _chainTo(
      top,
      (MdBlock block) => _containsLine(block.sourceRange, row.sourceRange),
      row.sourceRange.start,
      null,
    );
  }
  return _chainTo(
    top,
    (MdBlock block) => _containsRange(block.sourceRange, target.sourceRange),
    target.sourceRange.start,
    target,
  );
}

List<MdBlock> _chainTo(
  MdBlock top,
  bool Function(MdBlock block) contains,
  int probe,
  MdBlock? target,
) {
  final List<MdBlock> chain = <MdBlock>[];
  MdBlock? node = contains(top) ? top : null;
  while (node != null) {
    final MdBlock current = node;
    if (target != null && _sameBlock(current, target)) {
      if (_isListItem(current)) {
        chain.add(current);
      }
      break;
    }
    if (!_isContainer(current) && !_isList(current)) {
      break;
    }
    if (_isContainer(current)) {
      chain.add(current);
    }
    node = _childContaining(current.blocks, contains, probe);
  }
  return List<MdBlock>.unmodifiable(chain);
}

MdBlock? _childContaining(
  List<MdBlock> blocks,
  bool Function(MdBlock block) contains,
  int probe,
) {
  int low = 0;
  int high = blocks.length - 1;
  int found = -1;
  while (low <= high) {
    final int mid = (low + high) >> 1;
    if (blocks[mid].sourceRange.start <= probe) {
      found = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  for (int i = found; i >= 0 && i >= found - 1; i--) {
    if (contains(blocks[i])) {
      return blocks[i];
    }
  }
  return null;
}

final class _Seed {
  const _Seed({
    required this.firstLine,
    required this.lastLine,
    required this.kind,
    required this.blockIndex,
    required this.sourceRange,
    required this.chain,
    this.block,
  });

  final int firstLine;
  final int lastLine;
  final LayoutRowKind kind;
  final int blockIndex;
  final TextRange sourceRange;
  final List<MdBlock> chain;
  final MdBlock? block;
}

_Seed _blankSeed(MdTree tree, MdSourceLine line) {
  final TextRange range = TextRange(start: line.start, end: line.end);
  final List<MdBlock> blocks = tree.blocks;
  int low = 0;
  int high = blocks.length - 1;
  int before = -1;
  while (low <= high) {
    final int mid = (low + high) >> 1;
    if (blocks[mid].sourceRange.start <= line.start) {
      before = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  final int blockIndex = before < 0 ? 0 : before;
  final bool inside =
      before >= 0 && _containsLine(blocks[before].sourceRange, range);
  return _Seed(
    firstLine: line.index,
    lastLine: line.index,
    kind: LayoutRowKind.blankLine,
    blockIndex: blockIndex,
    sourceRange: range,
    chain: inside
        ? _chainTo(
            blocks[before],
            (MdBlock block) => _containsLine(block.sourceRange, range),
            line.start,
            null,
          )
        : const <MdBlock>[],
  );
}

final class _SeedCollector {
  _SeedCollector(this.split)
    : covered = List<bool>.filled(split.lines.length, false);

  final MdSourceLines split;
  final List<bool> covered;
  final List<_Seed> _leaves = <_Seed>[];
  final Map<int, _Seed> _markers = <int, _Seed>{};

  void visit(MdBlock block, int blockIndex, List<MdBlock> chain) {
    switch (block.kind) {
      case MdBlockKind.paragraph:
      case MdBlockKind.heading:
        _leaf(block, blockIndex, chain, LayoutRowKind.text);
      case MdBlockKind.fencedCode:
        _leaf(block, blockIndex, chain, LayoutRowKind.code);
      case MdBlockKind.thematicBreak:
        _leaf(block, blockIndex, chain, LayoutRowKind.divider);
      case MdBlockKind.photoLine:
        _leaf(block, blockIndex, chain, LayoutRowKind.photo);
      case MdBlockKind.table:
        _leaf(block, blockIndex, chain, LayoutRowKind.table);
      case MdBlockKind.blockQuote:
        final List<MdBlock> inner = List<MdBlock>.unmodifiable(<MdBlock>[
          ...chain,
          block,
        ]);
        for (final MdBlock child in block.blocks) {
          visit(child, blockIndex, inner);
        }
      case MdBlockKind.bulletList:
      case MdBlockKind.orderedList:
        for (final MdBlock child in block.blocks) {
          visit(child, blockIndex, chain);
        }
      case MdBlockKind.listItem:
        final List<MdBlock> inner = List<MdBlock>.unmodifiable(<MdBlock>[
          ...chain,
          block,
        ]);
        final MdSourceLine line =
            split.lines[split.lineIndexAt(block.sourceRange.start)];
        _markers[line.index] = _Seed(
          firstLine: line.index,
          lastLine: line.index,
          kind: LayoutRowKind.text,
          blockIndex: blockIndex,
          sourceRange: TextRange(start: line.start, end: line.end),
          chain: inner,
          block: block,
        );
        for (final MdBlock child in block.blocks) {
          visit(child, blockIndex, inner);
        }
      case MdBlockKind.blankLine:
      case MdBlockKind.tableRow:
      case MdBlockKind.tableCell:
        break;
    }
  }

  void _leaf(
    MdBlock block,
    int blockIndex,
    List<MdBlock> chain,
    LayoutRowKind kind,
  ) {
    final int first = split.lineIndexAt(block.sourceRange.start);
    final int last = math.max(first, split.lineIndexAt(block.sourceRange.end));
    for (int line = first; line <= last; line++) {
      covered[line] = true;
    }
    _leaves.add(
      _Seed(
        firstLine: first,
        lastLine: last,
        kind: kind,
        blockIndex: blockIndex,
        sourceRange: TextRange(
          start: block.sourceRange.start,
          end: block.sourceRange.end,
        ),
        chain: chain,
        block: block,
      ),
    );
  }

  List<_Seed> seeds() {
    final List<_Seed> all = <_Seed>[
      ..._leaves,
      for (final _Seed marker in _markers.values)
        if (!covered[marker.firstLine]) marker,
    ]..sort((_Seed a, _Seed b) => a.firstLine.compareTo(b.firstLine));
    final List<_Seed> ordered = <_Seed>[];
    int next = 0;
    for (final _Seed seed in all) {
      if (seed.firstLine >= next) {
        ordered.add(seed);
        next = seed.lastLine + 1;
      }
    }
    return ordered;
  }
}

final class _Frame {
  const _Frame({
    required this.block,
    required this.ruleX,
    required this.markerX,
    required this.contentX,
    required this.listLeft,
    required this.listDepth,
  });

  final MdBlock block;
  final double ruleX;
  final double markerX;
  final double contentX;
  final double listLeft;
  final int listDepth;

  bool get isQuote => block.kind == MdBlockKind.blockQuote;

  MdRange? rangeOwning(int offset) {
    final List<MdRange> ranges = block.markerRanges;
    int low = 0;
    int high = ranges.length - 1;
    while (low <= high) {
      final int mid = (low + high) >> 1;
      final MdRange range = ranges[mid];
      if (offset < range.start) {
        high = mid - 1;
      } else if (offset >= range.end) {
        low = mid + 1;
      } else {
        return range;
      }
    }
    return null;
  }
}

List<_Frame> _framesOf(List<MdBlock> chain, double em, double columnWidth) {
  final List<_Frame> frames = <_Frame>[];
  final double markerWidth = NoteTypography.listMarkerEm * em;
  final double minText = NoteTypography.minTextEm * em;
  double x = 0;
  int depth = 0;
  for (final MdBlock block in chain) {
    if (block.kind == MdBlockKind.blockQuote) {
      final double edge =
          x + NoteTypography.quoteRuleWidth + NoteTypography.quoteInsetEm * em;
      frames.add(
        _Frame(
          block: block,
          ruleX: x,
          markerX: x,
          contentX: edge,
          listLeft: edge,
          listDepth: depth,
        ),
      );
      x = edge;
      continue;
    }
    depth++;
    final _Frame? parent = frames.isNotEmpty && !frames.last.isQuote
        ? frames.last
        : null;
    final double candidate = (parent?.contentX ?? x) + markerWidth;
    final bool indents =
        parent == null || columnWidth - candidate >= minText - _tolerance;
    final _Frame frame = _Frame(
      block: block,
      ruleX: x,
      markerX: parent == null
          ? x
          : indents
          ? parent.contentX
          : parent.markerX,
      contentX: indents ? candidate : parent.contentX,
      listLeft: parent?.listLeft ?? x,
      listDepth: depth,
    );
    frames.add(frame);
    x = frame.contentX;
  }
  return List<_Frame>.unmodifiable(frames);
}

Object _contextOf({
  required MdTree tree,
  required _Seed seed,
  required List<_Frame> frames,
  required double em,
  required double gapBefore,
  required int continuedQuoteLevels,
  required int? activeLineInRow,
  required int rowLineStart,
  required int rowLineEnd,
}) {
  final MdBlock? block = seed.block;
  final MdBlockData? data = block?.data;
  final _Frame? item = _innermostItem(frames);
  final MdBlockData? itemData = item?.block.data;
  final bool outside =
      seed.kind == LayoutRowKind.blankLine &&
      (tree.blocks.isEmpty ||
          !_containsLine(
            tree.blocks[seed.blockIndex].sourceRange,
            seed.sourceRange,
          ));
  final StringBuffer containers = StringBuffer()
    ..write(seed.sourceRange.start - rowLineStart)
    ..write(':')
    ..write(seed.sourceRange.end - rowLineStart);
  for (final _Frame frame in frames) {
    containers
      ..write(frame.isQuote ? '|q' : '|i')
      ..write(frame.block.sourceRange.start >= rowLineStart ? '*' : '')
      ..write('@${frame.markerX / em},${frame.contentX / em}');
    for (final MdRange range in frame.block.markerRanges) {
      if (range.end >= rowLineStart && range.start <= rowLineEnd) {
        containers.write(
          ',${range.start - rowLineStart}-${range.end - rowLineStart}',
        );
      }
    }
  }
  return (
    kind: seed.kind,
    leafKind: block?.kind,
    topLevelKind: outside || tree.blocks.isEmpty
        ? 'blankLine'
        : tree.blocks[seed.blockIndex].kind.name,
    headingLevel: data is MdHeadingData ? data.level : 0,
    listDepth: item?.listDepth ?? 0,
    markerColumnEm: item == null ? null : item.markerX / em,
    textLeftEm: (frames.isEmpty ? 0.0 : frames.last.contentX) / em,
    quoteDepth: frames.where((_Frame frame) => frame.isQuote).length,
    taskState: itemData is MdListItemData
        ? itemData.taskState
        : MdTaskState.none,
    gapBefore: gapBefore,
    continuedQuoteLevels: continuedQuoteLevels,
    activeLineInRow: activeLineInRow,
    containers: containers.toString(),
  );
}

_Frame? _innermostItem(List<_Frame> frames) {
  for (int i = frames.length - 1; i >= 0; i--) {
    if (!frames[i].isQuote) {
      return frames[i];
    }
  }
  return null;
}

enum _PieceKind { quote, indent, marker }

final class _Piece {
  const _Piece(this.kind, this.frame, this.range);

  final _PieceKind kind;
  final _Frame frame;
  final TextRange range;

  _Piece extendedTo(int end, _Frame owner) =>
      _Piece(kind, owner, TextRange(start: range.start, end: end));
}

final class _Part {
  const _Part({
    required this.prefix,
    required this.content,
    required this.contentStart,
    required this.keepsPrefix,
  });

  final List<_Piece> prefix;
  final TextRange content;
  final int contentStart;
  final bool keepsPrefix;
}

final class _Assembly {
  const _Assembly({
    required this.fragments,
    required this.decorations,
    required this.bottom,
  });

  final List<LineFragment> fragments;
  final List<RowDecoration> decorations;
  final double bottom;
}

final class _Measured {
  const _Measured({
    required this.paragraph,
    required this.topOffset,
    required this.extent,
    required this.firstBaseline,
  });

  final ui.Paragraph paragraph;
  final double topOffset;
  final double extent;
  final double firstBaseline;
}

final class _Placed {
  const _Placed(this.range, this.x, this.measured);

  final TextRange range;
  final double x;
  final _Measured measured;
}

final class _RowScope {
  _RowScope._({
    required this.inputs,
    required this.row,
    required this.region,
    required this.em,
    required this.frames,
    required this.visibleLines,
  });

  factory _RowScope(LayoutInputs inputs, LayoutRow row, RowRegion region) {
    final double em = NoteTypography.emOf(inputs.textScaler);
    final String source = inputs.source;
    return _RowScope._(
      inputs: inputs,
      row: row,
      region: region,
      em: em,
      frames: _framesOf(_chainOf(inputs.tree, row), em, inputs.columnWidth),
      visibleLines: _visibleLinesBetween(
        inputs.visibleText.lines,
        _lineStartAt(source, row.sourceRange.start),
        _lineEndAt(source, row.sourceRange.end),
      ),
    );
  }

  final LayoutInputs inputs;
  final LayoutRow row;
  final RowRegion region;
  final double em;
  final List<_Frame> frames;
  final List<VisibleLine> visibleLines;

  double get textLeft => frames.isEmpty ? 0 : frames.last.contentX;

  bool get inQuote => frames.any((_Frame frame) => frame.isQuote);

  TextStyle get markerBase => inQuote
      ? NoteTypography.quoteOf(NoteTypography.body)
      : NoteTypography.body;

  TextStyle get contentBase {
    if (row.kind == LayoutRowKind.divider) {
      return markerBase;
    }
    final MdBlockData? data = row.block?.data;
    final TextStyle style = data is MdHeadingData
        ? NoteTypography.heading(data.level)
        : NoteTypography.body;
    final TextStyle quoted = inQuote ? NoteTypography.quoteOf(style) : style;
    final _Frame? item = _innermostItem(frames);
    final MdBlockData? itemData = item?.block.data;
    return itemData is MdListItemData &&
            itemData.taskState == MdTaskState.checked
        ? quoted.merge(NoteTypography.checkedItem)
        : quoted;
  }

  _Part get collapsedPart => _Part(
    prefix: const <_Piece>[],
    content: TextRange.collapsed(row.visibleRange.start),
    contentStart: row.visibleRange.start,
    keepsPrefix: true,
  );

  (List<_Part>, int) parts(int? visibleFrom, int? visibleTo) {
    final int? activeLine = row.activeLineInRow == null
        ? null
        : inputs.activeLine;
    final List<List<VisibleLine>> groups = <List<VisibleLine>>[];
    if (activeLine == null) {
      if (visibleLines.isNotEmpty) {
        groups.add(visibleLines);
      }
    } else {
      final List<VisibleLine> before = <VisibleLine>[
        for (final VisibleLine line in visibleLines)
          if (line.sourceLine < activeLine) line,
      ];
      final List<VisibleLine> active = <VisibleLine>[
        for (final VisibleLine line in visibleLines)
          if (line.sourceLine == activeLine) line,
      ];
      final List<VisibleLine> after = <VisibleLine>[
        for (final VisibleLine line in visibleLines)
          if (line.sourceLine > activeLine) line,
      ];
      for (final List<VisibleLine> group in <List<VisibleLine>>[
        before,
        active,
        after,
      ]) {
        if (group.isNotEmpty) {
          groups.add(group);
        }
      }
    }
    final List<_Part> parts = <_Part>[];
    int rowContentStart = row.visibleRange.start;
    for (int i = 0; i < groups.length; i++) {
      final List<VisibleLine> group = groups[i];
      final (List<_Piece>, int) prefix = _prefixOf(group.first);
      final int contentStart = prefix.$2;
      final int contentEnd = math.max(
        contentStart,
        _endWithoutBreak(group.last),
      );
      if (i == 0) {
        rowContentStart = contentStart;
      }
      final bool keepsPrefix =
          visibleFrom == null || visibleFrom <= contentStart;
      final int start = visibleFrom == null
          ? contentStart
          : math.max(contentStart, visibleFrom);
      final int end = visibleTo == null
          ? contentEnd
          : math.min(contentEnd, visibleTo);
      final bool empty = contentStart == contentEnd;
      final bool inside = empty
          ? (visibleFrom == null || visibleFrom <= contentStart) &&
                (visibleTo == null || visibleTo >= contentStart)
          : end > start;
      if (!inside) {
        continue;
      }
      parts.add(
        _Part(
          prefix: keepsPrefix ? prefix.$1 : const <_Piece>[],
          content: TextRange(start: start, end: math.max(start, end)),
          contentStart: contentStart,
          keepsPrefix: keepsPrefix,
        ),
      );
    }
    return (List<_Part>.unmodifiable(parts), rowContentStart);
  }

  (List<_Piece>, int) _prefixOf(VisibleLine line) {
    final VisibleText visible = inputs.visibleText;
    final int sourceLineStart = line.sourceRange.start;
    final List<_Piece> pieces = <_Piece>[];
    int contentStart = line.visibleRange.start;
    for (final VisibleSpan span in line.spans) {
      final TextRange range = TextRange(
        start: span.visibleRange.start,
        end: span.visibleRange.end,
      );
      if (span.kind == VisibleSpanKind.atomic) {
        final AtomicObject? atomic = visible.atomicAtVisible(range.start);
        final _Frame? owner = _ownerOf(span.sourceRange.start)?.$1;
        if (atomic == null ||
            owner == null ||
            owner.isQuote ||
            (atomic.kind != AtomicKind.listMarker &&
                atomic.kind != AtomicKind.checkbox)) {
          break;
        }
        _append(pieces, _Piece(_PieceKind.marker, owner, range));
      } else if (span.kind == VisibleSpanKind.marker) {
        final (_Frame, MdRange)? owner = _ownerOf(span.sourceRange.start);
        if (owner == null) {
          break;
        }
        final _Frame frame = owner.$1;
        if (frame.isQuote) {
          pieces.add(_Piece(_PieceKind.quote, frame, range));
        } else if (owner.$2 == frame.block.markerRanges.first &&
            frame.block.sourceRange.start >= sourceLineStart) {
          final int split = range.start + _leadingBlanks(visible.text, range);
          if (split > range.start) {
            _append(
              pieces,
              _Piece(
                _PieceKind.indent,
                frame,
                TextRange(start: range.start, end: split),
              ),
            );
          }
          if (split < range.end) {
            _append(
              pieces,
              _Piece(
                _PieceKind.marker,
                frame,
                TextRange(start: split, end: range.end),
              ),
            );
          }
        } else {
          _append(pieces, _Piece(_PieceKind.indent, frame, range));
        }
      } else {
        break;
      }
      contentStart = range.end;
    }
    return (List<_Piece>.unmodifiable(pieces), contentStart);
  }

  void _append(List<_Piece> pieces, _Piece piece) {
    if (pieces.isNotEmpty) {
      final _Piece last = pieces.last;
      final bool joins =
          last.range.end == piece.range.start &&
          last.kind == piece.kind &&
          (piece.kind == _PieceKind.indent ||
              identical(last.frame, piece.frame));
      if (joins) {
        pieces[pieces.length - 1] = last.extendedTo(
          piece.range.end,
          piece.frame,
        );
        return;
      }
    }
    pieces.add(piece);
  }

  (_Frame, MdRange)? _ownerOf(int sourceOffset) {
    for (int i = frames.length - 1; i >= 0; i--) {
      final MdRange? range = frames[i].rangeOwning(sourceOffset);
      if (range != null) {
        return (frames[i], range);
      }
    }
    return null;
  }

  (List<_Placed>, double) _placePrefix(List<_Piece> prefix) {
    final List<_Placed> placed = <_Placed>[];
    double pen = 0;
    _Piece? indent;
    void flushIndent(double end, double listLeft) {
      final _Piece? pending = indent;
      if (pending == null) {
        return;
      }
      final _Measured measured = _measureMarker(pending.range);
      final double width = measured.paragraph.maxIntrinsicWidth;
      final double start = math.max(pen, math.max(listLeft, end - width));
      placed.add(_Placed(pending.range, start, measured));
      pen = start + width;
      indent = null;
    }

    for (final _Piece piece in prefix) {
      switch (piece.kind) {
        case _PieceKind.indent:
          indent = piece;
        case _PieceKind.quote:
          flushIndent(piece.frame.ruleX, piece.frame.ruleX);
          final _Measured measured = _measureMarker(piece.range);
          final double start = math.max(
            pen,
            piece.frame.ruleX + NoteTypography.quoteRuleWidth,
          );
          placed.add(_Placed(piece.range, start, measured));
          pen = math.max(
            piece.frame.contentX,
            start + measured.paragraph.maxIntrinsicWidth,
          );
        case _PieceKind.marker:
          flushIndent(piece.frame.markerX, piece.frame.listLeft);
          final _Measured measured = _measureMarker(piece.range);
          final double start = math.max(pen, piece.frame.markerX);
          placed.add(_Placed(piece.range, start, measured));
          pen = math.max(
            piece.frame.contentX,
            start + measured.paragraph.maxIntrinsicWidth,
          );
      }
    }
    final _Piece? trailing = indent;
    if (trailing != null) {
      final _Frame owner = trailing.frame;
      flushIndent(owner.contentX, owner.listLeft);
      pen = math.max(pen, owner.contentX);
    }
    return (placed, pen);
  }

  _Measured _measureMarker(TextRange range) {
    final ui.Paragraph paragraph = _buildParagraph(
      inputs,
      range,
      base: markerBase,
      width: double.infinity,
    );
    paragraph.layout(
      ui.ParagraphConstraints(width: paragraph.maxIntrinsicWidth),
    );
    return _measure(paragraph, markerBase);
  }

  _Measured _measure(ui.Paragraph paragraph, TextStyle strutBase) {
    final List<ui.LineMetrics> metrics = paragraph.computeLineMetrics();
    if (metrics.isEmpty) {
      final double? fontSize = strutBase.fontSize;
      final double? height = strutBase.height;
      return _Measured(
        paragraph: paragraph,
        topOffset: 0,
        extent: fontSize == null || height == null
            ? paragraph.height
            : inputs.textScaler.scale(fontSize) * height,
        firstBaseline: paragraph.alphabeticBaseline,
      );
    }
    final ui.LineMetrics first = metrics.first;
    final ui.LineMetrics last = metrics.last;
    final double top = first.baseline - first.ascent;
    return _Measured(
      paragraph: paragraph,
      topOffset: top,
      extent: last.baseline + last.descent - top,
      firstBaseline: first.baseline,
    );
  }

  _Assembly layoutText(
    List<_Part> parts, {
    required FragmentKind contentKind,
    required TextStyle contentBase,
    TextStyle? strutBase,
  }) {
    final List<LineFragment> fragments = <LineFragment>[];
    double y = region.top;
    for (final _Part part in parts) {
      final (List<_Placed>, double) prefix = _placePrefix(part.prefix);
      final double x = math.max(prefix.$2, textLeft);
      final TextStyle strut = strutBase ?? contentBase;
      final ui.Paragraph paragraph = _buildParagraph(
        inputs,
        part.content,
        base: contentBase,
        width: region.width - x,
        strutBase: strutBase ?? (part.content.isCollapsed ? contentBase : null),
      );
      final _Measured content = _measure(paragraph, strut);
      y = _stackPart(
        fragments,
        top: y,
        prefix: prefix.$1,
        content: content,
        contentKind: contentKind,
        contentRange: part.content,
        contentX: x,
        contentWidth: region.width - x,
      );
    }
    return _Assembly(
      fragments: fragments,
      decorations: const <RowDecoration>[],
      bottom: y,
    );
  }

  _Assembly layoutCode(List<_Part> parts) {
    final double padding = NoteTypography.codePaddingEm * em;
    final TextStyle base = NoteTypography.codeBlock;
    final List<LineFragment> fragments = <LineFragment>[];
    double y = region.top + padding;
    if (parts.isEmpty) {
      final double? fontSize = base.fontSize;
      final double? height = base.height;
      y +=
          inputs.textScaler.scale(fontSize ?? NoteTypography.bodyFontSize) *
          (height ?? 1);
    }
    for (final _Part part in parts) {
      final (List<_Placed>, double) prefix = _placePrefix(part.prefix);
      final double x = math.max(prefix.$2, textLeft) + padding;
      final double width = region.width - x - padding;
      final ui.Paragraph paragraph = _buildParagraph(
        inputs,
        part.content,
        base: base,
        width: width,
        strutBase: part.content.isCollapsed ? base : null,
      );
      y = _stackPart(
        fragments,
        top: y,
        prefix: prefix.$1,
        content: _measure(paragraph, base),
        contentKind: FragmentKind.text,
        contentRange: part.content,
        contentX: x,
        contentWidth: width,
      );
    }
    final double bottom = y + padding;
    final double left = region.left + textLeft;
    return _Assembly(
      fragments: fragments,
      decorations: <RowDecoration>[
        RowDecoration(
          kind: RowDecorationKind.codeBackground,
          rect: Rect.fromLTRB(
            left,
            region.top,
            math.max(left, region.left + region.width),
            bottom,
          ),
        ),
      ],
      bottom: bottom,
    );
  }

  _Assembly layoutDivider(List<_Part> parts) {
    final List<LineFragment> fragments = <LineFragment>[];
    final List<RowDecoration> decorations = <RowDecoration>[];
    const double height =
        NoteTypography.dividerPadding * 2 + NoteTypography.dividerThickness;
    double bottom = region.top;
    for (final _Part part in parts) {
      final (List<_Placed>, double) prefix = _placePrefix(part.prefix);
      final double x = math.max(prefix.$2, textLeft);
      for (final _Placed marker in prefix.$1) {
        final LineFragment fragment = _fragment(
          FragmentKind.marker,
          marker.range,
          Offset(region.left + marker.x, bottom),
          marker.measured,
          marker.measured.paragraph.maxIntrinsicWidth,
        );
        fragments.add(fragment);
      }
      final double left = region.left + x;
      final double width = math.max(0, region.width - x);
      fragments.add(
        LineFragment(
          rowIndex: row.index,
          kind: FragmentKind.divider,
          visibleRange: part.content,
          origin: Offset(left, bottom),
          layoutWidth: width,
          height: height,
          besideFloat: region.besideFloat,
        ),
      );
      decorations.add(
        RowDecoration(
          kind: RowDecorationKind.dividerRule,
          rect: Rect.fromLTWH(
            left,
            bottom + NoteTypography.dividerPadding,
            width,
            NoteTypography.dividerThickness,
          ),
        ),
      );
      double partBottom = bottom + height;
      for (final LineFragment fragment in fragments) {
        partBottom = math.max(partBottom, fragment.lines.last.box.bottom);
      }
      bottom = partBottom;
    }
    return _Assembly(
      fragments: fragments,
      decorations: decorations,
      bottom: bottom,
    );
  }

  double _stackPart(
    List<LineFragment> fragments, {
    required double top,
    required List<_Placed> prefix,
    required _Measured content,
    required FragmentKind contentKind,
    required TextRange contentRange,
    required double contentX,
    required double contentWidth,
  }) {
    final double baseline = top - content.topOffset + content.firstBaseline;
    double shift = 0;
    for (final _Placed marker in prefix) {
      final double markerTop =
          baseline - marker.measured.firstBaseline + marker.measured.topOffset;
      shift = math.max(shift, top - markerTop);
    }
    double bottom = top + shift + content.extent;
    for (final _Placed marker in prefix) {
      final double originY = baseline + shift - marker.measured.firstBaseline;
      fragments.add(
        _fragment(
          FragmentKind.marker,
          marker.range,
          Offset(region.left + marker.x, originY),
          marker.measured,
          marker.measured.paragraph.maxIntrinsicWidth,
        ),
      );
      bottom = math.max(
        bottom,
        originY + marker.measured.topOffset + marker.measured.extent,
      );
    }
    fragments.add(
      _fragment(
        contentKind,
        contentRange,
        Offset(region.left + contentX, top + shift - content.topOffset),
        content,
        math.max(0, contentWidth),
      ),
    );
    return bottom;
  }

  LineFragment _fragment(
    FragmentKind kind,
    TextRange range,
    Offset origin,
    _Measured measured,
    double width,
  ) => LineFragment(
    rowIndex: row.index,
    kind: kind,
    visibleRange: range,
    origin: origin,
    layoutWidth: width,
    height: measured.extent,
    paragraph: measured.paragraph,
    besideFloat: region.besideFloat,
  );

  List<RowDecoration> quoteRules(double bottom, {required bool extendUp}) {
    final List<RowDecoration> rules = <RowDecoration>[];
    int level = 0;
    for (final _Frame frame in frames) {
      if (!frame.isQuote) {
        continue;
      }
      final double extension = extendUp && level < row.continuedQuoteLevels
          ? row.gapBefore
          : 0;
      rules.add(
        RowDecoration(
          kind: RowDecorationKind.quoteRule,
          rect: Rect.fromLTRB(
            region.left + frame.ruleX,
            region.top - extension,
            region.left + frame.ruleX + NoteTypography.quoteRuleWidth,
            bottom,
          ),
        ),
      );
      level++;
    }
    return rules;
  }
}

int _leadingBlanks(String text, TextRange range) {
  int count = 0;
  while (range.start + count < range.end) {
    final int unit = text.codeUnitAt(range.start + count);
    if (unit != _space && unit != _tab) {
      break;
    }
    count++;
  }
  return count;
}

int _lineStartAt(String source, int offset) {
  int at = math.min(offset, source.length);
  while (at > 0 && source.codeUnitAt(at - 1) != _lineFeed) {
    at--;
  }
  return at;
}

int _lineEndAt(String source, int offset) {
  int at = math.min(offset, source.length);
  while (at < source.length && source.codeUnitAt(at) != _lineFeed) {
    at++;
  }
  return at > offset &&
          at < source.length &&
          source.codeUnitAt(at - 1) == _carriageReturn
      ? at - 1
      : at;
}

List<VisibleLine> _visibleLinesBetween(
  List<VisibleLine> lines,
  int sourceStart,
  int sourceEnd,
) {
  int low = 0;
  int high = lines.length;
  while (low < high) {
    final int mid = (low + high) >> 1;
    if (lines[mid].sourceRange.start < sourceStart) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  final List<VisibleLine> found = <VisibleLine>[];
  for (
    int i = low;
    i < lines.length && lines[i].sourceRange.start <= sourceEnd;
    i++
  ) {
    found.add(lines[i]);
  }
  return List<VisibleLine>.unmodifiable(found);
}
