import 'dart:ui' as ui;

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/float_flow.dart';
import 'package:field_notes/features/note_engine/layout/hit_testing.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/table_layout.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const String _leftMedium = '![](photo/a1b2c3d4e5f6 "left medium")';
const String _rightMedium = '![](photo/a1b2c3d4e5f6 "right medium")';

String _harbours(int count) => List<String>.filled(count, 'harbour').join(' ');

final String _floatFixture =
    '$_leftMedium\nThe quick brown dog jumps over the lazy fox '
    '${_harbours(140)}';

typedef _Line = ({LineFragment fragment, VisualLine line});

LayoutInputs _inputs(
  String source, {
  int? activeLine,
  double columnWidth = 688,
}) {
  final MdTree tree = parseNoteTree(source);
  return LayoutInputs(
    source: source,
    tree: tree,
    visibleText: const NoteVisibleProjector().project(source, tree, activeLine),
    activeLine: activeLine,
    columnWidth: columnWidth,
    textScaler: TextScaler.noScaling,
    boldText: false,
    locale: const ui.Locale('en', 'US'),
    readerMode: false,
    mediaDimensions: <String, Size>{'a1b2c3d4e5f6': const Size(1200, 800)},
  );
}

LaidOutRow _routeRow(
  LayoutInputs inputs,
  LayoutRow row,
  RowRegion region, {
  int? visibleFrom,
  int? visibleTo,
}) => row.kind == LayoutRowKind.table
    ? layoutTableRow(
        inputs,
        row,
        region,
        visibleFrom: visibleFrom,
        visibleTo: visibleTo,
      )
    : layoutRow(
        inputs,
        row,
        region,
        visibleFrom: visibleFrom,
        visibleTo: visibleTo,
      );

NoteHitTester _tester(
  String source, {
  int? activeLine,
  double columnWidth = 688,
}) => NoteHitTester(
  flow: flowNote(
    _inputs(source, activeLine: activeLine, columnWidth: columnWidth),
    rowLayouter: _routeRow,
  ),
);

OffsetMap _map(NoteHitTester tester) => tester.flow.inputs.visibleText.map;

String _visibleText(NoteHitTester tester) =>
    tester.flow.inputs.visibleText.text;

List<_Line> _lines(NoteHitTester tester, FragmentKind kind) => <_Line>[
  for (final LineFragment fragment in tester.flow.fragments)
    if (fragment.kind == kind)
      for (final VisualLine line in fragment.lines)
        (fragment: fragment, line: line),
];

List<_Line> _bandLines(NoteHitTester tester) => <_Line>[
  for (final _Line line in _lines(tester, FragmentKind.text))
    if (line.line.top < 228.83) line,
];

_Line _firstFullWidthLine(NoteHitTester tester) => _lines(
  tester,
  FragmentKind.text,
).firstWhere((_Line line) => !line.fragment.besideFloat);

int _startOf(NoteHitTester tester, VisualLine line) =>
    _map(tester).visibleToSource(line.visibleRange.start).downstream;

int _endOf(NoteHitTester tester, VisualLine line) =>
    _map(tester).visibleToSource(line.visibleRange.end).upstream;

Rect _glyphBox(LineFragment fragment, int visibleStart, int visibleEnd) {
  final List<TextBox> boxes = fragment.paragraph!.getBoxesForRange(
    visibleStart - fragment.visibleRange.start,
    visibleEnd - fragment.visibleRange.start,
    boxHeightStyle: ui.BoxHeightStyle.max,
    boxWidthStyle: ui.BoxWidthStyle.tight,
  );
  return boxes
      .map((TextBox box) => box.toRect().shift(fragment.origin))
      .reduce((Rect a, Rect b) => a.expandToInclude(b));
}

