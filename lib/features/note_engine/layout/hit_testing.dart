import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/caret_geometry.dart';
import 'package:field_notes/features/note_engine/layout/float_flow.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_typography.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/painting.dart';

const int _lineFeed = 0x0A;
const int _carriageReturn = 0x0D;
const double _nearestSearchStart = 32;

final class NoteHitTester {
  const NoteHitTester({required this.flow});

  final NoteFlow flow;

  CaretGeometry get _geometry => CaretGeometry(flow: flow);

  VisibleText get _visible => flow.inputs.visibleText;

  TextPosition positionInLine(VisualLine line, double x) {
    final LocatedLine? owner = _ownerOf(line);
    if (owner == null) {
      return _geometryFallback(line);
    }
    final double y = line.top + line.height / 2;
    return _resolve(visualLineAt(owner, y), x);
  }

  TextPosition positionAt(Offset point) {
    for (final PlacedPhoto photo in flow.photos) {
      if (photo.figureRect.contains(point)) {
        return TextPosition(offset: photo.sourceRange.start);
      }
    }
    final LocatedLine? line = _lineAtHeight(point.dy);
    if (line == null) {
      return const TextPosition(offset: 0);
    }
    final VisualLine chosen = line.line;
    final double y =
        point.dy >= chosen.top && point.dy < chosen.top + chosen.height
        ? point.dy
        : chosen.top + chosen.height / 2;
    return _resolve(visualLineAt(line, y), point.dx);
  }

  List<LocatedLine> visualLineAt(LocatedLine member, double y) {
    final LaidOutRow row = flow.rows[member.fragment.rowIndex];
    final List<LocatedLine> group = <LocatedLine>[
      for (final LineFragment fragment in row.fragments)
        if (fragment.kind != FragmentKind.photo)
          for (final VisualLine line in _linesAtHeight(fragment, y))
            (fragment: fragment, line: line),
    ];
    return group.isEmpty
        ? <LocatedLine>[member]
        : List<LocatedLine>.unmodifiable(group);
  }

  TextRange wordBoundary(int position) {
    final OffsetMap map = _visible.map;
    final int visible = map.sourceToVisible(position);
    final LocatedLine located = _geometry.locateVisible(
      visible,
      TextAffinity.downstream,
    );
    final LineFragment fragment = located.fragment;
    final TextRange scope = fragment.kind == FragmentKind.tableCell
        ? fragment.visibleRange
        : flow.rows[fragment.rowIndex].row.visibleRange;
    if (scope.isCollapsed ||
        visible < scope.start ||
        visible > scope.end ||
        fragment.kind == FragmentKind.photo) {
      return TextRange.collapsed(position);
    }
    final ui.Paragraph paragraph = buildVisibleParagraph(
      flow.inputs,
      scope,
      base: NoteTypography.body,
      width: flow.inputs.columnWidth,
    );
    final TextRange local = paragraph.getWordBoundary(
      TextPosition(offset: visible - scope.start),
    );
    final int start = (scope.start + local.start).clamp(scope.start, scope.end);
    final int end = (scope.start + local.end).clamp(start, scope.end);
    return TextRange(
      start: map.visibleToSource(start).downstream,
      end: math.max(
        map.visibleToSource(start).downstream,
        map.visibleToSource(end).upstream,
      ),
    );
  }

  TextRange lineBoundary(int position, TextAffinity affinity) {
    final LocatedLine located = _geometry.locate(position, affinity);
    final double y = located.line.top + located.line.height / 2;
    final List<LocatedLine> group = visualLineAt(located, y);
    int start = located.line.visibleRange.start;
    int end = located.line.visibleRange.end;
    final bool fromMarker = located.fragment.kind == FragmentKind.marker;
    for (final LocatedLine member in group) {
      final FragmentKind kind = member.fragment.kind;
      final TextRange range = member.line.visibleRange;
      if (kind == FragmentKind.marker && range.end <= start) {
        start = math.min(start, range.start);
      } else if (fromMarker &&
          kind != FragmentKind.tableCell &&
          range.start >= end) {
        end = math.max(end, range.end);
      }
    }
    final OffsetMap map = _visible.map;
    final int sourceStart = map.visibleToSource(start).downstream;
    return TextRange(
      start: sourceStart,
      end: math.max(sourceStart, map.visibleToSource(end).upstream),
    );
  }

