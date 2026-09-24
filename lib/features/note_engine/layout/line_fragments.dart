import 'dart:ui' as ui;

import 'package:field_notes/design/widgets/dashed_divider.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_typography.dart';
import 'package:flutter/painting.dart';

final class VisualLine {
  const VisualLine({
    required this.visibleRange,
    required this.top,
    required this.height,
    required this.baseline,
    required this.left,
    required this.width,
  });

  final TextRange visibleRange;
  final double top;
  final double height;
  final double baseline;
  final double left;
  final double width;

  Rect get box => Rect.fromLTWH(left, top, width, height);

  VisualLine shifted(Offset delta, int visibleDelta) => VisualLine(
    visibleRange: _shiftRange(visibleRange, visibleDelta),
    top: top + delta.dy,
    height: height,
    baseline: baseline + delta.dy,
    left: left + delta.dx,
    width: width,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisualLine &&
          visibleRange == other.visibleRange &&
          top == other.top &&
          height == other.height &&
          baseline == other.baseline &&
          left == other.left &&
          width == other.width;

  @override
  int get hashCode =>
      Object.hash(visibleRange, top, height, baseline, left, width);

  @override
  String toString() =>
      'VisualLine(v[${visibleRange.start}, ${visibleRange.end}), '
      'top: $top, height: $height, baseline: $baseline, left: $left, '
      'width: $width)';
}

enum FragmentKind { text, marker, blankLine, divider, photo, tableCell }

final class LineFragment {
  LineFragment({
    required this.rowIndex,
    required this.kind,
    required this.visibleRange,
    required this.origin,
    required this.layoutWidth,
    required this.height,
    this.paragraph,
    this.besideFloat = false,
    this.tableColumn,
    this.textAlign = TextAlign.start,
  }) : lines = _linesOf(
         paragraph: paragraph,
         visibleRange: visibleRange,
         origin: origin,
         layoutWidth: layoutWidth,
         height: height,
         textAlign: textAlign,
       );

  LineFragment._shifted(
    LineFragment source,
    Offset delta,
    int visibleDelta,
    this.rowIndex,
  ) : kind = source.kind,
      visibleRange = _shiftRange(source.visibleRange, visibleDelta),
      origin = source.origin + delta,
      layoutWidth = source.layoutWidth,
      height = source.height,
      paragraph = source.paragraph,
      besideFloat = source.besideFloat,
      tableColumn = source.tableColumn,
      textAlign = source.textAlign,
      lines = List<VisualLine>.unmodifiable(<VisualLine>[
        for (final VisualLine line in source.lines)
          line.shifted(delta, visibleDelta),
      ]);

  final int rowIndex;
  final FragmentKind kind;
  final TextRange visibleRange;
  final Offset origin;
  final double layoutWidth;
  final double height;
  final ui.Paragraph? paragraph;
  final bool besideFloat;
  final int? tableColumn;
  final TextAlign textAlign;
  final List<VisualLine> lines;

  Rect get rect => origin & Size(layoutWidth, height);

  LineFragment shifted(Offset delta, int visibleDelta, {int? rowIndex}) =>
      LineFragment._shifted(
        this,
        delta,
        visibleDelta,
        rowIndex ?? this.rowIndex,
      );