_Line _lineHolding(NoteHitTester tester, int visibleOffset) =>
    <_Line>[
      ..._lines(tester, FragmentKind.text),
      ..._lines(tester, FragmentKind.tableCell),
    ].firstWhere(
      (_Line line) =>
          line.line.visibleRange.start <= visibleOffset &&
          visibleOffset < line.line.visibleRange.end,
    );

void _expectNearerEdges(
  NoteHitTester tester,
  int visibleStart,
  int visibleEnd,
) {
  final _Line line = _lineHolding(tester, visibleStart);
  final Rect box = _glyphBox(line.fragment, visibleStart, visibleEnd);
  final OffsetMap map = _map(tester);
  expect(
    tester
        .positionAt(Offset(box.left + 0.25 * box.width, box.center.dy))
        .offset,
    map.visibleToSource(visibleStart).downstream,
  );
  expect(
    tester
        .positionAt(Offset(box.left + 0.75 * box.width, box.center.dy))
        .offset,
    map.visibleToSource(visibleEnd).upstream,
  );
}

MdBlock _table(String source) => parseNoteTree(
  source,
).blocks.firstWhere((MdBlock block) => block.kind == MdBlockKind.table);

List<MdBlock> _tableRows(String source) => <MdBlock>[
  for (final MdBlock row in _table(source).blocks)
    if (row.kind == MdBlockKind.tableRow) row,
];