  TextRange paragraphBoundary(int position) {
    final String source = flow.inputs.source;
    final int at = position.clamp(0, source.length);
    int start = at;
    while (start > 0 && source.codeUnitAt(start - 1) != _lineFeed) {
      start--;
    }
    int end = at;
    while (end < source.length && source.codeUnitAt(end) != _lineFeed) {
      end++;
    }
    if (end < source.length &&
        end > start &&
        source.codeUnitAt(end - 1) == _carriageReturn) {
      end--;
    }
    return TextRange(start: start, end: math.max(start, end));
  }

  TextRange documentBoundary() =>
      TextRange(start: 0, end: flow.inputs.source.length);

  TextPosition _resolve(List<LocatedLine> group, double x) {
    final LocatedLine chosen = _nearestHorizontally(group, x);
    final LineFragment fragment = chosen.fragment;
    final VisualLine line = chosen.line;
    final TextRange range = line.visibleRange;
    final ui.Paragraph? paragraph = fragment.paragraph;
    if (paragraph == null) {
      return x < fragment.rect.center.dx
          ? _toSource(fragment.visibleRange.start, TextAffinity.downstream)
          : _toSource(fragment.visibleRange.end, TextAffinity.upstream);
    }
    if (range.isCollapsed || x < line.left) {
      return _toSource(range.start, TextAffinity.downstream);
    }
    if (x > line.left + line.width) {
      return _toSource(range.end, TextAffinity.upstream);
    }
    final (int, TextAffinity) hit = _hitInLine(chosen, x);
    return _toSource(_nearerAtomicEdge(fragment, hit.$1, x) ?? hit.$1, hit.$2);
  }

  (int, TextAffinity) _hitInLine(LocatedLine located, double x) {
    final LineFragment fragment = located.fragment;
    final VisualLine line = located.line;
    final ui.Paragraph paragraph = fragment.paragraph!;
    final int base = fragment.visibleRange.start;
    final Offset local = Offset(
      x - fragment.origin.dx,
      line.top + line.height / 2 - fragment.origin.dy,
    );
    final ui.GlyphInfo? glyph = paragraph.getClosestGlyphInfoForOffset(local);
    if (glyph != null) {
      final Rect bounds = glyph.graphemeClusterLayoutBounds;
      final TextRange cluster = glyph.graphemeClusterCodeUnitRange;
      final bool inLine =
          base + cluster.start >= line.visibleRange.start &&
          base + cluster.end <= line.visibleRange.end;
      if (inLine && local.dx >= bounds.left && local.dx <= bounds.right) {
        final double middle = bounds.center.dx;
        final bool after = glyph.writingDirection == TextDirection.rtl
            ? local.dx <= middle
            : local.dx >= middle;
        return after
            ? (base + cluster.end, TextAffinity.upstream)
            : (base + cluster.start, TextAffinity.downstream);
      }
    }
    final TextPosition position = paragraph.getPositionForOffset(local);
    final int visible = (base + position.offset).clamp(
      line.visibleRange.start,
      line.visibleRange.end,
    );
    final TextRange cluster = visible < line.visibleRange.end
        ? CaretGeometry.graphemeAt(paragraph, visible - base)
        : TextRange.collapsed(visible - base);
    if (base + cluster.start < visible) {
      final TextBox? box = _geometry.glyphBoxAt(fragment, visible - base);
      final bool after = box != null && x >= (box.left + box.right) / 2;
      return after
          ? (base + cluster.end, TextAffinity.upstream)
          : (base + cluster.start, TextAffinity.downstream);
    }
    return (visible, position.affinity);
  }

