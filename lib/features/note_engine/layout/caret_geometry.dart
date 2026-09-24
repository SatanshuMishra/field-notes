import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/float_flow.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_typography.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart' show TextSelectionPoint;

const int _lineFeed = 0x0A;

typedef LocatedLine = ({LineFragment fragment, VisualLine line});

final class CaretGeometry {
  const CaretGeometry({required this.flow});

  final NoteFlow flow;

  VisibleText get _visible => flow.inputs.visibleText;

  ({LineFragment fragment, VisualLine line}) locate(
    int position,
    TextAffinity affinity,
  ) => locateVisible(_visible.map.sourceToVisible(position), affinity);

  ({LineFragment fragment, VisualLine line}) locateVisible(
    int visibleOffset,
    TextAffinity affinity,
  ) {
    final List<LocatedLine> holding = linesHolding(visibleOffset);
    if (holding.isNotEmpty) {
      return affinity == TextAffinity.upstream ? holding.first : holding.last;
    }
    return _nearestLine(visibleOffset);
  }

  List<LocatedLine> linesHolding(int visibleOffset) {
    final List<LaidOutRow> rows = flow.rows;
    final List<LocatedLine> found = <LocatedLine>[];
    for (
      int i =
          _upperBound(
            rows.length,
            (int index) => rows[index].row.visibleRange.start <= visibleOffset,
          ) -
          1;
      i >= 0 && rows[i].row.visibleRange.end >= visibleOffset;
      i--
    ) {
      found.insertAll(0, _linesInRow(rows[i], visibleOffset));
    }
    if (found.length < 2) {
      return List<LocatedLine>.unmodifiable(found);
    }
    final List<LocatedLine> owned = <LocatedLine>[
      for (final LocatedLine located in found)
        if (_holdsVisibleLine(rows[located.fragment.rowIndex].row)) located,
    ];
    return List<LocatedLine>.unmodifiable(owned.isEmpty ? found : owned);
  }

  bool _holdsVisibleLine(LayoutRow row) {
    final List<VisibleLine> lines = _visible.lines;
    final int start = row.sourceRange.start;
    final int index = _upperBound(
      lines.length,
      (int i) => lines[i].sourceRange.start < start,
    );
    return index < lines.length &&
        lines[index].sourceRange.start <=
            math.max(start, row.sourceRange.end - 1);
  }

  Rect caretRect(int position, TextAffinity affinity, {double caretWidth = 2}) {
    final int visible = _visible.map.sourceToVisible(position);
    final LocatedLine located = locateVisible(visible, affinity);
    final VisualLine line = located.line;
    return Rect.fromLTWH(
      caretX(located, visible, affinity),
      line.top,
      caretWidth,
      line.height,
    );
  }

  double caretX(LocatedLine located, int visibleOffset, TextAffinity affinity) {
    final LineFragment fragment = located.fragment;
    final VisualLine line = located.line;
    final ui.Paragraph? paragraph = fragment.paragraph;
    if (paragraph == null) {
      return visibleOffset <= fragment.visibleRange.start
          ? fragment.rect.left
          : fragment.rect.right;
    }
    if (line.visibleRange.isCollapsed) {
      return line.left;
    }
    final int local = visibleOffset - fragment.visibleRange.start;
    final int lineStart = line.visibleRange.start - fragment.visibleRange.start;
    final int lineEnd = line.visibleRange.end - fragment.visibleRange.start;
    final bool before = local >= lineEnd
        ? true
        : local <= lineStart
        ? false
        : affinity == TextAffinity.upstream;
    final TextBox? preferred = before
        ? glyphBoxAt(fragment, local - 1)
        : glyphBoxAt(fragment, local);
    if (preferred != null) {
      return before ? _trailingEdge(preferred) : _leadingEdge(preferred);
    }
    final TextBox? other = before
        ? (local < lineEnd ? glyphBoxAt(fragment, local) : null)
        : (local > lineStart ? glyphBoxAt(fragment, local - 1) : null);
    if (other != null) {
      return before ? _leadingEdge(other) : _trailingEdge(other);
    }
    return line.left;
  }