void main() {
  test('a point hit tests to the nearer glyph edge across fragments', () {
    final NoteHitTester tester = _tester(_floatFixture, activeLine: 1);
    final String visible = _visibleText(tester);
    final int g = visible.indexOf('dog') + 2;
    expect(_lineHolding(tester, g).fragment.besideFloat, isTrue);
    _expectNearerEdges(tester, g, g + 1);
    final Rect gBox = _glyphBox(_lineHolding(tester, g).fragment, g, g + 1);
    expect(
      tester
          .positionAt(Offset(gBox.left + 0.75 * gBox.width, gBox.center.dy))
          .offset,
      _floatFixture.indexOf('dog') + 3,
    );
    final _Line full = _firstFullWidthLine(tester);
    final int middle =
        (full.line.visibleRange.start + full.line.visibleRange.end) ~/ 2;
    expect(full.fragment.besideFloat, isFalse);
    _expectNearerEdges(tester, middle, middle + 1);
  });

  test('a point in a line-final space gives the nearer edge of the space', () {
    final String source = 'Para ${_harbours(30)}';
    final NoteHitTester tester = _tester(source);
    final List<_Line> lines = _lines(tester, FragmentKind.text);
    expect(lines.length, greaterThan(1));
    final String visible = _visibleText(tester);
    final int wrapSpace = lines.first.line.visibleRange.end - 1;
    expect(visible[wrapSpace], ' ');
    _expectNearerEdges(tester, wrapSpace, wrapSpace + 1);

    final NoteHitTester beside = _tester(
      '$_leftMedium\n${_harbours(60)}',
      activeLine: 1,
    );
    final OffsetMap map = _map(beside);
    for (final _Line located in _lines(beside, FragmentKind.text)) {
      final VisualLine line = located.line;
      final double y = line.top + line.height / 2;
      for (
        int glyph = line.visibleRange.start;
        glyph < line.visibleRange.end;
        glyph++
      ) {
        final Rect box = _glyphBox(located.fragment, glyph, glyph + 1);
        expect(
          beside.positionAt(Offset(box.left + 0.25 * box.width, y)).offset,
          map.visibleToSource(glyph).downstream,
          reason: 'left quarter of $glyph',
        );
        expect(
          beside.positionAt(Offset(box.left + 0.75 * box.width, y)).offset,
          map.visibleToSource(glyph + 1).upstream,
          reason: 'right quarter of $glyph',
        );
      }
    }

    for (final String marked in <String>[
      '- a\n- b',
      '> a\n> b',
      '1. a\n2. b',
    ]) {
      final NoteHitTester active = _tester(marked, activeLine: 0);
      final LineFragment marker = active.flow.fragments.firstWhere(
        (LineFragment fragment) =>
            fragment.kind == FragmentKind.marker &&
            fragment.visibleRange.start == 0,
      );
      final int space = marker.visibleRange.end - 1;
      expect(_visibleText(active)[space], ' ', reason: marked);
      final Rect box = _glyphBox(marker, space, space + 1);
      expect(
        active
            .positionAt(Offset(box.left + 0.25 * box.width, box.center.dy))
            .offset,
        space,
        reason: marked,
      );
      expect(
        active
            .positionAt(Offset(box.left + 0.75 * box.width, box.center.dy))
            .offset,
        space + 1,
        reason: marked,
      );
    }
  });

  test('a point beside a float resolves to the band line', () {
    final NoteHitTester tester = _tester(_floatFixture, activeLine: 1);
    final List<_Line> band = _bandLines(tester);
    expect(band.length, greaterThan(4));
    for (final _Line located in band) {
      final VisualLine line = located.line;
      final double y = line.box.center.dy;
      final int start = _startOf(tester, line);
      final int end = _endOf(tester, line);
      final int gutter = tester.positionAt(Offset(350, y)).offset;
      expect(gutter, start, reason: '$line');
      final int right = tester.positionAt(Offset(687.5, y)).offset;
      if (line.left + line.width < 687.5) {
        expect(right, end, reason: '$line');
      }
      for (final int result in <int>[gutter, right]) {
        expect(result, inInclusiveRange(start, end));
      }
    }
    final String source = '$_rightMedium\n${_harbours(80)}';
    final NoteHitTester right = _tester(source, activeLine: 1);
    final List<_Line> rightBand = _bandLines(right);
    expect(rightBand, isNotEmpty);
    for (final _Line located in rightBand) {
      expect(located.fragment.origin.dx + located.fragment.layoutWidth, 328);
      expect(
        right.positionAt(Offset(336, located.line.box.center.dy)).offset,
        _endOf(right, located.line),
      );
    }
  });

  test(
    'word, line, paragraph and document boundaries work across fragments',
    () {
      final NoteHitTester tester = _tester(_floatFixture, activeLine: 1);
      final int quick = _floatFixture.indexOf('quick');
      expect(
        tester.wordBoundary(quick + 2),
        TextRange(start: quick, end: quick + 5),
      );
      final _Line full = _firstFullWidthLine(tester);
      final String visible = _visibleText(tester);
      final int wordStart =
          visible.indexOf(' ', full.line.visibleRange.start) + 1;
      final int wordEnd = visible.indexOf(' ', wordStart);
      final OffsetMap map = _map(tester);
      expect(
        tester.wordBoundary(map.visibleToSource(wordStart + 1).downstream),
        TextRange(
          start: map.visibleToSource(wordStart).downstream,
          end: map.visibleToSource(wordEnd).upstream,
        ),
      );
      final _Line lastBand = _bandLines(tester).last;
      for (final _Line located in <_Line>[lastBand, full]) {
        final VisualLine line = located.line;
        final int middle =
            (line.visibleRange.start + line.visibleRange.end) ~/ 2;
        expect(
          tester.lineBoundary(
            map.visibleToSource(middle).downstream,
            TextAffinity.downstream,
          ),
          TextRange(start: _startOf(tester, line), end: _endOf(tester, line)),
        );
      }
      expect(
        tester.paragraphBoundary(quick),
        TextRange(start: _leftMedium.length + 1, end: _floatFixture.length),
      );
      expect(
        tester.documentBoundary(),
        TextRange(start: 0, end: _floatFixture.length),
      );
    },
  );

  test('hidden markers map by the side of the glyph hit', () {
    const String source = 'The **dog** ran';
    final NoteHitTester tester = _tester(source);
    final LineFragment fragment = tester.flow.fragments.single;
    final Rect g = _glyphBox(fragment, 6, 7);
    final TextPosition after = tester.positionAt(
      Offset(g.left + 0.75 * g.width, g.center.dy),
    );
    expect(after.offset, source.indexOf('**', 6));
    expect(after.affinity, TextAffinity.upstream);
    final Rect d = _glyphBox(fragment, 4, 5);
    expect(
      tester.positionAt(Offset(d.left + 0.25 * d.width, d.center.dy)).offset,
      source.indexOf('dog'),
    );
  });

  test('a point in the photo figure gives the photo line start', () {
    final String source = 'Intro\n$_leftMedium\n${_harbours(40)}';
    final NoteHitTester tester = _tester(source);
    final PlacedPhoto photo = tester.flow.photos.single;
    expect(tester.positionAt(photo.figureRect.center).offset, 6);
  });

  test('positionInLine over the float figure lands on the band line', () {
    final NoteHitTester tester = _tester(_floatFixture, activeLine: 1);
    final VisualLine line = _bandLines(tester)[2].line;
    expect(tester.positionInLine(line, 100).offset, _startOf(tester, line));
    expect(tester.positionInLine(line, 687.9).offset, _endOf(tester, line));
  });

  test('points above, below and between lines clamp to the nearest', () {
    const String source = 'Alpha words\n- beta item';
    final NoteHitTester tester = _tester(source);
    final List<LaidOutRow> rows = tester.flow.rows;
    expect(rows, hasLength(2));
    final double gap = rows[1].top - rows[0].bottom;
    expect(gap, closeTo(12.8, 0.01));
    expect(tester.positionAt(const Offset(1, -40)).offset, 0);
    expect(
      tester.positionAt(Offset(600, tester.flow.height + 80)).offset,
      source.length,
    );
    expect(tester.positionAt(Offset(600, rows[0].bottom + 2)).offset, 11);
    expect(
      tester.positionAt(Offset(600, rows[1].top - 2)).offset,
      source.length,
    );
  });

  test('a point in a table lands in the nearest cell', () {
    const String source = '| head | more |\n| --- | --- |\n| alpha | beta |';
    final NoteHitTester tester = _tester(source);
    final List<MdBlock> rows = _tableRows(source);
    final List<_Line> cells = _lines(tester, FragmentKind.tableCell);
    final _Line beta = cells.last;
    final MdBlock betaCell = rows.last.blocks[1];
    final int inside = tester
        .positionAt(beta.line.box.center.translate(-1, 0))
        .offset;
    expect(
      inside,
      inInclusiveRange(betaCell.contentRange.start, betaCell.contentRange.end),
    );
    final _Line alpha = cells[cells.length - 2];
    final double gridX = beta.fragment.origin.dx - 12;
    final double alphaRight =
        alpha.fragment.origin.dx + alpha.fragment.layoutWidth;
    final int onGrid = tester
        .positionAt(Offset(gridX, beta.line.box.center.dy))
        .offset;
    final MdBlock nearer = gridX - alphaRight < beta.fragment.origin.dx - gridX
        ? rows.last.blocks[0]
        : betaCell;
    expect(
      onGrid,
      inInclusiveRange(nearer.contentRange.start, nearer.contentRange.end),
    );
  });

  test('a point on a list glyph gives the nearer edge of the marker', () {
    const String source = '- item\n- other';
    final NoteHitTester tester = _tester(source);
    final LineFragment marker = tester.flow.fragments.firstWhere(
      (LineFragment fragment) => fragment.kind == FragmentKind.marker,
    );
    final Rect box = _glyphBox(marker, 0, 2);
    expect(tester.positionAt(Offset(box.left + 1, box.center.dy)).offset, 0);
    expect(tester.positionAt(Offset(box.right - 1, box.center.dy)).offset, 2);
    for (double x = box.left; x <= box.right; x += 0.5) {
      expect(tester.positionAt(Offset(x, box.center.dy)).offset, anyOf(0, 2));
    }
  });

  test('word boundaries span floats, stop at cells and ignore styles', () {
    final String word = 'x' * 400;
    final String source = '$_leftMedium\nlead $word tail';
    final NoteHitTester tester = _tester(source, activeLine: 1);
    expect(
      tester.flow.fragments.where(
        (LineFragment fragment) => fragment.kind == FragmentKind.text,
      ),
      hasLength(2),
    );
    final int start = source.indexOf(word);
    final TextRange whole = TextRange(start: start, end: start + 400);
    expect(tester.wordBoundary(start + 10), whole);
    expect(tester.wordBoundary(start + 390), whole);

    const String tableSource = '| head | more |\n| --- | --- |\n| ab | cd |';
    final NoteHitTester table = _tester(tableSource);
    final MdBlock cell = _tableRows(tableSource).last.blocks[1];
    expect(
      table.wordBoundary(cell.contentRange.start + 1),
      TextRange(start: cell.contentRange.start, end: cell.contentRange.end),
    );

    final NoteHitTester heading = _tester('# Harbour day');
    final NoteHitTester paragraph = _tester('Harbour day');
    expect(heading.wordBoundary(4), const TextRange(start: 2, end: 9));
    expect(paragraph.wordBoundary(2), const TextRange(start: 0, end: 7));
  });

  test('line boundaries follow affinity, markers and cells', () {
    final NoteHitTester tester = _tester(_floatFixture, activeLine: 1);
    final _Line lastBand = _bandLines(tester).last;
    final int cut = _endOf(tester, lastBand.line);
    expect(
      tester.lineBoundary(cut, TextAffinity.upstream),
      TextRange(
        start: _startOf(tester, lastBand.line),
        end: _endOf(tester, lastBand.line),
      ),
    );
    final _Line full = _firstFullWidthLine(tester);
    expect(
      tester.lineBoundary(cut, TextAffinity.downstream).start,
      _startOf(tester, full.line),
    );

    final NoteHitTester list = _tester('- item one\n- two', activeLine: 0);
    expect(
      list.lineBoundary(5, TextAffinity.downstream),
      const TextRange(start: 0, end: 10),
    );
    expect(
      list.lineBoundary(1, TextAffinity.downstream),
      const TextRange(start: 0, end: 10),
    );

    const String tableSource = '| head | more |\n| --- | --- |\n| ab | cd |';
    final NoteHitTester table = _tester(tableSource);
    final MdBlock cell = _tableRows(tableSource).last.blocks[0];
    expect(
      table.lineBoundary(cell.contentRange.start + 1, TextAffinity.downstream),
      TextRange(start: cell.contentRange.start, end: cell.contentRange.end),
    );
  });

  test('a paragraph boundary excludes a CRLF as one unit', () {
    const String source = 'ab\r\ncd\r\n\r\nef';
    final NoteHitTester tester = _tester(source);
    expect(tester.paragraphBoundary(1), const TextRange(start: 0, end: 2));
    expect(tester.paragraphBoundary(5), const TextRange(start: 4, end: 6));
    expect(tester.paragraphBoundary(8), const TextRange(start: 8, end: 8));
    expect(tester.paragraphBoundary(11), const TextRange(start: 10, end: 12));
  });

  test('an emoji ZWJ sequence is never split', () {
    const String family = '\u{1F468}‍\u{1F469}‍\u{1F467}';
    const String source = 'a${family}b';
    final NoteHitTester tester = _tester(source);
    final LineFragment fragment = tester.flow.fragments.single;
    final Rect box = _glyphBox(fragment, 1, 1 + family.length);
    for (double x = box.left; x <= box.right; x += box.width / 16) {
      expect(
        tester.positionAt(Offset(x, box.center.dy)).offset,
        anyOf(1, 1 + family.length),
      );
    }
  });
}