  int? _nearerAtomicEdge(LineFragment fragment, int visible, double x) {
    final AtomicObject? atomic = _visible.atomicAtVisible(visible);
    if (atomic == null ||
        atomic.visibleLength < 2 ||
        visible <= atomic.visibleOffset) {
      return null;
    }
    final int start = atomic.visibleOffset;
    final int end = atomic.visibleOffset + atomic.visibleLength;
    final ui.Paragraph? paragraph = fragment.paragraph;
    if (paragraph == null ||
        start < fragment.visibleRange.start ||
        end > fragment.visibleRange.end) {
      return null;
    }
    final List<TextBox> boxes = paragraph.getBoxesForRange(
      start - fragment.visibleRange.start,
      end - fragment.visibleRange.start,
      boxWidthStyle: ui.BoxWidthStyle.tight,
    );
    if (boxes.isEmpty) {
      return null;
    }
    final double left =
        fragment.origin.dx +
        boxes.map((TextBox box) => box.left).reduce(math.min);
    final double right =
        fragment.origin.dx +
        boxes.map((TextBox box) => box.right).reduce(math.max);
    return x - left < right - x ? start : end;
  }

  TextPosition _toSource(int visible, TextAffinity affinity) {
    final SourceOffsets offsets = _visible.map.visibleToSource(visible);
    return TextPosition(
      offset: affinity == TextAffinity.upstream
          ? offsets.upstream
          : offsets.downstream,
      affinity: affinity,
    );
  }

  LocatedLine _nearestHorizontally(List<LocatedLine> group, double x) {
    LocatedLine best = group.first;
    double bestDistance = double.infinity;
    for (final LocatedLine member in group) {
      final LineFragment fragment = member.fragment;
      final double left = fragment.origin.dx;
      final double right = left + fragment.layoutWidth;
      final double distance = x < left
          ? left - x
          : x > right
          ? x - right
          : 0;
      if (distance < bestDistance) {
        best = member;
        bestDistance = distance;
      }
    }
    return best;
  }

  LocatedLine? _lineAtHeight(double y) {
    double reach = _nearestSearchStart;
    while (true) {
      LocatedLine? nearest;
      double nearestDistance = double.infinity;
      for (final LaidOutRow row in flow.rowsIntersecting(
        y - reach,
        y + reach,
      )) {
        for (final LineFragment fragment in row.fragments) {
          if (fragment.kind == FragmentKind.photo) {
            continue;
          }
          for (final VisualLine line in _linesNear(fragment, y, reach)) {
            final double top = line.top;
            final double bottom = line.top + line.height;
            final double distance = y < top
                ? top - y
                : y >= bottom
                ? y - bottom
                : 0;
            if (distance < nearestDistance) {
              nearest = (fragment: fragment, line: line);
              nearestDistance = distance;
            }
          }
        }
      }
      if (nearest != null && nearestDistance <= reach) {
        return nearest;
      }
      if (y - reach <= 0 && y + reach >= flow.height) {
        return nearest;
      }
      reach *= 2;
    }
  }

  Iterable<VisualLine> _linesNear(
    LineFragment fragment,
    double y,
    double reach,
  ) {
    final List<VisualLine> lines = fragment.lines;
    final int first = _upperBound(
      lines.length,
      (int i) => lines[i].top + lines[i].height < y - reach,
    );
    final int last = _upperBound(
      lines.length,
      (int i) => lines[i].top <= y + reach,
    );
    return lines.sublist(math.min(first, last), last);
  }

  Iterable<VisualLine> _linesAtHeight(LineFragment fragment, double y) {
    final List<VisualLine> lines = fragment.lines;
    final int index =
        _upperBound(lines.length, (int i) => lines[i].top <= y) - 1;
    if (index < 0) {
      return const <VisualLine>[];
    }
    final VisualLine line = lines[index];
    return y < line.top + line.height
        ? <VisualLine>[line]
        : const <VisualLine>[];
  }

  LocatedLine? _ownerOf(VisualLine line) {
    for (final LocatedLine located in _geometry.linesHolding(
      line.visibleRange.start,
    )) {
      if (located.line == line) {
        return located;
      }
    }
    return null;
  }

  TextPosition _geometryFallback(VisualLine line) =>
      _toSource(line.visibleRange.start, TextAffinity.downstream);
}

int _upperBound(int length, bool Function(int index) isBefore) {
  int low = 0;
  int high = length;
  while (low < high) {
    final int mid = (low + high) >> 1;
    if (isBefore(mid)) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}
