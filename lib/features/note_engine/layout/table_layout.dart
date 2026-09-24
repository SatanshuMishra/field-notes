import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_typography.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/painting.dart';

const double tableMinColumnEm = 4;
const double tableCellPaddingVerticalEm = 0.4;
const double tableCellPaddingHorizontalEm = 0.6;

const double _tolerance = 1e-9;
const double _wrapGuard = 1e-6;

final class TableColumnPlan {
  TableColumnPlan({
    required List<double> widths,
    required this.contentWidth,
    required this.scrolls,
  }) : widths = List<double>.unmodifiable(widths);

  final List<double> widths;
  final double contentWidth;
  final bool scrolls;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableColumnPlan &&
          contentWidth == other.contentWidth &&
          scrolls == other.scrolls &&
          listEquals(widths, other.widths);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(widths), contentWidth, scrolls);

  @override
  String toString() =>
      'TableColumnPlan($widths, contentWidth: $contentWidth'
      '${scrolls ? ', scrolls' : ''})';
}

TableColumnPlan planTableColumns(
  List<double> naturalWidths, {
  required double regionWidth,
  required double em,
}) {
  final int count = naturalWidths.length;
  final double gridLines = (count + 1) * NoteTypography.tableGridLineWidth;
  final double available = regionWidth - gridLines;
  final double minimum = tableMinColumnEm * em;
  final double natural = _sum(naturalWidths);
  if (natural <= available + _tolerance) {
    return TableColumnPlan(
      widths: naturalWidths,
      contentWidth: natural + gridLines,
      scrolls: false,
    );
  }
  if (count * minimum <= available + _tolerance) {
    final List<double> widths = _sharedWidths(
      naturalWidths,
      available: available,
      minimum: minimum,
    );
    return TableColumnPlan(
      widths: widths,
      contentWidth: _sum(widths) + gridLines,
      scrolls: false,
    );
  }
  return TableColumnPlan(
    widths: List<double>.filled(count, minimum),
    contentWidth: count * minimum + gridLines,
    scrolls: true,
  );
}

List<double> _sharedWidths(
  List<double> naturalWidths, {
  required double available,
  required double minimum,
}) {
  Set<int> clamped = const <int>{};
  while (true) {
    final double remaining = available - clamped.length * minimum;
    final List<int> free = <int>[
      for (int i = 0; i < naturalWidths.length; i++)
        if (!clamped.contains(i)) i,
    ];
    final double freeNatural = free.fold<double>(
      0,
      (double sum, int i) => sum + naturalWidths[i],
    );
    double shareOf(int i) => freeNatural <= 0
        ? remaining / free.length
        : remaining * naturalWidths[i] / freeNatural;
    final Set<int> under = <int>{
      for (final int i in free)
        if (shareOf(i) < minimum - _tolerance) i,
    };
    if (under.isEmpty || under.length == free.length) {
      return List<double>.unmodifiable(<double>[
        for (int i = 0; i < naturalWidths.length; i++)
          clamped.contains(i) ? minimum : math.max(minimum, shareOf(i)),
      ]);
    }
    clamped = <int>{...clamped, ...under};
  }
}

TableColumnPlan tableColumnsOf(
  LayoutInputs inputs,
  LayoutRow row, {
  required double regionWidth,
}) {
  final List<MdBlock> rows = _tableRowsOf(row);
  final double em = NoteTypography.emOf(inputs.textScaler);
  final double padding = 2 * tableCellPaddingHorizontalEm * em;
  final int count = rows.isEmpty ? 0 : rows.first.blocks.length;
  final List<double> measured = <double>[
    for (int column = 0; column < count; column++)
      rows.indexed.fold<double>(padding, (double widest, (int, MdBlock) entry) {
        final List<MdBlock> cells = entry.$2.blocks;
        if (column >= cells.length) {
          return widest;
        }
        final ui.Paragraph paragraph = buildVisibleParagraph(
          inputs,
          _cellVisibleRange(inputs.visibleText.map, cells[column]),
          base: _baseOf(entry.$1),
          width: double.infinity,
        );
        return math.max(
          widest,
          paragraph.maxIntrinsicWidth.ceilToDouble() + padding,
        );
      }),
  ];
  return planTableColumns(measured, regionWidth: regionWidth, em: em);
}

