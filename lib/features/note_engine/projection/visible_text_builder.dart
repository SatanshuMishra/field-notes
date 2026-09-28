import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';

const String _lineBreak = '\n';

final class ProjectedPiece {
  const ProjectedPiece({
    required this.sourceStart,
    required this.sourceEnd,
    required this.text,
    this.dimmed = false,
    this.atomic,
  });

  final int sourceStart;
  final int sourceEnd;
  final String text;
  final bool dimmed;
  final AtomicKind? atomic;

  bool get isHidden => text.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectedPiece &&
          sourceStart == other.sourceStart &&
          sourceEnd == other.sourceEnd &&
          text == other.text &&
          dimmed == other.dimmed &&
          atomic == other.atomic;

  @override
  int get hashCode => Object.hash(sourceStart, sourceEnd, text, dimmed, atomic);

  @override
  String toString() =>
      "ProjectedPiece([$sourceStart, $sourceEnd), '$text'"
      '${dimmed ? ', dimmed' : ''}'
      '${atomic == null ? '' : ', ${atomic!.name}'})';
}

final class ProjectedLine {
  const ProjectedLine({
    required this.index,
    required this.start,
    required this.end,
    required this.breakEnd,
    required this.pieces,
    this.removed = false,
  });

  final int index;
  final int start;
  final int end;
  final int breakEnd;
  final List<ProjectedPiece> pieces;
  final bool removed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectedLine &&
          index == other.index &&
          start == other.start &&
          end == other.end &&
          breakEnd == other.breakEnd &&
          removed == other.removed &&
          _listEquals(pieces, other.pieces);

  @override
  int get hashCode =>
      Object.hash(index, start, end, breakEnd, removed, Object.hashAll(pieces));

  @override
  String toString() =>
      'ProjectedLine($index: $start, $end, $breakEnd'
      '${removed ? ', removed' : ''}, $pieces)';
}

List<ProjectedPiece> splitByMarkers(
  String source,
  int start,
  int end,
  Iterable<MdRange> markers, {
  required bool active,
}) {
  final List<MdRange> clipped = <MdRange>[
    for (final MdRange marker in markers)
      if ((marker.start > start ? marker.start : start) <
          (marker.end < end ? marker.end : end))
        MdRange(
          marker.start > start ? marker.start : start,
          marker.end < end ? marker.end : end,
        ),
  ]..sort((MdRange a, MdRange b) => a.start.compareTo(b.start));
  final List<ProjectedPiece> pieces = <ProjectedPiece>[];
  int at = start;
  int index = 0;
  while (index < clipped.length) {
    final int markerStart = clipped[index].start;
    int markerEnd = clipped[index].end;
    index++;
    while (index < clipped.length && clipped[index].start < markerEnd) {
      if (clipped[index].end > markerEnd) {
        markerEnd = clipped[index].end;
      }
      index++;
    }
    if (markerStart > at) {
      pieces.add(
        ProjectedPiece(
          sourceStart: at,
          sourceEnd: markerStart,
          text: source.substring(at, markerStart),
        ),
      );
    }
    final int pieceStart = markerStart > at ? markerStart : at;
    if (markerEnd > pieceStart) {
      pieces.add(
        ProjectedPiece(
          sourceStart: pieceStart,
          sourceEnd: markerEnd,
          text: active ? source.substring(pieceStart, markerEnd) : '',
          dimmed: active,
        ),
      );
      at = markerEnd;
    }
  }
  if (end > at) {
    pieces.add(
      ProjectedPiece(
        sourceStart: at,
        sourceEnd: end,
        text: source.substring(at, end),
      ),
    );
  }
  return List<ProjectedPiece>.unmodifiable(pieces);
}

final class VisibleTextBuilder implements VisibleProjector {
  const VisibleTextBuilder();