  void paint(ui.Canvas canvas, Offset offset) {
    final ui.Paragraph? paragraph = this.paragraph;
    if (paragraph == null) {
      return;
    }
    canvas.drawParagraph(paragraph, origin + offset);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LineFragment &&
          rowIndex == other.rowIndex &&
          kind == other.kind &&
          visibleRange == other.visibleRange &&
          origin == other.origin &&
          layoutWidth == other.layoutWidth &&
          height == other.height &&
          identical(paragraph, other.paragraph) &&
          besideFloat == other.besideFloat &&
          tableColumn == other.tableColumn &&
          textAlign == other.textAlign;

  @override
  int get hashCode => Object.hash(
    rowIndex,
    kind,
    visibleRange,
    origin,
    layoutWidth,
    height,
    paragraph == null ? null : identityHashCode(paragraph),
    besideFloat,
    tableColumn,
    textAlign,
  );

  @override
  String toString() =>
      'LineFragment(${kind.name}, row $rowIndex, '
      'v[${visibleRange.start}, ${visibleRange.end}), $origin, '
      'width: $layoutWidth, height: $height'
      '${besideFloat ? ', besideFloat' : ''}'
      '${tableColumn == null ? '' : ', column $tableColumn'})';

  static List<VisualLine> _linesOf({
    required ui.Paragraph? paragraph,
    required TextRange visibleRange,
    required Offset origin,
    required double layoutWidth,
    required double height,
    required TextAlign textAlign,
  }) {
    if (paragraph == null) {
      final Rect rect = origin & Size(layoutWidth, height);
      return List<VisualLine>.unmodifiable(<VisualLine>[
        VisualLine(
          visibleRange: TextRange(
            start: visibleRange.start,
            end: visibleRange.start + 1,
          ),
          top: rect.top,
          height: rect.height,
          baseline: rect.bottom,
          left: rect.left,
          width: rect.width,
        ),
      ]);
    }
    final List<ui.LineMetrics> metrics = paragraph.computeLineMetrics();
    if (metrics.isEmpty) {
      return List<VisualLine>.unmodifiable(<VisualLine>[
        VisualLine(
          visibleRange: TextRange.collapsed(visibleRange.start),
          top: origin.dy,
          height: height,
          baseline: origin.dy + paragraph.alphabeticBaseline,
          left: origin.dx + _emptyLineLeft(textAlign, layoutWidth),
          width: 0,
        ),
      ]);
    }
    final int length = visibleRange.end - visibleRange.start;
    final List<VisualLine> lines = <VisualLine>[];
    int start = 0;
    for (int i = 0; i < metrics.length; i++) {
      final ui.LineMetrics line = metrics[i];
      final bool isLast = i == metrics.length - 1;
      final int next = isLast
          ? length
          : _lineStart(paragraph, i + 1, start, length, metrics.length);
      final int end = !isLast && line.hardBreak && next > start
          ? next - 1
          : next;
      lines.add(
        VisualLine(
          visibleRange: TextRange(
            start: visibleRange.start + start,
            end: visibleRange.start + end,
          ),
          top: origin.dy + line.baseline - line.ascent,
          height: line.ascent + line.descent,
          baseline: origin.dy + line.baseline,
          left: origin.dx + line.left,
          width: line.width,
        ),
      );
      start = next;
    }
    return List<VisualLine>.unmodifiable(lines);
  }

  static int _lineStart(
    ui.Paragraph paragraph,
    int lineNumber,
    int from,
    int length,
    int lineCount,
  ) {
    int low = from + 1;
    int high = length;
    int found = length;
    while (low <= high) {
      final int mid = (low + high) >> 1;
      final int number = mid >= length
          ? lineCount - 1
          : paragraph.getLineNumberAt(mid) ?? lineCount - 1;
      if (number >= lineNumber) {
        found = mid;
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    return found;
  }

  static double _emptyLineLeft(TextAlign textAlign, double layoutWidth) =>
      switch (textAlign) {
        TextAlign.center => layoutWidth / 2,
        TextAlign.right || TextAlign.end => layoutWidth,
        TextAlign.left || TextAlign.start || TextAlign.justify => 0,
      };
}

enum RowDecorationKind {
  quoteRule,
  codeBackground,
  dividerRule,
  tableHeaderBackground,
  tableGridLine,
}

final class RowDecoration {
  const RowDecoration({required this.kind, required this.rect});

  final RowDecorationKind kind;
  final Rect rect;

  bool get paintsBehindText =>
      kind == RowDecorationKind.codeBackground ||
      kind == RowDecorationKind.tableHeaderBackground;

  RowDecoration shifted(Offset delta) =>
      RowDecoration(kind: kind, rect: rect.shift(delta));

  void paint(ui.Canvas canvas, Offset offset) {
    final Rect target = rect.shift(offset);
    switch (kind) {
      case RowDecorationKind.quoteRule:
        canvas.drawRect(target, Paint()..color = NoteTypography.quoteRuleColor);
      case RowDecorationKind.tableGridLine:
        canvas.drawRect(target, Paint()..color = NoteTypography.tableGridColor);
      case RowDecorationKind.tableHeaderBackground:
        canvas.drawRect(
          target,
          Paint()..color = NoteTypography.tableHeaderBackground,
        );
      case RowDecorationKind.codeBackground:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            target,
            const Radius.circular(NoteTypography.codeRadius),
          ),
          Paint()..color = NoteTypography.codeBackground,
        );
      case RowDecorationKind.dividerRule:
        canvas
          ..save()
          ..translate(target.left, target.top);
        const DashedLinePainter(
          axis: Axis.horizontal,
          thickness: NoteTypography.dividerThickness,
          color: NoteTypography.dividerColor,
          dashLength: 6,
          dashGap: 4,
        ).paint(canvas, target.size);
        canvas.restore();
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RowDecoration && kind == other.kind && rect == other.rect;

  @override
  int get hashCode => Object.hash(kind, rect);

  @override
  String toString() => 'RowDecoration(${kind.name}, $rect)';
}

typedef StyleRun = ({TextRange visibleRange, String styleKind});

final class _RowContent {
  _RowContent({
    required List<LineFragment> fragments,
    required List<RowDecoration> decorations,
    required List<StyleRun> styleRuns,
  }) : fragments = List<LineFragment>.unmodifiable(fragments),
       decorations = List<RowDecoration>.unmodifiable(decorations),
       styleRuns = List<StyleRun>.unmodifiable(styleRuns);

  final List<LineFragment> fragments;
  final List<RowDecoration> decorations;
  final List<StyleRun> styleRuns;
}

final class LaidOutRow {
  LaidOutRow({
    required this.row,
    required List<LineFragment> fragments,
    required List<RowDecoration> decorations,
    required this.top,
    required this.bottom,
    required this.contentWidth,
    List<({TextRange visibleRange, String styleKind})> styleRuns =
        const <({TextRange visibleRange, String styleKind})>[],
  }) : _content = _RowContent(
         fragments: fragments,
         decorations: decorations,
         styleRuns: styleRuns,
       ),
       _offset = Offset.zero,
       _visibleDelta = 0,
       _rowIndex = null;

  LaidOutRow._moved({
    required this.row,
    required this._content,
    required this._offset,
    required this._visibleDelta,
    required this._rowIndex,
    required this.top,
    required this.bottom,
    required this.contentWidth,
  });

  final LayoutRow row;
  final double top;
  final double bottom;
  final double contentWidth;
  final _RowContent _content;
  final Offset _offset;
  final int _visibleDelta;
  final int? _rowIndex;

  late final List<LineFragment> fragments =
      _offset == Offset.zero && _visibleDelta == 0 && _rowIndex == null
      ? _content.fragments
      : List<LineFragment>.unmodifiable(<LineFragment>[
          for (final LineFragment fragment in _content.fragments)
            fragment.shifted(_offset, _visibleDelta, rowIndex: _rowIndex),
        ]);

  late final List<RowDecoration> decorations = _offset == Offset.zero
      ? _content.decorations
      : List<RowDecoration>.unmodifiable(<RowDecoration>[
          for (final RowDecoration decoration in _content.decorations)
            decoration.shifted(_offset),
        ]);

  late final List<({TextRange visibleRange, String styleKind})> styleRuns =
      _visibleDelta == 0
      ? _content.styleRuns
      : List<StyleRun>.unmodifiable(<StyleRun>[
          for (final StyleRun run in _content.styleRuns)
            (
              visibleRange: _shiftRange(run.visibleRange, _visibleDelta),
              styleKind: run.styleKind,
            ),
        ]);

  LaidOutRow shifted(Offset delta, int visibleDelta, {LayoutRow? row}) =>
      LaidOutRow._moved(
        row: row ?? this.row,
        content: _content,
        offset: _offset + delta,
        visibleDelta: _visibleDelta + visibleDelta,
        rowIndex: row?.index ?? _rowIndex,
        top: top + delta.dy,
        bottom: bottom + delta.dy,
        contentWidth: contentWidth,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LaidOutRow &&
          row == other.row &&
          top == other.top &&
          bottom == other.bottom &&
          contentWidth == other.contentWidth &&
          _listEquals(fragments, other.fragments) &&
          _listEquals(decorations, other.decorations) &&
          _listEquals(styleRuns, other.styleRuns);

  @override
  int get hashCode => Object.hash(
    row,
    top,
    bottom,
    contentWidth,
    Object.hashAll(fragments),
    Object.hashAll(decorations),
    Object.hashAll(styleRuns),
  );

  @override
  String toString() =>
      'LaidOutRow(row ${row.index}, ${row.kind.name}, top: $top, '
      'bottom: $bottom, $fragments, $decorations)';
}

TextRange _shiftRange(TextRange range, int delta) =>
    TextRange(start: range.start + delta, end: range.end + delta);

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