  TextBox? glyphBoxAt(LineFragment fragment, int localOffset) {
    final ui.Paragraph? paragraph = fragment.paragraph;
    final int length = fragment.visibleRange.end - fragment.visibleRange.start;
    if (paragraph == null || localOffset < 0 || localOffset >= length) {
      return null;
    }
    final TextRange cluster = graphemeAt(paragraph, localOffset);
    final List<TextBox> boxes = paragraph.getBoxesForRange(
      cluster.start,
      cluster.end,
      boxHeightStyle: ui.BoxHeightStyle.max,
      boxWidthStyle: ui.BoxWidthStyle.tight,
    );
    if (boxes.isEmpty) {
      return null;
    }
    final Offset origin = fragment.origin;
    final TextBox first = boxes.first;
    return TextBox.fromLTRBD(
      origin.dx +
          boxes.fold<double>(
            first.left,
            (double left, TextBox box) => math.min(left, box.left),
          ),
      origin.dy + first.top,
      origin.dx +
          boxes.fold<double>(
            first.right,
            (double right, TextBox box) => math.max(right, box.right),
          ),
      origin.dy + first.bottom,
      first.direction,
    );
  }

  List<Rect> selectionBoxes(TextRange range) {
    final (int, int) visible = _visibleSpan(range);
    final int start = visible.$1;
    final int end = visible.$2;
    if (end <= start) {
      return List<Rect>.unmodifiable(const <Rect>[]);
    }
    final String text = _visible.text;
    final List<Rect> boxes = <Rect>[];
    final List<LaidOutRow> rows = flow.rows;
    for (
      int i = _firstRowEndingAtOrAfter(start);
      i < rows.length && rows[i].row.visibleRange.start <= end;
      i++
    ) {
      for (final LineFragment fragment in rows[i].fragments) {
        final TextRange own = fragment.visibleRange;
        if (own.start >= end || own.end <= start) {
          continue;
        }
        final ui.Paragraph? paragraph = fragment.paragraph;
        if (fragment.kind == FragmentKind.photo) {
          continue;
        }
        if (paragraph == null) {
          if (fragment.kind == FragmentKind.divider) {
            boxes.add(fragment.rect);
          }
          continue;
        }
        int segment = math.max(start, own.start);
        final int last = math.min(end, own.end);
        while (segment < last) {
          int stop = segment;
          while (stop < last && text.codeUnitAt(stop) != _lineFeed) {
            stop++;
          }
          if (stop > segment) {
            for (final TextBox box in paragraph.getBoxesForRange(
              segment - own.start,
              stop - own.start,
              boxHeightStyle: ui.BoxHeightStyle.max,
              boxWidthStyle: ui.BoxWidthStyle.tight,
            )) {
              final Rect? clipped = _clip(
                box.toRect().shift(fragment.origin),
                fragment,
              );
              if (clipped != null) {
                boxes.add(clipped);
              }
            }
          }
          segment = stop + 1;
        }
      }
    }
    for (int offset = start; offset < end; offset++) {
      if (text.codeUnitAt(offset) != _lineFeed) {
        continue;
      }
      final Rect? box = _lineBreakBox(offset);
      if (box != null) {
        boxes.add(box);
      }
    }
    return List<Rect>.unmodifiable(boxes);
  }

  ({
    TextSelectionPoint start,
    double startLineHeight,
    TextSelectionPoint end,
    double endLineHeight,
  })
  selectionEndpoints(
    TextRange range, {
    TextAffinity collapsedAffinity = TextAffinity.downstream,
  }) {
    final int low = math.min(range.start, range.end);
    final int high = math.max(range.start, range.end);
    final bool collapsed = low == high;
    final Rect start = caretRect(
      low,
      collapsed ? collapsedAffinity : TextAffinity.downstream,
    );
    final Rect end = collapsed ? start : caretRect(high, TextAffinity.upstream);
    return (
      start: TextSelectionPoint(
        Offset(start.left, start.bottom),
        TextDirection.ltr,
      ),
      startLineHeight: start.height,
      end: TextSelectionPoint(Offset(end.left, end.bottom), TextDirection.ltr),
      endLineHeight: end.height,
    );
  }

  Rect rangeBounds(TextRange range) {
    final int low = math.min(range.start, range.end);
    final int high = math.max(range.start, range.end);
    final List<Rect> rects = <Rect>[
      ...selectionBoxes(TextRange(start: low, end: high)),
      if (high > low) ..._wholeBlockRects(low, high),
    ];
    if (rects.isEmpty) {
      final Rect caret = caretRect(low, TextAffinity.downstream);
      return Rect.fromLTWH(caret.left, caret.top, 0, caret.height);
    }
    return rects
        .skip(1)
        .fold<Rect>(
          rects.first,
          (Rect bounds, Rect rect) => bounds.expandToInclude(rect),
        );
  }