  List<ProjectedLine> projectLines(
    String source,
    MdTree tree,
    int? activeLine,
  ) {
    if (tree.sourceLength != source.length) {
      throw ArgumentError.value(
        tree.sourceLength,
        'tree.sourceLength',
        'must equal source.length ${source.length}',
      );
    }
    final MdSourceLines split = MdSourceLines.split(source);
    final List<MdSourceLine> lines = split.lines;
    if (activeLine != null && (activeLine < 0 || activeLine >= lines.length)) {
      throw ArgumentError.value(
        activeLine,
        'activeLine',
        'must lie in [0, ${lines.length})',
      );
    }
    final _Collector collector = _Collector(split);
    for (final MdBlock block in tree.blocks) {
      collector.visitBlock(block, 0);
    }
    return List<ProjectedLine>.unmodifiable(<ProjectedLine>[
      for (final MdSourceLine line in lines)
        _projectLine(source, line, collector, line.index == activeLine),
    ]);
  }

  VisibleText assemble(
    String source,
    List<ProjectedLine> lines, {
    int? activeLine,
  }) {
    final int count = lines.length;
    final bool lastRemoved =
        count > 1 &&
        lines[count - 1].removed &&
        lines[count - 1].breakEnd == lines[count - 1].end;
    final StringBuffer text = StringBuffer();
    final List<VisibleLine> visibleLines = <VisibleLine>[];
    final List<AtomicObject> atomics = <AtomicObject>[];
    int offset = 0;
    for (int i = 0; i < count; i++) {
      final ProjectedLine line = lines[i];
      if (line.removed) {
        continue;
      }
      final bool keepsBreak =
          line.breakEnd > line.end && !(lastRemoved && i == count - 2);
      final int lineStart = offset;
      final List<VisibleSpan> spans = <VisibleSpan>[];
      for (final ProjectedPiece piece in line.pieces) {
        if (piece.isHidden) {
          continue;
        }
        final MdRange visibleRange = MdRange(
          offset,
          offset + piece.text.length,
        );
        final MdRange sourceRange = MdRange(piece.sourceStart, piece.sourceEnd);
        final AtomicKind? atomic = piece.atomic;
        if (atomic != null) {
          atomics.add(
            AtomicObject(
              kind: atomic,
              sourceRange: sourceRange,
              visibleOffset: offset,
              visibleLength: piece.text.length,
            ),
          );
        }
        spans.add(
          VisibleSpan(
            kind: atomic != null
                ? VisibleSpanKind.atomic
                : piece.dimmed
                ? VisibleSpanKind.marker
                : VisibleSpanKind.text,
            visibleRange: visibleRange,
            sourceRange: sourceRange,
          ),
        );
        text.write(piece.text);
        offset = visibleRange.end;
      }
      if (keepsBreak) {
        spans.add(
          VisibleSpan(
            kind: VisibleSpanKind.lineBreak,
            visibleRange: MdRange(offset, offset + 1),
            sourceRange: MdRange(line.end, line.breakEnd),
          ),
        );
        text.write(_lineBreak);
        offset++;
      }
      visibleLines.add(
        VisibleLine(
          sourceLine: line.index,
          sourceRange: MdRange(
            line.start,
            keepsBreak ? line.breakEnd : line.end,
          ),
          visibleRange: MdRange(lineStart, offset),
          spans: spans,
        ),
      );
    }
    return VisibleText(
      text: text.toString(),
      sourceLength: source.length,
      lines: visibleLines,
      atomics: atomics,
      activeLine: activeLine,
    );
  }

  @override
  VisibleText project(String source, MdTree tree, int? activeLine) => assemble(
    source,
    projectLines(source, tree, activeLine),
    activeLine: activeLine,
  );
}

