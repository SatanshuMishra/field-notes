import 'source_lines.dart';
import 'syntax_tree.dart';

String plainTextOfTree(MdTree tree, String source) {
  if (tree.sourceLength != source.length) {
    throw ArgumentError.value(
      tree.sourceLength,
      'tree.sourceLength',
      'must equal the source length ${source.length}',
    );
  }
  final MdSourceLines lines = MdSourceLines.split(source);
  final _Collected collected = _Collected.of(tree, lines);
  final List<MdRange> markers = collected.markers;
  final int lineCount = lines.lines.length;
  final Set<int> removedBreaks = <int>{
    for (final int index in collected.silentLines)
      if (index < lineCount - 1) index else if (index > 0) index - 1,
  };
  final StringBuffer buffer = StringBuffer();
  for (final MdSourceLine line in lines.lines) {
    final int index = line.index;
    if (!collected.silentLines.contains(index)) {
      final List<MdRange>? cells = collected.rowCells[index];
      if (cells == null) {
        _writeVisible(buffer, source, line.start, line.end, markers);
      } else {
        for (int column = 0; column < cells.length; column++) {
          if (column > 0) {
            buffer.write('\t');
          }
          _writeVisible(
            buffer,
            source,
            cells[column].start,
            cells[column].end,
            markers,
          );
        }
      }
    }
    if (index < lineCount - 1 && !removedBreaks.contains(index)) {
      buffer.write('\n');
    }
  }
  return buffer.toString();
}

final class _Collected {
  const _Collected({
    required this.markers,
    required this.silentLines,
    required this.rowCells,
  });

  factory _Collected.of(MdTree tree, MdSourceLines lines) {
    final List<MdRange> markers = <MdRange>[];
    final Set<int> silentLines = <int>{};
    final Map<int, List<MdRange>> rowCells = <int, List<MdRange>>{};
    final List<MdNode> pending = <MdNode>[...tree.blocks];
    while (pending.isNotEmpty) {
      final MdNode node = pending.removeLast();
      markers.addAll(node.markerRanges);
      pending.addAll(node.children);
      if (node is MdBlock) {
        final MdBlockData? data = node.data;
        if (node.kind == MdBlockKind.fencedCode) {
          silentLines.add(lines.lineIndexAt(node.sourceRange.start));
          if (data is MdFenceData && data.isClosed) {
            silentLines.add(lines.lineIndexAt(node.sourceRange.end));
          }
        }
      }
    }
    for (final MdBlock block in tree.blocks) {
      if (block.kind == MdBlockKind.table) {
        if (block.markerRanges.isNotEmpty) {
          silentLines.add(lines.lineIndexAt(block.markerRanges.first.start));
        }
        for (final MdBlock row in block.blocks) {
          rowCells[lines.lineIndexAt(row.sourceRange.start)] = <MdRange>[
            for (final MdBlock cell in row.blocks) cell.contentRange,
          ];
        }
      }
    }
    return _Collected(
      markers: _merged(markers),
      silentLines: silentLines,
      rowCells: rowCells,
    );
  }

  final List<MdRange> markers;
  final Set<int> silentLines;
  final Map<int, List<MdRange>> rowCells;
}

List<MdRange> _merged(List<MdRange> ranges) {
  final List<MdRange> sorted = <MdRange>[
    for (final MdRange range in ranges)
      if (!range.isEmpty) range,
  ]..sort((MdRange a, MdRange b) => a.start.compareTo(b.start));
  final List<MdRange> merged = <MdRange>[];
  for (final MdRange range in sorted) {
    if (merged.isNotEmpty && range.start <= merged.last.end) {
      final MdRange last = merged.removeLast();
      merged.add(
        MdRange(last.start, range.end > last.end ? range.end : last.end),
      );
    } else {
      merged.add(range);
    }
  }
  return merged;
}

void _writeVisible(
  StringBuffer buffer,
  String source,
  int start,
  int end,
  List<MdRange> markers,
) {
  int low = 0;
  int high = markers.length;
  while (low < high) {
    final int mid = (low + high) >> 1;
    if (markers[mid].end <= start) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  int position = start;
  for (
    int index = low;
    index < markers.length && markers[index].start < end;
    index++
  ) {
    final MdRange marker = markers[index];
    if (marker.start > position) {
      buffer.write(source.substring(position, marker.start));
    }
    if (marker.end > position) {
      position = marker.end;
    }
  }
  if (position < end) {
    buffer.write(source.substring(position, end));
  }
}