LaidOutRow layoutTableRow(
  LayoutInputs inputs,
  LayoutRow row,
  RowRegion region, {
  int? visibleFrom,
  int? visibleTo,
}) {
  if (row.kind != LayoutRowKind.table) {
    throw ArgumentError.value(row.kind, 'row.kind', 'must be a table row');
  }
  final List<MdBlock> rows = _tableRowsOf(row);
  final TableColumnPlan plan = tableColumnsOf(
    inputs,
    row,
    regionWidth: region.width,
  );
  final double em = NoteTypography.emOf(inputs.textScaler);
  const double line = NoteTypography.tableGridLineWidth;
  final double padX = tableCellPaddingHorizontalEm * em;
  final double padY = tableCellPaddingVerticalEm * em;
  final int count = plan.widths.length;
  final List<double> columnLefts = <double>[
    for (int column = 0; column < count; column++)
      region.left + _sum(plan.widths.take(column)) + (column + 1) * line,
  ];
  final OffsetMap map = inputs.visibleText.map;
  final List<List<_Cell>> cells = <List<_Cell>>[
    for (int r = 0; r < rows.length; r++)
      <_Cell>[
        for (
          int column = 0;
          column < math.min(count, rows[r].blocks.length);
          column++
        )
          _Cell.measure(
            inputs,
            rows[r].blocks[column],
            column: column,
            base: _baseOf(r),
            width: plan.widths[column] - 2 * padX,
          ),
      ],
  ];
  final List<double> rowHeights = <double>[
    for (final List<_Cell> row in cells)
      row.fold<double>(
            0,
            (double tallest, _Cell cell) => math.max(tallest, cell.extent),
          ) +
          2 * padY,
  ];
  final List<double> rowTops = <double>[
    for (int r = 0; r < rows.length; r++)
      region.top + _sum(rowHeights.take(r)) + (r + 1) * line,
  ];
  final double gridHeight = _sum(rowHeights) + (rows.length + 1) * line;
  final List<LineFragment> fragments = <LineFragment>[
    for (int r = 0; r < rows.length; r++)
      for (final _Cell cell in cells[r])
        LineFragment(
          rowIndex: row.index,
          kind: FragmentKind.tableCell,
          visibleRange: cell.visibleRange,
          origin: Offset(
            columnLefts[cell.column] + padX,
            rowTops[r] + padY - cell.topOffset,
          ),
          layoutWidth: plan.widths[cell.column] - 2 * padX,
          height: cell.extent,
          paragraph: cell.paragraph,
          tableColumn: cell.column,
          textAlign: cell.textAlign,
        ),
  ];
  final List<RowDecoration> decorations = <RowDecoration>[
    if (rows.isNotEmpty)
      RowDecoration(
        kind: RowDecorationKind.tableHeaderBackground,
        rect: Rect.fromLTWH(
          region.left,
          rowTops.first,
          plan.contentWidth,
          rowHeights.first,
        ),
      ),
    for (int column = 0; column <= count; column++)
      RowDecoration(
        kind: RowDecorationKind.tableGridLine,
        rect: Rect.fromLTWH(
          column < count
              ? columnLefts[column] - line
              : region.left + plan.contentWidth - line,
          region.top,
          line,
          gridHeight,
        ),
      ),
    for (int r = 0; r <= rows.length; r++)
      RowDecoration(
        kind: RowDecorationKind.tableGridLine,
        rect: Rect.fromLTWH(
          region.left,
          r < rows.length ? rowTops[r] - line : region.top + gridHeight - line,
          plan.contentWidth,
          line,
        ),
      ),
  ];
  return LaidOutRow(
    row: row,
    fragments: fragments,
    decorations: decorations,
    top: region.top,
    bottom: region.top + gridHeight,
    contentWidth: plan.contentWidth,
    styleRuns: _styleRunsOf(map, row, rows),
  );
}

