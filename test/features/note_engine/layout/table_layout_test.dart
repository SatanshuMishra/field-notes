import 'dart:ui' as ui;

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_typography.dart';
import 'package:field_notes/features/note_engine/layout/table_layout.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

LayoutInputs _inputs(
  String source, {
  double columnWidth = 688,
  TextScaler textScaler = TextScaler.noScaling,
  int? activeLine,
  int? activeCell,
}) {
  final MdTree tree = parseNoteTree(source);
  return LayoutInputs(
    source: source,
    tree: tree,
    visibleText: const NoteVisibleProjector().project(
      source,
      tree,
      activeLine,
      activeCell: activeCell,
    ),
    activeLine: activeLine,
    columnWidth: columnWidth,
    textScaler: textScaler,
    boldText: false,
    locale: const ui.Locale('en', 'US'),
    readerMode: false,
    mediaDimensions: const <String, Size>{},
  );
}

LayoutRow _tableRow(LayoutInputs inputs) => layoutRowsOf(
  inputs,
).firstWhere((LayoutRow row) => row.kind == LayoutRowKind.table);

LaidOutRow _layout(LayoutInputs inputs) => layoutTableRow(
  inputs,
  _tableRow(inputs),
  RowRegion(top: 0, left: 0, width: inputs.columnWidth),
);

String _textOf(LayoutInputs inputs, LineFragment fragment) => inputs
    .visibleText
    .text
    .substring(fragment.visibleRange.start, fragment.visibleRange.end);

List<Rect> _gridLines(LaidOutRow row) => <Rect>[
  for (final RowDecoration decoration in row.decorations)
    if (decoration.kind == RowDecorationKind.tableGridLine) decoration.rect,
];

List<Rect> _verticalLines(LaidOutRow row) =>
    _gridLines(row).where((Rect rect) => rect.height > rect.width).toList();

List<Rect> _horizontalLines(LaidOutRow row) =>
    _gridLines(row).where((Rect rect) => rect.width > rect.height).toList()
      ..sort((Rect a, Rect b) => a.top.compareTo(b.top));

