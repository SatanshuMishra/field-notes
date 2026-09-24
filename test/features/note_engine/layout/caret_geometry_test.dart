import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/caret_geometry.dart';
import 'package:field_notes/features/note_engine/layout/float_flow.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_typography.dart';
import 'package:field_notes/features/note_engine/layout/table_layout.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart' show TextSelectionPoint;
import 'package:flutter_test/flutter_test.dart';

const String _leftMedium = '![](photo/a1b2c3d4e5f6 "left medium")';
const String _rightMedium = '![](photo/a1b2c3d4e5f6 "right medium")';

final String _floatFixture =
    '$_leftMedium\nThe quick brown dog jumps over the lazy fox '
    '${List<String>.filled(140, 'harbour').join(' ')}';

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

CaretGeometry _geometry(
  String source, {
  int? activeLine,
  double columnWidth = 688,
}) => CaretGeometry(
  flow: flowNote(
    _inputs(source, activeLine: activeLine, columnWidth: columnWidth),
    rowLayouter: _routeRow,
  ),
);

OffsetMap _map(CaretGeometry geometry) => geometry.flow.inputs.visibleText.map;

String _visibleText(CaretGeometry geometry) =>
    geometry.flow.inputs.visibleText.text;

List<LocatedLine> _textLines(CaretGeometry geometry) => <LocatedLine>[
  for (final LineFragment fragment in geometry.flow.fragments)
    if (fragment.kind == FragmentKind.text)
      for (final VisualLine line in fragment.lines)
        (fragment: fragment, line: line),
];

List<LocatedLine> _bandLines(CaretGeometry geometry) => <LocatedLine>[
  for (final LocatedLine located in _textLines(geometry))
    if (located.fragment.besideFloat) located,
];

LocatedLine _firstFullWidthLine(CaretGeometry geometry) => _textLines(
  geometry,
).firstWhere((LocatedLine located) => !located.fragment.besideFloat);

Rect _glyphBox(LineFragment fragment, int visibleStart, int visibleEnd) {
  final ui.Paragraph paragraph = fragment.paragraph!;
  final List<TextBox> boxes = paragraph.getBoxesForRange(
    visibleStart - fragment.visibleRange.start,
    visibleEnd - fragment.visibleRange.start,
    boxHeightStyle: ui.BoxHeightStyle.max,
    boxWidthStyle: ui.BoxWidthStyle.tight,
  );
  return boxes
      .map((TextBox box) => box.toRect().shift(fragment.origin))
      .reduce((Rect a, Rect b) => a.expandToInclude(b));
}

Rect _clipped(Rect box, LineFragment fragment) => Rect.fromLTRB(
  math.max(box.left, fragment.origin.dx),
  box.top,
  math.min(box.right, fragment.origin.dx + fragment.layoutWidth),
  box.bottom,
);

double _spaceAdvance(TextStyle style) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: ' ', style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final List<TextBox> boxes = painter.getBoxesForSelection(
    const TextSelection(baseOffset: 0, extentOffset: 1),
    boxWidthStyle: ui.BoxWidthStyle.tight,
  );
  painter.dispose();
  return boxes.first.right - boxes.first.left;
}

int _sourceOf(CaretGeometry geometry, int visibleOffset) =>
    _map(geometry).visibleToSource(visibleOffset).downstream;

List<Rect> _boxesOnLine(List<Rect> boxes, VisualLine line) => <Rect>[
  for (final Rect box in boxes)
    if (box.center.dy > line.top && box.center.dy < line.top + line.height) box,
]..sort((Rect a, Rect b) => a.left.compareTo(b.left));