ProjectedLine _projectLine(
  String source,
  MdSourceLine line,
  _Collector collector,
  bool active,
) {
  final List<MdRange> markers = collector.markers[line.index];
  if (!active && collector.fenceLines.contains(line.index)) {
    return ProjectedLine(
      index: line.index,
      start: line.start,
      end: line.end,
      breakEnd: line.breakEnd,
      pieces: List<ProjectedPiece>.unmodifiable(<ProjectedPiece>[
        if (line.end > line.start)
          ProjectedPiece(
            sourceStart: line.start,
            sourceEnd: line.end,
            text: '',
          ),
      ]),
      removed: true,
    );
  }
  final List<_Glyph> glyphs = active
      ? const <_Glyph>[]
      : collector.glyphs[line.index] ?? const <_Glyph>[];
  final List<ProjectedPiece> pieces = <ProjectedPiece>[];
  int at = line.start;
  for (final _Glyph glyph in glyphs) {
    final int glyphStart = glyph.range.start;
    final int glyphEnd = glyph.range.end < line.end
        ? glyph.range.end
        : line.end;
    if (glyphStart < at || glyphEnd <= glyphStart) {
      continue;
    }
    pieces.addAll(
      splitByMarkers(source, at, glyphStart, markers, active: active),
    );
    pieces.add(
      ProjectedPiece(
        sourceStart: glyphStart,
        sourceEnd: glyphEnd,
        text: glyph.text,
        atomic: AtomicKind.listMarker,
      ),
    );
    at = glyphEnd;
  }
  pieces.addAll(splitByMarkers(source, at, line.end, markers, active: active));
  return ProjectedLine(
    index: line.index,
    start: line.start,
    end: line.end,
    breakEnd: line.breakEnd,
    pieces: List<ProjectedPiece>.unmodifiable(pieces),
  );
}

final class _Glyph {
  const _Glyph(this.range, this.text);

  final MdRange range;
  final String text;
}

final class _Collector {
  _Collector(this.split)
    : markers = List<List<MdRange>>.generate(
        split.lines.length,
        (int _) => <MdRange>[],
      );

  final MdSourceLines split;
  final List<List<MdRange>> markers;
  final Map<int, List<_Glyph>> glyphs = <int, List<_Glyph>>{};
  final Set<int> fenceLines = <int>{};

  void visitBlock(MdBlock block, int listDepth) {
    _addMarkers(block.markerRanges);
    final MdBlockData? data = block.data;
    if (data is MdFenceData) {
      fenceLines.add(split.lineIndexAt(block.sourceRange.start));
      if (data.isClosed) {
        fenceLines.add(split.lineIndexAt(block.sourceRange.end));
      }
    }
    final bool isList =
        block.kind == MdBlockKind.bulletList ||
        block.kind == MdBlockKind.orderedList;
    final int childDepth = isList ? listDepth + 1 : listDepth;
    for (int i = 0; i < block.blocks.length; i++) {
      final MdBlock child = block.blocks[i];
      if (isList) {
        _addGlyph(block, child, i, childDepth);
      }
      visitBlock(child, childDepth);
    }
    for (final MdInline inline in block.inlines) {
      _visitInline(inline);
    }
  }

  void _visitInline(MdInline inline) {
    _addMarkers(inline.markerRanges);
    for (final MdInline child in inline.children) {
      _visitInline(child);
    }
  }

  void _addGlyph(MdBlock list, MdBlock item, int index, int depth) {
    if (item.markerRanges.isEmpty) {
      return;
    }
    final MdBlockData? listData = list.data;
    final MdBlockData? itemData = item.data;
    final bool isTask =
        itemData is MdListItemData && itemData.taskState != MdTaskState.none;
    final String text;
    if (listData is MdOrderedListData) {
      text = '${listData.start + index}. ';
    } else if (isTask) {
      return;
    } else {
      text = switch (depth) {
        1 => '\u2022 ',
        2 => '\u25E6 ',
        _ => '\u25AA ',
      };
    }
    final MdRange range = item.markerRanges.first;
    if (range.isEmpty) {
      return;
    }
    final int line = split.lineIndexAt(range.start);
    glyphs.update(
      line,
      (List<_Glyph> existing) => <_Glyph>[...existing, _Glyph(range, text)],
      ifAbsent: () => <_Glyph>[_Glyph(range, text)],
    );
  }

  void _addMarkers(List<MdRange> ranges) {
    final List<MdSourceLine> lines = split.lines;
    for (final MdRange range in ranges) {
      if (range.isEmpty) {
        continue;
      }
      for (
        int index = split.lineIndexAt(range.start);
        index < lines.length && lines[index].start < range.end;
        index++
      ) {
        final MdSourceLine line = lines[index];
        if ((range.start > line.start ? range.start : line.start) <
            (range.end < line.end ? range.end : line.end)) {
          markers[index].add(range);
        }
      }
    }
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