double _textWidth(String text, FontWeight weight) {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: text,
      style: NoteTypography.body.copyWith(
        fontWeight: weight,
        locale: const ui.Locale('en', 'US'),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final double width = painter.width;
  painter.dispose();
  return width;
}

String _wideRow(String cell) =>
    '| ${List<String>.filled(20, cell).join(' | ')} |';

String get _wideDelimiter => '|${List<String>.filled(20, ' --- ').join('|')}|';

void main() {
  test('columns take natural widths when the table fits', () {
    final TableColumnPlan fitted = planTableColumns(
      <double>[100, 60],
      regionWidth: 688,
      em: 16,
    );
    expect(fitted.widths, <double>[100, 60]);
    expect(fitted.contentWidth, 163);
    expect(fitted.scrolls, isFalse);

    final LayoutInputs inputs = _inputs(
      '| Item | Qty |\n| --- | --- |\n| socks | 2 |',
    );
    final LayoutRow row = _tableRow(inputs);
    final LaidOutRow laidOut = layoutTableRow(
      inputs,
      row,
      const RowRegion(top: 0, left: 0, width: 688),
    );
    final TableColumnPlan plan = tableColumnsOf(inputs, row, regionWidth: 688);
    expect(plan.scrolls, isFalse);
    expect(
      laidOut.contentWidth,
      closeTo(plan.widths[0] + plan.widths[1] + 3, 0.01),
    );
    expect(laidOut.contentWidth, lessThan(688));
    final List<LineFragment> cells = laidOut.fragments
        .where(
          (LineFragment fragment) => fragment.kind == FragmentKind.tableCell,
        )
        .toList();
    expect(cells, hasLength(4));
    for (final LineFragment cell in cells) {
      expect(cell.lines, hasLength(1));
    }
    final List<LineFragment> first = cells
        .where((LineFragment cell) => _textOf(inputs, cell) != 'Qty')
        .where((LineFragment cell) => _textOf(inputs, cell) != '2')
        .toList();
    final List<LineFragment> second = cells
        .where((LineFragment cell) => !first.contains(cell))
        .toList();
    expect(first.map((LineFragment cell) => _textOf(inputs, cell)), <String>[
      'Item',
      'socks',
    ]);
    for (final LineFragment cell in first) {
      expect(cell.origin.dx, closeTo(10.6, 0.01));
      expect(cell.tableColumn, 0);
    }
    for (final LineFragment cell in second) {
      expect(cell.origin.dx, closeTo(1 + plan.widths[0] + 1 + 9.6, 0.01));
      expect(cell.tableColumn, 1);
    }
  });

  test('columns share the width with a four em minimum and wrap', () {
    final TableColumnPlan shared = planTableColumns(
      <double>[600, 300, 40],
      regionWidth: 688,
      em: 16,
    );
    expect(shared.widths, hasLength(3));
    expect(shared.widths[0], closeTo(413.33, 0.01));
    expect(shared.widths[1], closeTo(206.67, 0.01));
    expect(shared.widths[2], closeTo(64, 0.01));
    expect(shared.contentWidth, closeTo(688, 0.01));
    expect(shared.scrolls, isFalse);

    final LayoutInputs inputs = _inputs(
      '| a | b | c |\n| --- | --- | --- |\n'
      '| ${List<String>.filled(60, 'harbour').join(' ')} | x | y |',
    );
    final LayoutRow row = _tableRow(inputs);
    final TableColumnPlan plan = tableColumnsOf(inputs, row, regionWidth: 688);
    for (final double width in plan.widths) {
      expect(width, greaterThanOrEqualTo(64));
    }
    final LaidOutRow laidOut = layoutTableRow(
      inputs,
      row,
      const RowRegion(top: 0, left: 0, width: 688),
    );
    expect(laidOut.contentWidth, closeTo(688, 0.01));
    final LineFragment long = laidOut.fragments.firstWhere(
      (LineFragment fragment) =>
          _textOf(inputs, fragment).startsWith('harbour'),
    );
    expect(long.lines.length, greaterThan(1));
  });

  test('a table too wide at four em per column scrolls inside itself', () {
    final TableColumnPlan scrolling = planTableColumns(
      List<double>.filled(20, 200),
      regionWidth: 688,
      em: 16,
    );
    expect(scrolling.widths, List<double>.filled(20, 64));
    expect(scrolling.contentWidth, 1301);
    expect(scrolling.scrolls, isTrue);

    final String row = _wideRow('abcdefghij');
    final LayoutInputs inputs = _inputs('$row\n$_wideDelimiter\n$row');
    final LaidOutRow laidOut = _layout(inputs);
    expect(laidOut.contentWidth, closeTo(1301, 0.01));
    expect(laidOut.contentWidth, greaterThan(688));
  });

  test('twenty columns of one-letter cells fit at their natural widths', () {
    final String row = _wideRow('a');
    final LayoutInputs inputs = _inputs('$row\n$_wideDelimiter\n$row');
    final TableColumnPlan plan = tableColumnsOf(
      inputs,
      _tableRow(inputs),
      regionWidth: 688,
    );
    expect(plan.widths, hasLength(20));
    expect(plan.scrolls, isFalse);
    expect(plan.contentWidth, lessThan(688));
    for (final double width in plan.widths) {
      expect(width, lessThan(64));
    }
    expect(_layout(inputs).contentWidth, closeTo(plan.contentWidth, 0.01));
  });

  test('a one-column table lays out one column', () {
    final LayoutInputs inputs = _inputs('| Only |\n| --- |\n| one |');
    final LaidOutRow laidOut = _layout(inputs);
    expect(laidOut.fragments, hasLength(2));
    for (final LineFragment fragment in laidOut.fragments) {
      expect(fragment.tableColumn, 0);
      expect(fragment.origin.dx, closeTo(10.6, 0.01));
    }
    expect(_verticalLines(laidOut), hasLength(2));
    expect(_horizontalLines(laidOut), hasLength(3));
  });

  test('header cells are weight 600 over a header background', () {
    final LayoutInputs inputs = _inputs('| Item |\n| --- |\n| Item |');
    final LaidOutRow laidOut = _layout(inputs);
    final LineFragment header = laidOut.fragments.first;
    final LineFragment body = laidOut.fragments.last;
    expect(
      header.lines.single.width,
      closeTo(_textWidth('Item', FontWeight.w600), 0.01),
    );
    expect(
      body.lines.single.width,
      closeTo(_textWidth('Item', FontWeight.w400), 0.01),
    );
    expect(
      header.lines.single.width,
      isNot(closeTo(body.lines.single.width, 0.01)),
    );
    final List<Rect> backgrounds = <Rect>[
      for (final RowDecoration decoration in laidOut.decorations)
        if (decoration.kind == RowDecorationKind.tableHeaderBackground)
          decoration.rect,
    ];
    expect(backgrounds, hasLength(1));
    final Rect background = backgrounds.single;
    final List<Rect> horizontal = _horizontalLines(laidOut);
    expect(background.left, closeTo(0, 0.01));
    expect(background.width, closeTo(laidOut.contentWidth, 0.01));
    expect(background.top, closeTo(horizontal[0].bottom, 0.01));
    expect(background.bottom, closeTo(horizontal[1].top, 0.01));
    expect(background.contains(header.rect.center), isTrue);
    expect(background.contains(body.rect.center), isFalse);
  });

  test('grid lines are 1 px, n + 1 vertical and rows + 1 horizontal', () {
    final LayoutInputs inputs = _inputs(
      '| a | b | c |\n| --- | --- | --- |\n| d | e | f |\n| g | h | i |',
    );
    final LaidOutRow laidOut = _layout(inputs);
    final List<Rect> vertical = _verticalLines(laidOut);
    final List<Rect> horizontal = _horizontalLines(laidOut);
    expect(vertical, hasLength(4));
    expect(horizontal, hasLength(4));
    for (final Rect rect in vertical) {
      expect(rect.width, 1);
      expect(rect.top, closeTo(laidOut.top, 0.01));
      expect(rect.bottom, closeTo(laidOut.bottom, 0.01));
    }
    for (final Rect rect in horizontal) {
      expect(rect.height, 1);
      expect(rect.left, closeTo(0, 0.01));
      expect(rect.width, closeTo(laidOut.contentWidth, 0.01));
    }
    expect(horizontal.first.top, closeTo(laidOut.top, 0.01));
    expect(horizontal.last.bottom, closeTo(laidOut.bottom, 0.01));
    final List<double> lefts = vertical.map((Rect rect) => rect.left).toList()
      ..sort();
    expect(lefts.first, closeTo(0, 0.01));
    expect(lefts.last + 1, closeTo(laidOut.contentWidth, 0.01));
  });

  test('a row is its tallest cell plus 12.8', () {
    final LayoutInputs inputs = _inputs(
      '| a | b |\n| --- | --- |\n'
      '| ${List<String>.filled(80, 'harbour').join(' ')} | x |',
    );
    final LaidOutRow laidOut = _layout(inputs);
    final List<Rect> horizontal = _horizontalLines(laidOut);
    final List<LineFragment> bodyCells = laidOut.fragments
        .where(
          (LineFragment fragment) => fragment.origin.dy > horizontal[1].top,
        )
        .toList();
    expect(bodyCells, hasLength(2));
    final double tallest = bodyCells
        .map((LineFragment fragment) => fragment.height)
        .reduce((double a, double b) => a > b ? a : b);
    expect(tallest, greaterThan(25.6 * 2));
    expect(
      horizontal[2].top - horizontal[1].bottom,
      closeTo(tallest + 12.8, 0.01),
    );
    final LineFragment headerCell = laidOut.fragments.first;
    expect(
      horizontal[1].top - horizontal[0].bottom,
      closeTo(headerCell.height + 12.8, 0.01),
    );
    expect(
      laidOut.bottom - laidOut.top,
      closeTo(headerCell.height + tallest + 2 * 12.8 + 3, 0.01),
    );
  });

  test('the delimiter row centres and right-aligns a short cell', () {
    final LayoutInputs inputs = _inputs(
      '| Destination | Destination |\n| :---: | ---: |\n| a | a |',
    );
    final LaidOutRow laidOut = _layout(inputs);
    final LineFragment centred = laidOut.fragments[2];
    final LineFragment right = laidOut.fragments[3];
    expect(_textOf(inputs, centred), 'a');
    expect(centred.textAlign, TextAlign.center);
    expect(right.textAlign, TextAlign.right);
    final VisualLine centreLine = centred.lines.single;
    expect(
      centreLine.left + centreLine.width / 2,
      closeTo(centred.origin.dx + centred.layoutWidth / 2, 0.5),
    );
    expect(centreLine.left, greaterThan(centred.origin.dx + 10));
    final VisualLine rightLine = right.lines.single;
    expect(
      rightLine.left + rightLine.width,
      closeTo(right.origin.dx + right.layoutWidth, 0.5),
    );
    expect(rightLine.left, greaterThan(right.origin.dx + 10));
  });

  test('missing cells draw empty and extra cells are not drawn', () {
    final LayoutInputs inputs = _inputs(
      '| a | b | c |\n| --- | --- | --- |\n| x |\n| p | q | r | s |',
    );
    final LaidOutRow laidOut = _layout(inputs);
    final List<Rect> horizontal = _horizontalLines(laidOut);
    List<LineFragment> inRow(int index) => laidOut.fragments
        .where(
          (LineFragment fragment) =>
              fragment.origin.dy > horizontal[index].top &&
              fragment.origin.dy < horizontal[index + 1].top,
        )
        .toList();
    expect(inRow(0), hasLength(3));
    expect(inRow(1).map((LineFragment cell) => cell.tableColumn), <int>[0]);
    expect(inRow(2).map((LineFragment cell) => cell.tableColumn), <int>[
      0,
      1,
      2,
    ]);
    expect(inRow(2).map((LineFragment cell) => _textOf(inputs, cell)), <String>[
      'p',
      'q',
      'r',
    ]);
    expect(_verticalLines(laidOut), hasLength(4));
    expect(horizontal, hasLength(4));
    expect(
      horizontal[2].top - horizontal[1].bottom,
      closeTo(25.6 + 12.8, 0.01),
    );
  });

  test('an empty cell has a fragment one body line high', () {
    final LayoutInputs inputs = _inputs('|  | b |\n| --- | --- |\n| c | d |');
    final LaidOutRow laidOut = _layout(inputs);
    final LineFragment empty = laidOut.fragments.firstWhere(
      (LineFragment fragment) => fragment.tableColumn == 0,
    );
    expect(empty.visibleRange.isCollapsed, isTrue);
    expect(empty.height, closeTo(25.6, 0.01));
    expect(empty.lines.single.height, closeTo(25.6, 0.01));
    expect(laidOut.fragments, hasLength(4));
  });

  test('inline markers show only in the active cell', () {
    const String source = '| h | i |\n| --- | --- |\n| **b** | **b** |';
    final LayoutInputs inputs = _inputs(source, activeLine: 2, activeCell: 0);
    final LaidOutRow laidOut = _layout(inputs);
    final List<String> body = <String>[
      for (final LineFragment fragment in laidOut.fragments.skip(2))
        _textOf(inputs, fragment),
    ];
    expect(body, <String>['**b**', 'b']);
    final LayoutInputs idle = _inputs(source);
    expect(
      <String>[
        for (final LineFragment fragment in _layout(idle).fragments.skip(2))
          _textOf(idle, fragment),
      ],
      <String>['b', 'b'],
    );
  });

  test('the minimum column width scales with the text scaler', () {
    final String row = _wideRow('abcdefghij');
    final LayoutInputs inputs = _inputs(
      '$row\n$_wideDelimiter\n$row',
      textScaler: const TextScaler.linear(1.15),
    );
    final TableColumnPlan plan = tableColumnsOf(
      inputs,
      _tableRow(inputs),
      regionWidth: 688,
    );
    expect(plan.scrolls, isTrue);
    for (final double width in plan.widths) {
      expect(width, closeTo(73.6, 0.01));
    }
    expect(plan.contentWidth, closeTo(20 * 73.6 + 21, 0.01));
  });

  test('styleRuns start with the table and hold every inline node', () {
    final LayoutInputs inputs = _inputs(
      '| **a** | b |\n| --- | --- |\n| c | ==d== |',
    );
    final LayoutRow row = _tableRow(inputs);
    final LaidOutRow laidOut = layoutTableRow(
      inputs,
      row,
      const RowRegion(top: 0, left: 0, width: 688),
    );
    expect(laidOut.styleRuns.first.visibleRange, row.visibleRange);
    expect(
      laidOut.styleRuns.map(
        (({TextRange visibleRange, String styleKind}) run) => run.styleKind,
      ),
      <String>['table', 'strong', 'text', 'text', 'text', 'highlight', 'text'],
    );
  });

  test('plans built from equal width lists are equal', () {
    final TableColumnPlan a = TableColumnPlan(
      widths: <double>[10, 20],
      contentWidth: 33,
      scrolls: false,
    );
    final TableColumnPlan b = TableColumnPlan(
      widths: <double>[10, 20],
      contentWidth: 33,
      scrolls: false,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(
      a,
      isNot(
        TableColumnPlan(
          widths: <double>[10, 21],
          contentWidth: 33,
          scrolls: false,
        ),
      ),
    );
  });

  test('the grid starts at the region and ignores the visible bounds', () {
    final LayoutInputs inputs = _inputs('| a | b |\n| --- | --- |\n| c | d |');
    final LayoutRow row = _tableRow(inputs);
    final LaidOutRow whole = layoutTableRow(
      inputs,
      row,
      const RowRegion(top: 40, left: 0, width: 688),
    );
    final LaidOutRow bounded = layoutTableRow(
      inputs,
      row,
      const RowRegion(top: 40, left: 0, width: 688),
      visibleFrom: row.visibleRange.start + 2,
      visibleTo: row.visibleRange.start + 3,
    );
    expect(bounded.fragments.length, whole.fragments.length);
    expect(bounded.bottom, whole.bottom);
    expect(whole.top, 40);
    expect(whole.fragments.first.lines.first.top, closeTo(40 + 1 + 6.4, 0.01));
  });
}