void main() {
  test(
    'the caret left edge sits on the glyph box edge beside a left float',
    () {
      final CaretGeometry geometry = _geometry(_floatFixture, activeLine: 1);
      final int afterG = _floatFixture.indexOf('dog') + 3;
      for (final TextAffinity affinity in TextAffinity.values) {
        final LocatedLine located = geometry.locate(afterG, affinity);
        final int visible = _map(geometry).sourceToVisible(afterG);
        final Rect g = _glyphBox(located.fragment, visible - 1, visible);
        final Rect caret = geometry.caretRect(afterG, affinity);
        expect(caret.left, closeTo(g.right, 1), reason: '$affinity');
        expect(caret.left, greaterThanOrEqualTo(360));
        expect(caret.top, closeTo(located.line.top, 1));
        expect(
          caret.bottom,
          closeTo(located.line.top + located.line.height, 1),
        );
      }
    },
  );

  test('selection boxes cover exactly the selected glyph boxes', () {
    final CaretGeometry geometry = _geometry(_floatFixture, activeLine: 1);
    final String visibleText = _visibleText(geometry);
    final LocatedLine fullWidth = _firstFullWidthLine(geometry);
    final int lineStart = fullWidth.line.visibleRange.start;
    final String lineText = visibleText.substring(
      lineStart,
      fullWidth.line.visibleRange.end,
    );
    final int wordEnd = lineText.split(' ').take(5).join(' ').length;
    final int visibleStart = visibleText.indexOf('quick');
    final int visibleEnd = lineStart + wordEnd;
    final TextRange range = TextRange(
      start: _sourceOf(geometry, visibleStart),
      end: _sourceOf(geometry, visibleEnd),
    );
    final List<Rect> boxes = geometry.selectionBoxes(range);
    expect(boxes, isNotEmpty);
    final Rect photoAndGutter = Rect.fromLTWH(0, 0, 360, 229.33);
    for (final Rect box in boxes) {
      expect(box.overlaps(photoAndGutter), isFalse, reason: '$box');
    }
    final List<LocatedLine> touched = <LocatedLine>[
      for (final LocatedLine located in _textLines(geometry))
        if (located.line.visibleRange.end > visibleStart &&
            located.line.visibleRange.start < visibleEnd)
          located,
    ];
    expect(touched.length, greaterThan(2));
    int covered = 0;
    for (final LocatedLine located in touched) {
      final VisualLine line = located.line;
      final int from = math.max(visibleStart, line.visibleRange.start);
      final int to = math.min(visibleEnd, line.visibleRange.end);
      final List<Rect> glyphs = <Rect>[
        for (int i = from; i < to; i++)
          _clipped(_glyphBox(located.fragment, i, i + 1), located.fragment),
      ];
      final double left = glyphs.map((Rect r) => r.left).reduce(math.min);
      final double right = glyphs.map((Rect r) => r.right).reduce(math.max);
      final List<Rect> onLine = _boxesOnLine(boxes, line);
      expect(onLine, isNotEmpty, reason: '$line');
      covered += onLine.length;
      expect(onLine.first.left, closeTo(left, 0.5), reason: '$line');
      expect(
        onLine.map((Rect r) => r.right).reduce(math.max),
        closeTo(right, 0.5),
        reason: '$line',
      );
      double reach = onLine.first.left;
      for (final Rect box in onLine) {
        expect(box.left - reach, lessThanOrEqualTo(0.5), reason: '$box');
        reach = math.max(reach, box.right);
        expect(box.top, closeTo(line.top, 0.5), reason: '$box');
        expect(box.bottom, closeTo(line.top + line.height, 0.5));
        expect(box.right, lessThanOrEqualTo(right + 0.5));
      }
    }
    expect(covered, boxes.length);

    const String soft = 'first\nsecond';
    final CaretGeometry plain = _geometry(soft);
    final List<Rect> paragraph = plain.selectionBoxes(
      const TextRange(start: 0, end: soft.length),
    );
    final LineFragment fragment = plain.flow.fragments.single;
    final int glyphBoxes =
        fragment.paragraph!
            .getBoxesForRange(
              0,
              5,
              boxHeightStyle: ui.BoxHeightStyle.max,
              boxWidthStyle: ui.BoxWidthStyle.tight,
            )
            .length +
        fragment.paragraph!
            .getBoxesForRange(
              6,
              12,
              boxHeightStyle: ui.BoxHeightStyle.max,
              boxWidthStyle: ui.BoxWidthStyle.tight,
            )
            .length;
    expect(paragraph.length, glyphBoxes + 1);
    final VisualLine firstLine = fragment.lines.first;
    final Rect lastGlyph = _glyphBox(fragment, 4, 5);
    final List<Rect> extra = <Rect>[
      for (final Rect box in _boxesOnLine(paragraph, firstLine))
        if (box.left >= lastGlyph.right - 0.5) box,
    ];
    expect(extra, hasLength(1));
    expect(extra.single.left, closeTo(lastGlyph.right, 0.5));
    expect(
      extra.single.width,
      closeTo(_spaceAdvance(NoteTypography.body), 0.5),
    );
    expect(extra.single.top, closeTo(firstLine.top, 0.5));
    expect(extra.single.height, closeTo(firstLine.height, 0.5));
  });

  test('selection endpoints carry the line height at each end', () {
    const String source = 'Body text here\n# Big heading';
    final CaretGeometry geometry = _geometry(source);
    final ({
      TextSelectionPoint start,
      double startLineHeight,
      TextSelectionPoint end,
      double endLineHeight,
    })
    endpoints = geometry.selectionEndpoints(const TextRange(start: 5, end: 20));
    expect(endpoints.startLineHeight, closeTo(25.6, 0.5));
    expect(
      endpoints.start.point.dx,
      closeTo(geometry.caretRect(5, TextAffinity.downstream).left, 0.5),
    );
    expect(endpoints.start.point.dy, closeTo(25.6, 0.5));
    expect(endpoints.endLineHeight, closeTo(28.8, 0.5));
    expect(endpoints.end.point.dy, closeTo(73.6, 0.5));
    expect(
      endpoints.end.point.dx,
      closeTo(geometry.caretRect(20, TextAffinity.upstream).left, 0.5),
    );
  });

  test('range bounds cover a range split across fragments', () {
    final CaretGeometry geometry = _geometry(_floatFixture, activeLine: 1);
    final LocatedLine lastBand = _bandLines(geometry).last;
    final LocatedLine fullWidth = _firstFullWidthLine(geometry);
    final int from =
        (lastBand.line.visibleRange.start + lastBand.line.visibleRange.end) ~/
        2;
    final int to =
        (fullWidth.line.visibleRange.start + fullWidth.line.visibleRange.end) ~/
        2;
    final TextRange range = TextRange(
      start: _sourceOf(geometry, from),
      end: _sourceOf(geometry, to),
    );
    final Rect bounds = geometry.rangeBounds(range);
    final List<Rect> boxes = geometry.selectionBoxes(range);
    final Rect union = boxes.reduce((Rect a, Rect b) => a.expandToInclude(b));
    expect(bounds.left, closeTo(union.left, 0.5));
    expect(bounds.top, closeTo(union.top, 0.5));
    expect(bounds.right, closeTo(union.right, 0.5));
    expect(bounds.bottom, closeTo(union.bottom, 0.5));
    expect(bounds.top, closeTo(lastBand.line.top, 0.5));
    expect(
      bounds.bottom,
      closeTo(fullWidth.line.top + fullWidth.line.height, 0.5),
    );
    expect(lastBand.line.top, lessThan(229.33 - 0.5));
    expect(fullWidth.line.top, greaterThanOrEqualTo(229.33 - 0.5));
  });

  test('both affinities split a soft wrap, a float cut and a marker', () {
    final CaretGeometry geometry = _geometry(_floatFixture, activeLine: 1);
    final List<LocatedLine> band = _bandLines(geometry);
    final List<(LocatedLine, LocatedLine)> pairs = <(LocatedLine, LocatedLine)>[
      (band[2], band[3]),
      (band.last, _firstFullWidthLine(geometry)),
    ];
    for (final (LocatedLine earlier, LocatedLine later) in pairs) {
      final int shared = earlier.line.visibleRange.end;
      expect(later.line.visibleRange.start, shared);
      final int position = _sourceOf(geometry, shared);
      final Rect up = geometry.caretRect(position, TextAffinity.upstream);
      final Rect down = geometry.caretRect(position, TextAffinity.downstream);
      expect(up.top, closeTo(earlier.line.top, 0.01));
      expect(down.top, closeTo(later.line.top, 0.01));
      expect(
        up.left,
        closeTo(_glyphBox(earlier.fragment, shared - 1, shared).right, 0.01),
      );
      expect(
        down.left,
        closeTo(_glyphBox(later.fragment, shared, shared + 1).left, 0.01),
      );
      expect(
        identical(
          geometry.locate(position, TextAffinity.upstream).fragment,
          earlier.fragment,
        ),
        isTrue,
      );
    }
    final CaretGeometry list = _geometry('- item\n- other', activeLine: 0);
    expect(
      list.locate(2, TextAffinity.upstream).fragment.kind,
      FragmentKind.marker,
    );
    expect(
      list.locate(2, TextAffinity.downstream).fragment.kind,
      FragmentKind.text,
    );
  });

  test('a caret on a heading line spans the heading line box', () {
    final CaretGeometry geometry = _geometry('# Harbour day\nBody');
    final Rect caret = geometry.caretRect(5, TextAffinity.downstream);
    final VisualLine line = geometry.locate(5, TextAffinity.downstream).line;
    expect(caret.top, closeTo(line.top, 0.01));
    expect(caret.height, closeTo(line.height, 0.01));
    expect(caret.height, closeTo(28.8, 0.5));
    expect(caret.width, 2);
  });

  test('a caret on a blank line sits at its left with the body height', () {
    final CaretGeometry geometry = _geometry('A\n\nB');
    final LocatedLine located = geometry.locate(2, TextAffinity.downstream);
    expect(located.fragment.kind, FragmentKind.blankLine);
    final Rect caret = geometry.caretRect(2, TextAffinity.downstream);
    expect(caret.left, closeTo(located.line.left, 0.01));
    expect(caret.height, closeTo(25.6, 0.5));
  });

  test('a caret in a table cell and in an empty cell', () {
    const String source = 'Intro\n\n| a | bb |\n| --- | ---: |\n| cc |  |';
    final CaretGeometry geometry = _geometry(source);
    final int inCc = source.indexOf('cc') + 1;
    final LocatedLine cell = geometry.locate(inCc, TextAffinity.downstream);
    expect(cell.fragment.kind, FragmentKind.tableCell);
    final int visible = _map(geometry).sourceToVisible(inCc);
    expect(
      geometry.caretRect(inCc, TextAffinity.downstream).left,
      closeTo(_glyphBox(cell.fragment, visible, visible + 1).left, 0.01),
    );
    final MdBlock table = parseNoteTree(
      source,
    ).blocks.firstWhere((MdBlock block) => block.kind == MdBlockKind.table);
    final MdBlock emptyCell = table.blocks
        .where((MdBlock row) => row.kind == MdBlockKind.tableRow)
        .last
        .blocks[1];
    final int empty = emptyCell.contentRange.start;
    final LocatedLine located = geometry.locate(empty, TextAffinity.downstream);
    expect(located.fragment.kind, FragmentKind.tableCell);
    expect(located.fragment.tableColumn, 1);
    final Rect caret = geometry.caretRect(empty, TextAffinity.downstream);
    expect(caret.left, closeTo(located.line.left, 0.01));
    expect(
      caret.left,
      closeTo(located.fragment.origin.dx + located.fragment.layoutWidth, 0.01),
    );
    expect(caret.height, closeTo(25.6, 0.5));
  });

  test(
    'a flow without line fragments answers with an empty line at its top',
    () {
      const String source = 'Alpha\n\nBeta';
      final CaretGeometry geometry = CaretGeometry(
        flow: flowNote(
          _inputs(source),
          rowLayouter:
              (
                LayoutInputs inputs,
                LayoutRow row,
                RowRegion region, {
                int? visibleFrom,
                int? visibleTo,
              }) {
                final LaidOutRow full = layoutRow(inputs, row, region);
                return LaidOutRow(
                  row: full.row,
                  fragments: const <LineFragment>[],
                  decorations: full.decorations,
                  top: full.top,
                  bottom: full.bottom,
                  contentWidth: full.contentWidth,
                );
              },
        ),
      );
      expect(geometry.flow.fragments, isEmpty);
      for (int position = 0; position <= source.length; position++) {
        for (final TextAffinity affinity in TextAffinity.values) {
          final Rect caret = geometry.caretRect(position, affinity);
          expect(caret.left, 0);
          expect(caret.top, 0);
          expect(caret.height, closeTo(25.6, 0.01));
          expect(geometry.lineBoxAt(position, affinity).top, 0);
        }
        expect(
          geometry
              .selectionEndpoints(TextRange(start: 0, end: position))
              .endLineHeight,
          closeTo(25.6, 0.01),
        );
      }
    },
  );

  test('selecting two thousand line breaks stays inside two frames', () {
    final String source = List<String>.generate(
      2000,
      (int i) => i % 5 == 0 ? '# Heading $i' : 'Line $i with words',
    ).join('\n');
    final CaretGeometry geometry = _geometry(source);
    final TextRange all = TextRange(start: 0, end: source.length);
    expect(geometry.selectionBoxes(all).length, greaterThanOrEqualTo(3999));
    int timed() {
      final Stopwatch watch = Stopwatch()..start();
      geometry.selectionBoxes(all);
      return watch.elapsedMicroseconds;
    }

    final List<int> micros = <int>[for (int run = 0; run < 5; run++) timed()]
      ..sort();
    expect(micros.first, lessThan(16000), reason: '$micros');
  });

  test('a divider object gives carets at its edges and a selection rect', () {
    const String source = 'Above\n\n---\n\nBelow';
    final CaretGeometry geometry = _geometry(source);
    final int start = source.indexOf('---');
    final LineFragment divider = geometry.flow.fragments.firstWhere(
      (LineFragment fragment) => fragment.kind == FragmentKind.divider,
    );
    final Rect before = geometry.caretRect(start, TextAffinity.downstream);
    final Rect after = geometry.caretRect(start + 3, TextAffinity.upstream);
    expect(before.left, closeTo(divider.rect.left, 0.01));
    expect(after.left, closeTo(divider.rect.right, 0.01));
    expect(before.top, closeTo(divider.rect.top, 0.01));
    expect(before.height, closeTo(divider.rect.height, 0.01));
    final List<Rect> boxes = geometry.selectionBoxes(
      const TextRange(start: 0, end: source.length),
    );
    expect(boxes, contains(divider.rect));
  });

  test('photos give no selection box and whole blocks bound their rows', () {
    final CaretGeometry geometry = _geometry(_floatFixture, activeLine: 1);
    final PlacedPhoto photo = geometry.flow.photos.single;
    final List<Rect> boxes = geometry.selectionBoxes(
      TextRange(start: 0, end: _floatFixture.length),
    );
    expect(boxes, isNotEmpty);
    for (final Rect box in boxes) {
      expect(box.overlaps(photo.figureRect), isFalse, reason: '$box');
    }
    expect(geometry.rangeBounds(photo.sourceRange), photo.figureRect);

    const String source = 'Intro\n\n| a | b |\n| - | - |\n| c | d |\n\nOutro';
    final CaretGeometry table = _geometry(source);
    final LaidOutRow grid = table.flow.rows.firstWhere(
      (LaidOutRow row) => row.row.kind == LayoutRowKind.table,
    );
    final Rect bounds = table.rangeBounds(grid.row.sourceRange);
    expect(bounds.left, closeTo(0, 0.01));
    expect(bounds.top, closeTo(grid.top, 0.01));
    expect(bounds.right, closeTo(grid.contentWidth, 0.01));
    expect(bounds.bottom, closeTo(grid.bottom, 0.01));
  });

  test('a selection over hidden markers covers only the visible text', () {
    const String source = 'The **fog** lifted';
    final CaretGeometry geometry = _geometry(source);
    final LineFragment fragment = geometry.flow.fragments.single;
    final List<Rect> boxes = geometry.selectionBoxes(
      const TextRange(start: 4, end: 11),
    );
    expect(boxes, isNotEmpty);
    final Rect union = boxes.reduce((Rect a, Rect b) => a.expandToInclude(b));
    final Rect fog = _glyphBox(fragment, 4, 7);
    expect(union.left, closeTo(fog.left, 0.01));
    expect(union.right, closeTo(fog.right, 0.01));
    expect(geometry.selectionBoxes(const TextRange(start: 4, end: 6)), isEmpty);
  });

  test('a CRLF gives one space-width line break box', () {
    const String source = 'a\r\nb';
    final CaretGeometry geometry = _geometry(source);
    final LineFragment fragment = geometry.flow.fragments.single;
    final List<Rect> boxes = geometry.selectionBoxes(
      const TextRange(start: 0, end: 4),
    );
    final Rect a = _glyphBox(fragment, 0, 1);
    final double space = _spaceAdvance(NoteTypography.body);
    final List<Rect> breaks = <Rect>[
      for (final Rect box in boxes)
        if ((box.left - a.right).abs() < 0.5 && (box.width - space).abs() < 0.5)
          box,
    ];
    expect(breaks, hasLength(1));
    expect(boxes, hasLength(3));
  });

  test('beside a right float no selection box passes the band', () {
    final String source =
        '$_rightMedium\n${List<String>.filled(60, 'harbour').join(' ')}';
    final CaretGeometry geometry = _geometry(source, activeLine: 1);
    final LocatedLine first = _bandLines(geometry).first;
    final List<Rect> wrapped = geometry.selectionBoxes(
      TextRange(
        start: _sourceOf(geometry, first.line.visibleRange.start),
        end: _sourceOf(geometry, first.line.visibleRange.end),
      ),
    );
    expect(wrapped, isNotEmpty);
    for (final Rect box in wrapped) {
      expect(box.right, lessThanOrEqualTo(328 + 1e-6), reason: '$box');
    }
    final double space = _spaceAdvance(NoteTypography.body);
    String filler = '';
    for (int words = 1; filler.isEmpty && words < 8; words++) {
      for (int ls = 0; ls < 60; ls++) {
        final String candidate =
            '${List<String>.filled(words, 'harbour').join(' ')} '
            '${'l' * ls}';
        final TextPainter painter = TextPainter(
          text: TextSpan(text: candidate, style: NoteTypography.body),
          textDirection: TextDirection.ltr,
        )..layout();
        final double width = painter.width;
        painter.dispose();
        if (width > 328 - space / 2 && width <= 328 - 0.5) {
          filler = candidate;
          break;
        }
      }
    }
    expect(filler, isNotEmpty);
    final String broken = '$_rightMedium\n$filler\nnext line';
    final CaretGeometry breaking = _geometry(broken);
    final LocatedLine band = _bandLines(breaking).first;
    expect(
      _visibleText(
        breaking,
      ).substring(band.line.visibleRange.start, band.line.visibleRange.end),
      filler,
    );
    final List<Rect> boxes = breaking.selectionBoxes(
      TextRange(start: broken.indexOf(filler), end: broken.length),
    );
    final List<Rect> onLine = _boxesOnLine(boxes, band.line);
    expect(onLine.length, greaterThanOrEqualTo(2));
    for (final Rect box in boxes) {
      expect(box.right, lessThanOrEqualTo(328 + 1e-6), reason: '$box');
    }
  });

  test('an emoji ZWJ sequence is one glyph box', () {
    const String family = '\u{1F468}‍\u{1F469}‍\u{1F467}';
    const String source = 'a${family}b';
    final CaretGeometry geometry = _geometry(source);
    final LineFragment fragment = geometry.flow.fragments.single;
    for (int i = 1; i < 1 + family.length; i++) {
      expect(
        CaretGeometry.graphemeAt(fragment.paragraph!, i),
        const TextRange(start: 1, end: 1 + family.length),
      );
    }
    final TextBox? box = geometry.glyphBoxAt(fragment, 3);
    final Rect whole = _glyphBox(fragment, 1, 1 + family.length);
    expect(box, isNotNull);
    expect(box!.left, closeTo(whole.left, 0.01));
    expect(box.right, closeTo(whole.right, 0.01));
    expect(
      geometry.caretRect(1 + family.length, TextAffinity.upstream).left,
      closeTo(whole.right, 0.01),
    );
  });

  test('a caret inside a right-to-left run sits on the glyph edge', () {
    const String source = 'abc שלום def';
    final CaretGeometry geometry = _geometry(source);
    final LineFragment fragment = geometry.flow.fragments.single;
    final List<TextBox> after = fragment.paragraph!.getBoxesForRange(
      6,
      7,
      boxWidthStyle: ui.BoxWidthStyle.tight,
    );
    expect(after.first.direction, TextDirection.rtl);
    final Rect downstream = geometry.caretRect(6, TextAffinity.downstream);
    expect(
      downstream.left,
      closeTo(after.first.right + fragment.origin.dx, 0.01),
    );
    final List<TextBox> before = fragment.paragraph!.getBoxesForRange(
      5,
      6,
      boxWidthStyle: ui.BoxWidthStyle.tight,
    );
    final Rect upstream = geometry.caretRect(6, TextAffinity.upstream);
    expect(
      upstream.left,
      closeTo(before.first.left + fragment.origin.dx, 0.01),
    );
  });

  test('a collapsed range bounds to the caret with zero width', () {
    final CaretGeometry geometry = _geometry(_floatFixture, activeLine: 1);
    final int position = _floatFixture.indexOf('dog');
    final Rect caret = geometry.caretRect(position, TextAffinity.downstream);
    expect(
      geometry.rangeBounds(TextRange.collapsed(position)),
      Rect.fromLTWH(caret.left, caret.top, 0, caret.height),
    );
    const String hidden = 'The **fog** lifted';
    final CaretGeometry marked = _geometry(hidden);
    final Rect hiddenCaret = marked.caretRect(4, TextAffinity.downstream);
    expect(
      marked.rangeBounds(const TextRange(start: 4, end: 6)),
      Rect.fromLTWH(hiddenCaret.left, hiddenCaret.top, 0, hiddenCaret.height),
    );
  });

  test('the line box beside a float spans only the band fragment', () {
    final CaretGeometry geometry = _geometry(_floatFixture, activeLine: 1);
    final int position = _floatFixture.indexOf('dog');
    final VisualLine line = geometry
        .locate(position, TextAffinity.downstream)
        .line;
    final Rect box = geometry.lineBoxAt(position, TextAffinity.downstream);
    expect(box.left, closeTo(360, 0.01));
    expect(box.right, closeTo(688, 0.01));
    expect(box.top, closeTo(line.top, 0.01));
    expect(box.height, closeTo(line.height, 0.01));
  });

  test('collapsed selection endpoints follow the collapsed affinity', () {
    final CaretGeometry geometry = _geometry(_floatFixture, activeLine: 1);
    final List<LocatedLine> band = _bandLines(geometry);
    final int position = _sourceOf(geometry, band[1].line.visibleRange.end);
    final TextRange collapsed = TextRange.collapsed(position);
    final double upstream = geometry
        .selectionEndpoints(collapsed, collapsedAffinity: TextAffinity.upstream)
        .start
        .point
        .dy;
    final double downstream = geometry
        .selectionEndpoints(collapsed)
        .end
        .point
        .dy;
    expect(upstream, closeTo(band[1].line.top + band[1].line.height, 0.01));
    expect(downstream, closeTo(band[2].line.top + band[2].line.height, 0.01));
  });
}