final class _Cell {
  const _Cell({
    required this.column,
    required this.visibleRange,
    required this.textAlign,
    required this.paragraph,
    required this.topOffset,
    required this.extent,
  });

  factory _Cell.measure(
    LayoutInputs inputs,
    MdBlock cell, {
    required int column,
    required TextStyle base,
    required double width,
  }) {
    final TextRange visibleRange = _cellVisibleRange(
      inputs.visibleText.map,
      cell,
    );
    final TextAlign textAlign = _alignOf(cell);
    final ui.Paragraph paragraph = buildVisibleParagraph(
      inputs,
      visibleRange,
      base: base,
      width: width + _wrapGuard,
      textAlign: textAlign,
    );
    final List<ui.LineMetrics> metrics = paragraph.computeLineMetrics();
    if (metrics.isEmpty) {
      final double? fontSize = base.fontSize;
      final double? height = base.height;
      return _Cell(
        column: column,
        visibleRange: visibleRange,
        textAlign: textAlign,
        paragraph: paragraph,
        topOffset: 0,
        extent: fontSize == null || height == null
            ? paragraph.height
            : inputs.textScaler.scale(fontSize) * height,
      );
    }
    final ui.LineMetrics first = metrics.first;
    final ui.LineMetrics last = metrics.last;
    final double top = first.baseline - first.ascent;
    return _Cell(
      column: column,
      visibleRange: visibleRange,
      textAlign: textAlign,
      paragraph: paragraph,
      topOffset: top,
      extent: last.baseline + last.descent - top,
    );
  }

  final int column;
  final TextRange visibleRange;
  final TextAlign textAlign;
  final ui.Paragraph paragraph;
  final double topOffset;
  final double extent;
}

double _sum(Iterable<double> values) =>
    values.fold<double>(0, (double sum, double value) => sum + value);

List<MdBlock> _tableRowsOf(LayoutRow row) {
  final MdBlock? table = row.block;
  if (table == null || table.kind != MdBlockKind.table) {
    throw ArgumentError.value(row, 'row', 'must carry a table block');
  }
  return <MdBlock>[
    for (final MdBlock child in table.blocks)
      if (child.kind == MdBlockKind.tableRow) child,
  ];
}

TextRange _cellVisibleRange(OffsetMap map, MdBlock cell) => TextRange(
  start: map.sourceToVisible(cell.contentRange.start),
  end: map.sourceToVisible(cell.contentRange.end),
);

TextStyle _baseOf(int rowIndex) => rowIndex == 0
    ? NoteTypography.body.copyWith(fontWeight: NoteTypography.tableHeaderWeight)
    : NoteTypography.body;

TextAlign _alignOf(MdBlock cell) {
  final MdBlockData? data = cell.data;
  final MdCellAlignment alignment = data is MdTableCellData
      ? data.alignment
      : MdCellAlignment.none;
  return switch (alignment) {
    MdCellAlignment.left => TextAlign.left,
    MdCellAlignment.centre => TextAlign.center,
    MdCellAlignment.right => TextAlign.right,
    MdCellAlignment.none => TextAlign.start,
  };
}

List<({TextRange visibleRange, String styleKind})> _styleRunsOf(
  OffsetMap map,
  LayoutRow row,
  List<MdBlock> rows,
) {
  final List<({TextRange visibleRange, String styleKind})> runs =
      <({TextRange visibleRange, String styleKind})>[
        (visibleRange: row.visibleRange, styleKind: MdBlockKind.table.name),
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

  for (final MdBlock tableRow in rows) {
    for (final MdBlock cell in tableRow.blocks) {
      for (final MdInline inline in cell.inlines) {
        visit(inline);
      }
    }
  }
  return runs;
}