  Rect lineBoxAt(int position, TextAffinity affinity) {
    final LocatedLine located = locate(position, affinity);
    final LineFragment fragment = located.fragment;
    final VisualLine line = located.line;
    return Rect.fromLTWH(
      fragment.origin.dx,
      line.top,
      fragment.layoutWidth,
      line.height,
    );
  }

  static TextRange graphemeAt(ui.Paragraph paragraph, int localOffset) {
    final ui.GlyphInfo? info = paragraph.getGlyphInfoAt(localOffset);
    final TextRange? cluster = info?.graphemeClusterCodeUnitRange;
    return cluster == null || cluster.isCollapsed
        ? TextRange(start: localOffset, end: localOffset + 1)
        : cluster;
  }

  List<Rect> _wholeBlockRects(int start, int end) {
    final List<LaidOutRow> rows = flow.rows;
    final List<Rect> rects = <Rect>[];
    int low = 0;
    int high = rows.length;
    while (low < high) {
      final int mid = (low + high) >> 1;
      if (rows[mid].row.sourceRange.end < start) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    for (
      int i = low;
      i < rows.length && rows[i].row.sourceRange.start <= end;
      i++
    ) {
      final LaidOutRow row = rows[i];
      final TextRange source = row.row.sourceRange;
      if (source.start < start || source.end > end) {
        continue;
      }
      switch (row.row.kind) {
        case LayoutRowKind.photo:
          final PlacedPhoto? photo = _photoOfRow(row.row.index);
          if (photo != null) {
            rects.add(photo.figureRect);
          }
        case LayoutRowKind.table:
        case LayoutRowKind.code:
        case LayoutRowKind.divider:
          rects.add(Rect.fromLTRB(0, row.top, row.contentWidth, row.bottom));
        case LayoutRowKind.text:
        case LayoutRowKind.blankLine:
          break;
      }
    }
    return rects;
  }

  PlacedPhoto? _photoOfRow(int rowIndex) {
    final List<PlacedPhoto> photos = flow.photos;
    final int index =
        _upperBound(photos.length, (int i) => photos[i].rowIndex <= rowIndex) -
        1;
    return index >= 0 && photos[index].rowIndex == rowIndex
        ? photos[index]
        : null;
  }

  Rect? _lineBreakBox(int visibleOffset) {
    final List<LocatedLine> holding = linesHolding(visibleOffset);
    if (holding.isEmpty) {
      return null;
    }
    final LocatedLine located = holding.first;
    final LineFragment fragment = located.fragment;
    if (fragment.paragraph == null) {
      return null;
    }
    final VisualLine line = located.line;
    final double x = caretX(located, visibleOffset, TextAffinity.upstream);
    return _clip(
      Rect.fromLTWH(x, line.top, _spaceAdvance(fragment), line.height),
      fragment,
    );
  }

  double _spaceAdvance(LineFragment fragment) {
    final LayoutInputs inputs = flow.inputs;
    final TextStyle style = NoteTypography.withBoldText(
      _styleAtLineEnd(fragment),
      boldText: inputs.boldText,
    ).copyWith(locale: inputs.locale);
    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
      style.getParagraphStyle(
        textDirection: TextDirection.ltr,
        textScaler: inputs.textScaler,
        locale: inputs.locale,
      ),
    );
    TextSpan(
      text: ' ',
      style: style,
    ).build(builder, textScaler: inputs.textScaler);
    final ui.Paragraph paragraph = builder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: double.infinity));
    final List<TextBox> boxes = paragraph.getBoxesForRange(
      0,
      1,
      boxWidthStyle: ui.BoxWidthStyle.tight,
    );
    return boxes.isEmpty ? 0 : boxes.first.right - boxes.first.left;
  }

  TextStyle _styleAtLineEnd(LineFragment fragment) {
    final LaidOutRow row = flow.rows[fragment.rowIndex];
    if (fragment.kind == FragmentKind.marker ||
        fragment.kind == FragmentKind.blankLine) {
      return NoteTypography.body;
    }
    if (fragment.kind == FragmentKind.tableCell) {
      return _isHeaderCell(row, fragment)
          ? NoteTypography.body.copyWith(
              fontWeight: NoteTypography.tableHeaderWeight,
            )
          : NoteTypography.body;
    }
    if (row.row.kind == LayoutRowKind.code) {
      return NoteTypography.codeBlock;
    }
    final MdBlockData? data = row.row.block?.data;
    return data is MdHeadingData
        ? NoteTypography.heading(data.level)
        : NoteTypography.body;
  }

  bool _isHeaderCell(LaidOutRow row, LineFragment fragment) {
    int previous = -1;
    for (final LineFragment cell in row.fragments) {
      final int column = cell.tableColumn ?? 0;
      if (column <= previous) {
        return false;
      }
      if (identical(cell, fragment)) {
        return true;
      }
      previous = column;
    }
    return false;
  }

  (int, int) _visibleSpan(TextRange range) {
    final OffsetMap map = _visible.map;
    final int low = math.min(range.start, range.end);
    final int high = math.max(range.start, range.end);
    return (map.sourceToVisible(low), map.sourceToVisible(high));
  }

  int _firstRowEndingAtOrAfter(int visibleOffset) {
    final List<LaidOutRow> rows = flow.rows;
    int low = 0;
    int high = rows.length;
    while (low < high) {
      final int mid = (low + high) >> 1;
      if (rows[mid].row.visibleRange.end < visibleOffset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  List<LocatedLine> _linesInRow(LaidOutRow row, int visibleOffset) {
    final List<LineFragment> fragments = row.fragments;
    final List<LocatedLine> found = <LocatedLine>[];
    for (
      int f =
          _upperBound(
            fragments.length,
            (int i) => fragments[i].visibleRange.start <= visibleOffset,
          ) -
          1;
      f >= 0 && fragments[f].visibleRange.end >= visibleOffset;
      f--
    ) {
      final LineFragment fragment = fragments[f];
      final List<VisualLine> lines = fragment.lines;
      final List<LocatedLine> inFragment = <LocatedLine>[];
      for (
        int l =
            _upperBound(
              lines.length,
              (int i) => lines[i].visibleRange.start <= visibleOffset,
            ) -
            1;
        l >= 0 && lines[l].visibleRange.end >= visibleOffset;
        l--
      ) {
        inFragment.insert(0, (fragment: fragment, line: lines[l]));
      }
      found.insertAll(0, inFragment);
    }
    return found;
  }

  LocatedLine _nearestLine(int visibleOffset) {
    final List<LaidOutRow> rows = flow.rows;
    final int before =
        _upperBound(
          rows.length,
          (int i) => rows[i].row.visibleRange.start <= visibleOffset,
        ) -
        1;
    for (int i = before; i >= 0; i--) {
      if (rows[i].fragments.isNotEmpty) {
        final LineFragment fragment = rows[i].fragments.last;
        return (fragment: fragment, line: fragment.lines.last);
      }
    }
    for (int i = math.max(0, before + 1); i < rows.length; i++) {
      if (rows[i].fragments.isNotEmpty) {
        final LineFragment fragment = rows[i].fragments.first;
        return (fragment: fragment, line: fragment.lines.first);
      }
    }
    return _emptyLineAtTop(visibleOffset);
  }

  LocatedLine _emptyLineAtTop(int visibleOffset) {
    final List<LaidOutRow> rows = flow.rows;
    final double top = rows.isEmpty ? 0 : rows.first.top;
    final double height =
        NoteTypography.emOf(flow.inputs.textScaler) *
        NoteTypography.blankLineEm;
    final TextRange range = TextRange.collapsed(visibleOffset);
    return (
      fragment: LineFragment(
        rowIndex: 0,
        kind: FragmentKind.text,
        visibleRange: range,
        origin: Offset(0, top),
        layoutWidth: 0,
        height: height,
      ),
      line: VisualLine(
        visibleRange: range,
        top: top,
        height: height,
        baseline: top + height,
        left: 0,
        width: 0,
      ),
    );
  }

  static Rect? _clip(Rect box, LineFragment fragment) {
    final double left = math.max(box.left, fragment.origin.dx);
    final double right = math.min(
      box.right,
      fragment.origin.dx + fragment.layoutWidth,
    );
    return right > left
        ? Rect.fromLTRB(left, box.top, right, box.bottom)
        : null;
  }

  static double _leadingEdge(TextBox box) =>
      box.direction == TextDirection.ltr ? box.left : box.right;

  static double _trailingEdge(TextBox box) =>
      box.direction == TextDirection.ltr ? box.right : box.left;
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
