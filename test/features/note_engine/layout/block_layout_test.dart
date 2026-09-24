import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_typography.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

LayoutInputs _inputs(
  String source, {
  int? activeLine,
  double columnWidth = 688,
  double scale = 1,
}) {
  final MdTree tree = parseNoteTree(source);
  return LayoutInputs(
    source: source,
    tree: tree,
    visibleText: const NoteVisibleProjector().project(source, tree, activeLine),
    activeLine: activeLine,
    columnWidth: columnWidth,
    textScaler: scale == 1 ? TextScaler.noScaling : TextScaler.linear(scale),
    boldText: false,
    locale: const ui.Locale('en', 'US'),
    readerMode: false,
    mediaDimensions: const <String, Size>{},
  );
}

List<LaidOutRow> _stack(LayoutInputs inputs) =>
    stackRows(inputs, layoutRowsOf(inputs));

String _textOf(LayoutInputs inputs, LineFragment fragment) => inputs
    .visibleText
    .text
    .substring(fragment.visibleRange.start, fragment.visibleRange.end);

LineFragment _fragmentWith(
  LayoutInputs inputs,
  List<LaidOutRow> rows,
  String text, {
  FragmentKind? kind,
}) => rows
    .expand((LaidOutRow row) => row.fragments)
    .firstWhere(
      (LineFragment fragment) =>
          _textOf(inputs, fragment) == text &&
          (kind == null || fragment.kind == kind),
    );

LineFragment _firstOfKind(LaidOutRow row, FragmentKind kind) =>
    row.fragments.firstWhere((LineFragment fragment) => fragment.kind == kind);

Future<Color> _inkOf(LineFragment fragment) async {
  final ui.Paragraph paragraph = fragment.paragraph!;
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawParagraph(paragraph, Offset.zero);
  final int width = paragraph.maxIntrinsicWidth.ceil() + 2;
  final int height = paragraph.height.ceil() + 2;
  final ui.Image image = recorder.endRecording().toImageSync(width, height);
  final ByteData data = (await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  ))!;
  image.dispose();
  int alpha = 0;
  int at = 0;
  for (int i = 0; i < data.lengthInBytes; i += 4) {
    if (data.getUint8(i + 3) > alpha) {
      alpha = data.getUint8(i + 3);
      at = i;
    }
  }
  return Color.fromARGB(
    alpha,
    data.getUint8(at),
    data.getUint8(at + 1),
    data.getUint8(at + 2),
  );
}

Matcher _drawnIn(Color expected) => predicate<Color>(
  (Color actual) =>
      ((actual.r - expected.r) * 255).abs() <= 3 &&
      ((actual.g - expected.g) * 255).abs() <= 3 &&
      ((actual.b - expected.b) * 255).abs() <= 3 &&
      ((actual.a - expected.a) * 255).abs() <= 6,
  'drawn in $expected',
);

double _plainWidth(String text, TextStyle style) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final double width = painter.maxIntrinsicWidth;
  painter.dispose();
  return width;
}

void main() {
  test(
    'the column is the smaller of the available width and forty five em',
    () {
      expect(
        noteColumnWidth(availableWidth: 688, textScaler: TextScaler.noScaling),
        closeTo(688, 1e-9),
      );
      expect(
        noteColumnWidth(availableWidth: 1000, textScaler: TextScaler.noScaling),
        closeTo(720, 1e-9),
      );
      expect(
        noteColumnWidth(
          availableWidth: 1000,
          textScaler: const TextScaler.linear(0.9),
        ),
        closeTo(648, 1e-9),
      );
      expect(
        noteColumnWidth(
          availableWidth: 1000,
          textScaler: const TextScaler.linear(1.15),
        ),
        closeTo(828, 1e-9),
      );
      expect(
        noteColumnWidth(
          availableWidth: 900,
          textScaler: TextScaler.noScaling,
          fillsWidth: true,
        ),
        closeTo(900, 1e-9),
      );
      expect(
        noteColumnWidth(
          availableWidth: double.infinity,
          textScaler: TextScaler.noScaling,
        ),
        closeTo(720, 1e-9),
      );
    },
  );

  test('a blank line is an empty line box of body line height', () {
    final LayoutInputs inputs = _inputs('A\n\nB');
    final List<LaidOutRow> rows = _stack(inputs);
    expect(rows.map((LaidOutRow row) => row.row.kind), <LayoutRowKind>[
      LayoutRowKind.text,
      LayoutRowKind.blankLine,
      LayoutRowKind.text,
    ]);
    final LaidOutRow a = rows[0];
    final LaidOutRow blank = rows[1];
    final LaidOutRow b = rows[2];
    expect(blank.row.block, isNull);
    expect(blank.fragments, hasLength(1));
    final LineFragment fragment = blank.fragments.single;
    expect(fragment.kind, FragmentKind.blankLine);
    expect(fragment.height, closeTo(25.6, 0.01));
    expect(fragment.lines.single.height, closeTo(25.6, 0.01));
    expect(blank.top, a.bottom);
    expect(fragment.lines.single.top, closeTo(a.bottom, 1e-9));
    expect(b.top - a.bottom, closeTo(25.6, 0.01));
    expect(a.top, 0);
    expect(a.bottom - a.top, closeTo(25.6, 0.01));
    expect(b.top, closeTo(51.2, 0.01));
  });

  test(
    'list indentation stops when less than twelve em of text would remain',
    () {
      final String source = List<String>.generate(
        10,
        (int i) => '${'  ' * i}- l${i + 1}',
      ).join('\n');
      for (final (double column, int stop) in <(double, int)>[
        (720, 10),
        (350, 6),
      ]) {
        final LayoutInputs inputs = _inputs(source, columnWidth: column);
        final List<LaidOutRow> rows = _stack(inputs);
        expect(rows, hasLength(10));
        for (int n = 1; n <= 10; n++) {
          final LaidOutRow row = rows[n - 1];
          final LineFragment text = _firstOfKind(row, FragmentKind.text);
          final LineFragment marker = _firstOfKind(row, FragmentKind.marker);
          final double expected = 25.6 * (n < stop ? n : stop);
          expect(
            text.origin.dx,
            closeTo(expected, 0.01),
            reason: 'level $n text at $column',
          );
          expect(
            marker.origin.dx,
            closeTo(text.origin.dx - 25.6, 0.01),
            reason: 'level $n marker at $column',
          );
        }
      }
    },
  );

  test('an active list line keeps its marker columns', () {
    const String source = '- a\n  - b';
    final LayoutInputs inactive = _inputs(source);
    final List<LaidOutRow> inactiveRows = _stack(inactive);
    expect(
      _firstOfKind(inactiveRows[1], FragmentKind.marker).origin.dx,
      closeTo(25.6, 0.5),
    );
    expect(
      _fragmentWith(inactive, inactiveRows, 'b').origin.dx,
      closeTo(51.2, 0.5),
    );
    final LayoutInputs second = _inputs(source, activeLine: 1);
    final List<LaidOutRow> secondRows = _stack(second);
    expect(
      _fragmentWith(
        second,
        secondRows,
        '- ',
        kind: FragmentKind.marker,
      ).origin.dx,
      closeTo(25.6, 0.5),
    );
    expect(
      _fragmentWith(second, secondRows, 'b', kind: FragmentKind.text).origin.dx,
      closeTo(51.2, 0.5),
    );
    final LayoutInputs first = _inputs(source, activeLine: 0);
    final List<LaidOutRow> firstRows = _stack(first);
    expect(
      _fragmentWith(
        first,
        firstRows,
        '- ',
        kind: FragmentKind.marker,
      ).origin.dx,
      closeTo(0, 0.5),
    );
    expect(
      _fragmentWith(first, firstRows, 'a', kind: FragmentKind.text).origin.dx,
      closeTo(25.6, 0.5),
    );
  });

  test('quote levels inset text and draw two pixel rules', () {
    final LayoutInputs one = _inputs('> q');
    final LaidOutRow oneRow = _stack(one).single;
    expect(
      _firstOfKind(oneRow, FragmentKind.text).origin.dx,
      closeTo(16.4, 0.01),
    );
    expect(oneRow.decorations.single.kind, RowDecorationKind.quoteRule);
    expect(oneRow.decorations.single.rect.left, closeTo(0, 0.01));
    expect(oneRow.decorations.single.rect.width, closeTo(2, 0.01));
    final LayoutInputs two = _inputs('> > q');
    final LaidOutRow twoRow = _stack(two).single;
    expect(
      _firstOfKind(twoRow, FragmentKind.text).origin.dx,
      closeTo(32.8, 0.01),
    );
    expect(
      twoRow.decorations.map((RowDecoration rule) => rule.rect.left),
      <Matcher>[closeTo(0, 0.01), closeTo(16.4, 0.01)],
    );
    for (final RowDecoration rule in twoRow.decorations) {
      expect(rule.kind, RowDecorationKind.quoteRule);
      expect(rule.rect.width, closeTo(2, 0.01));
      expect(rule.rect.top, twoRow.top);
      expect(rule.rect.bottom, twoRow.bottom);
    }
    final LayoutInputs active = _inputs('> q', activeLine: 0);
    final List<LaidOutRow> activeRows = _stack(active);
    expect(
      _fragmentWith(
        active,
        activeRows,
        '> ',
        kind: FragmentKind.marker,
      ).origin.dx,
      closeTo(2, 0.01),
    );
    expect(
      _fragmentWith(active, activeRows, 'q').origin.dx,
      closeTo(16.4, 0.01),
    );
  });

  test(
    'a quoted heading continues the rule and takes the quote style',
    () async {
      final LayoutInputs inputs = _inputs('> a\n> # Harbour day');
      final List<LaidOutRow> rows = _stack(inputs);
      final LaidOutRow a = rows[0];
      final LaidOutRow heading = rows[1];
      expect(heading.row.gapBefore, closeTo(19.2, 0.01));
      expect(heading.row.continuedQuoteLevels, 1);
      expect(heading.top - a.bottom, closeTo(19.2, 0.01));
      expect(
        heading.decorations.single.rect.top,
        closeTo(a.decorations.single.rect.bottom, 1e-9),
      );
      final LineFragment text = _firstOfKind(heading, FragmentKind.text);
      final TextStyle quoted = NoteTypography.quoteOf(
        NoteTypography.heading(1),
      );
      expect(
        text.paragraph!.maxIntrinsicWidth,
        closeTo(_plainWidth('Harbour day', quoted), 0.01),
      );
      expect(
        (text.paragraph!.maxIntrinsicWidth -
                _plainWidth('Harbour day', NoteTypography.heading(1)))
            .abs(),
        greaterThan(0.5),
      );
      expect(text.lines.single.height, closeTo(24 * 1.2, 0.01));
      expect(await _inkOf(text), _drawnIn(Palette.inkSoft));
    },
  );

  test('a quote-only line is a blank row that draws the quote rule', () {
    final LayoutInputs inputs = _inputs('> a\n>\n> b');
    final List<LaidOutRow> rows = _stack(inputs);
    final LaidOutRow blank = rows[1];
    expect(blank.row.kind, LayoutRowKind.blankLine);
    expect(blank.row.block, isNull);
    expect(blank.fragments.single.kind, FragmentKind.blankLine);
    expect(blank.fragments.single.origin.dx, closeTo(16.4, 0.01));
    final RowDecoration rule = blank.decorations.single;
    expect(rule.kind, RowDecorationKind.quoteRule);
    expect(rule.rect.top, blank.top);
    expect(rule.rect.bottom, blank.bottom);
    expect(blank.bottom - blank.top, closeTo(25.6, 0.01));
    final LayoutInputs active = _inputs('> a\n>\n> b', activeLine: 1);
    final LaidOutRow activeBlank = _stack(active)[1];
    final LineFragment marker = _firstOfKind(activeBlank, FragmentKind.marker);
    expect(_textOf(active, marker), '>');
    expect(marker.origin.dx, closeTo(2, 0.01));
    expect(
      _textOf(active, _firstOfKind(activeBlank, FragmentKind.blankLine)),
      '',
    );
  });

  test('a code block insets its lines inside a background', () {
    final LayoutInputs inputs = _inputs('```\nlet x\n```');
    final LaidOutRow row = _stack(inputs).single;
    expect(row.row.kind, LayoutRowKind.code);
    final RowDecoration background = row.decorations.single;
    expect(background.kind, RowDecorationKind.codeBackground);
    expect(background.paintsBehindText, isTrue);
    expect(background.rect, const Rect.fromLTRB(0, 0, 688, 45));
    final LineFragment code = row.fragments.single;
    expect(code.kind, FragmentKind.text);
    expect(_textOf(inputs, code), 'let x');
    expect(code.origin.dx, closeTo(12, 0.01));
    expect(code.lines.single.top, closeTo(12, 0.01));
    expect(code.lines.single.height, closeTo(21, 0.01));
    expect(code.layoutWidth, closeTo(688 - 24, 0.01));
    final LaidOutRow empty = _stack(_inputs('```\n```')).single;
    expect(empty.fragments, isEmpty);
    expect(empty.decorations.single.rect.height, closeTo(45, 0.01));
    final LayoutInputs trailing = _inputs('```\na\n\n```');
    final LineFragment twoLines = _stack(trailing).single.fragments.single;
    expect(twoLines.lines, hasLength(2));
    expect(twoLines.lines[0].visibleRange, const TextRange(start: 0, end: 1));
    expect(twoLines.lines[1].visibleRange, const TextRange.collapsed(2));
  });

  test(
    'a divider is a rule off the active line and dimmed source on it',
    () async {
      final LayoutInputs inputs = _inputs('---');
      final LaidOutRow row = _stack(inputs).single;
      final LineFragment divider = row.fragments.single;
      expect(divider.kind, FragmentKind.divider);
      expect(divider.paragraph, isNull);
      expect(_textOf(inputs, divider), '￼');
      expect(divider.height, closeTo(9.5, 1e-9));
      expect(divider.lines.single.box, divider.rect);
      final RowDecoration rule = row.decorations.single;
      expect(rule.kind, RowDecorationKind.dividerRule);
      expect(rule.paintsBehindText, isFalse);
      expect(rule.rect.top, closeTo(divider.origin.dy + 4, 1e-9));
      expect(rule.rect.height, closeTo(1.5, 1e-9));
      expect(rule.rect.left, divider.rect.left);
      expect(rule.rect.right, divider.rect.right);
      final LayoutInputs active = _inputs('---', activeLine: 0, scale: 3);
      final LineFragment source = _stack(active).single.fragments.single;
      expect(source.kind, FragmentKind.text);
      expect(_textOf(active, source), '---');
      expect(await _inkOf(source), _drawnIn(Palette.ink34));
    },
  );

  test('touching blocks keep their gaps and blank lines replace them', () {
    double gapOf(String source) {
      final List<LaidOutRow> rows = _stack(_inputs(source));
      return rows[1].top - rows[0].bottom;
    }

    expect(gapOf('- a\n- b'), closeTo(4.8, 0.01));
    expect(gapOf('A\n# H'), closeTo(19.2, 0.01));
    expect(gapOf('# H\nA'), closeTo(12.8, 0.01));
    final List<LaidOutRow> loose = _stack(_inputs('- a\n\n- b'));
    expect(loose, hasLength(3));
    expect(loose[1].row.kind, LayoutRowKind.blankLine);
    expect(loose[1].top, loose[0].bottom);
    expect(loose[2].top, loose[1].bottom);
    expect(loose[1].bottom - loose[1].top, closeTo(25.6, 0.01));
  });

  test('a wide marker pushes content and an empty item gets a marker row', () {
    final LayoutInputs wide = _inputs('100. wide');
    final LaidOutRow row = _stack(wide).single;
    final LineFragment marker = _firstOfKind(row, FragmentKind.marker);
    final LineFragment text = _firstOfKind(row, FragmentKind.text);
    expect(_textOf(wide, marker), '100. ');
    expect(marker.origin.dx, 0);
    expect(text.origin.dx, greaterThan(25.6));
    expect(
      text.origin.dx,
      closeTo(marker.origin.dx + marker.paragraph!.maxIntrinsicWidth, 0.01),
    );
    final LayoutInputs empty = _inputs('- a\n- ');
    final List<LaidOutRow> rows = _stack(empty);
    final LaidOutRow item = rows[1];
    expect(item.row.kind, LayoutRowKind.text);
    expect(item.row.block?.kind, MdBlockKind.listItem);
    final LineFragment caret = _firstOfKind(item, FragmentKind.text);
    expect(caret.visibleRange.isCollapsed, isTrue);
    expect(caret.visibleRange.start, empty.visibleText.text.length);
    expect(caret.origin.dx, closeTo(25.6, 0.01));
    expect(caret.height, closeTo(25.6, 0.01));
  });

  test('an active indented marker never leaves the list edge', () {
    final LayoutInputs inputs = _inputs(' - a', activeLine: 0);
    final List<LaidOutRow> rows = _stack(inputs);
    final LineFragment indent = _fragmentWith(inputs, rows, ' ');
    final LineFragment marker = _fragmentWith(inputs, rows, '- ');
    expect(indent.kind, FragmentKind.marker);
    expect(indent.origin.dx, 0);
    expect(
      marker.origin.dx,
      closeTo(indent.origin.dx + indent.paragraph!.maxIntrinsicWidth, 0.01),
    );
    final LaidOutRow band = layoutRow(
      inputs,
      layoutRowsOf(inputs).single,
      const RowRegion(top: 0, left: 360, width: 328, besideFloat: true),
    );
    for (final LineFragment fragment in band.fragments) {
      expect(fragment.origin.dx, greaterThanOrEqualTo(360));
      expect(fragment.besideFloat, isTrue);
    }
  });

  test('checked items are muted and their active box stays undimmed', () async {
    const String source = '- [x] passport\n  - [ ] tickets';
    final LayoutInputs inputs = _inputs(source);
    final List<LaidOutRow> rows = _stack(inputs);
    expect(
      await _inkOf(_fragmentWith(inputs, rows, 'passport')),
      _drawnIn(Palette.muted),
    );
    expect(
      await _inkOf(_fragmentWith(inputs, rows, 'tickets')),
      _drawnIn(Palette.ink),
    );
    final LayoutInputs active = _inputs(source, activeLine: 0);
    final List<LaidOutRow> activeRows = _stack(active);
    final LineFragment marker = _fragmentWith(
      active,
      activeRows,
      '- ☑ ',
      kind: FragmentKind.marker,
    );
    expect(marker.origin.dx, 0);
    expect(await _inkOf(marker), _drawnIn(Palette.ink));
    expect(
      await _inkOf(_fragmentWith(active, activeRows, 'passport')),
      _drawnIn(Palette.muted),
    );
  });

  test('soft breaks are line breaks and a lone CR is not', () {
    final LayoutInputs soft = _inputs('first\nsecond');
    final LineFragment text = _stack(soft).single.fragments.single;
    expect(text.lines, hasLength(2));
    expect(text.lines[1].visibleRange, const TextRange(start: 6, end: 12));
    expect(text.lines[1].top, closeTo(text.lines[0].top + 26, 0.5));
    expect(text.lines[1].left, text.lines[0].left);
    final LayoutInputs lone = _inputs('a\rb');
    final LineFragment one = _stack(lone).single.fragments.single;
    expect(one.lines, hasLength(1));
    expect(one.lines.single.visibleRange, const TextRange(start: 0, end: 3));
  });

  test('an active continuation line keeps its content column', () {
    final LayoutInputs inputs = _inputs('- a\n  b', activeLine: 1);
    final List<LaidOutRow> rows = _stack(inputs);
    expect(rows, hasLength(1));
    expect(_fragmentWith(inputs, rows, 'b').origin.dx, closeTo(25.6, 0.01));
    final LineFragment indent = _fragmentWith(
      inputs,
      rows,
      '  ',
      kind: FragmentKind.marker,
    );
    expect(
      indent.origin.dx + indent.paragraph!.maxIntrinsicWidth,
      closeTo(25.6, 0.01),
    );
  });

  test('empty and whitespace sources are blank rows of body line height', () {
    final List<LaidOutRow> empty = _stack(_inputs(''));
    expect(empty, hasLength(1));
    expect(empty.single.row.kind, LayoutRowKind.blankLine);
    expect(empty.single.row.blockIndex, 0);
    expect(empty.single.bottom - empty.single.top, closeTo(25.6, 0.01));
    final LayoutInputs spaces = _inputs('  \n\t');
    final List<LaidOutRow> rows = _stack(spaces);
    expect(rows.map((LaidOutRow row) => row.row.kind), <LayoutRowKind>[
      LayoutRowKind.blankLine,
      LayoutRowKind.blankLine,
    ]);
    expect(_textOf(spaces, rows[0].fragments.single), '  ');
    expect(_textOf(spaces, rows[1].fragments.single), '\t');
    for (final LaidOutRow row in rows) {
      expect(row.bottom - row.top, closeTo(25.6, 0.01));
    }
    final List<LaidOutRow> scaled = _stack(_inputs('A\n\n\nB', scale: 1.15));
    expect(scaled[1].row.kind, LayoutRowKind.blankLine);
    expect(scaled[2].row.kind, LayoutRowKind.blankLine);
    expect(scaled[1].bottom - scaled[1].top, closeTo(29.44, 0.01));
    expect(scaled[2].bottom - scaled[2].top, closeTo(29.44, 0.01));
    expect(scaled[1].fragments.single.height, closeTo(29.44, 0.01));
  });

  test('a region offsets, wraps and marks every fragment', () {
    const String source =
        '- The harbour fog lifted slowly over the grey water while the '
        'gulls circled the fishing boats and the tide ran out';
    final LayoutInputs inputs = _inputs(source);
    final LayoutRow row = layoutRowsOf(inputs).single;
    final LaidOutRow full = layoutRow(
      inputs,
      row,
      const RowRegion(top: 0, left: 0, width: 688),
    );
    final LaidOutRow band = layoutRow(
      inputs,
      row,
      const RowRegion(top: 100, left: 360, width: 328, besideFloat: true),
    );
    expect(band.top, 100);
    expect(band.fragments, hasLength(full.fragments.length));
    for (int i = 0; i < band.fragments.length; i++) {
      final LineFragment moved = band.fragments[i];
      final LineFragment original = full.fragments[i];
      expect(moved.origin.dx, closeTo(original.origin.dx + 360, 1e-9));
      expect(moved.origin.dy, closeTo(original.origin.dy + 100, 1e-9));
      expect(moved.besideFloat, isTrue);
      expect(original.besideFloat, isFalse);
      expect(moved.rect.right, lessThanOrEqualTo(688 + 1e-9));
    }
    final LineFragment text = _firstOfKind(band, FragmentKind.text);
    expect(text.layoutWidth, closeTo(328 - 25.6, 0.01));
    expect(text.lines.length, greaterThan(1));
    for (final VisualLine line in text.lines) {
      expect(line.width, lessThanOrEqualTo(328 - 25.6 + 0.01));
    }
  });

  test('visible bounds split an item into a marked head and a bare tail', () {
    const String source = '- one two three four';
    final LayoutInputs inputs = _inputs(source);
    final LayoutRow row = layoutRowsOf(inputs).single;
    const RowRegion region = RowRegion(top: 0, left: 0, width: 688);
    final LaidOutRow head = layoutRow(inputs, row, region, visibleTo: 9);
    final LaidOutRow tail = layoutRow(inputs, row, region, visibleFrom: 9);
    expect(head.fragments.map((LineFragment f) => f.kind), <FragmentKind>[
      FragmentKind.marker,
      FragmentKind.text,
    ]);
    expect(_textOf(inputs, head.fragments.last), 'one two');
    expect(tail.fragments.map((LineFragment f) => f.kind), <FragmentKind>[
      FragmentKind.text,
    ]);
    expect(_textOf(inputs, tail.fragments.single), ' three four');
    expect(tail.fragments.single.origin.dx, closeTo(25.6, 0.01));
    expect(head.styleRuns, tail.styleRuns);
    expect(head.styleRuns.first.styleKind, 'bulletList');
  });

  test('style runs name the block kind and every inline node', () {
    final LayoutInputs inputs = _inputs('The **fog** lifted');
    final LaidOutRow row = _stack(inputs).single;
    expect(row.styleRuns, <({TextRange visibleRange, String styleKind})>[
      (
        visibleRange: const TextRange(start: 0, end: 14),
        styleKind: 'paragraph',
      ),
      (visibleRange: const TextRange(start: 0, end: 4), styleKind: 'text'),
      (visibleRange: const TextRange(start: 4, end: 7), styleKind: 'strong'),
      (visibleRange: const TextRange(start: 4, end: 7), styleKind: 'text'),
      (visibleRange: const TextRange(start: 7, end: 14), styleKind: 'text'),
    ]);
    expect(
      () => row.styleRuns.add((
        visibleRange: const TextRange.collapsed(0),
        styleKind: 'text',
      )),
      throwsUnsupportedError,
    );
    final Set<String> blockNames = <String>{
      for (final MdBlockKind kind in MdBlockKind.values) kind.name,
    };
    final Set<String> inlineNames = <String>{
      for (final MdInlineKind kind in MdInlineKind.values) kind.name,
    };
    expect(blockNames.intersection(inlineNames), isEmpty);
    final LayoutInputs mixed = _inputs('# H\n- a *b*\n> q\n\n---');
    final List<LaidOutRow> rows = _stack(mixed);
    expect(
      rows.map((LaidOutRow row) => row.styleRuns.first.styleKind),
      <String>[
        'heading',
        'bulletList',
        'blockQuote',
        'blankLine',
        'thematicBreak',
      ],
    );
    for (final LaidOutRow laid in rows) {
      expect(blockNames, contains(laid.styleRuns.first.styleKind));
      expect(laid.styleRuns.first.visibleRange, laid.row.visibleRange);
      for (final ({TextRange visibleRange, String styleKind}) run
          in laid.styleRuns.skip(1)) {
        expect(inlineNames, contains(run.styleKind));
      }
    }
    expect(
      rows[1].styleRuns.map(
        (({TextRange visibleRange, String styleKind}) run) => run.styleKind,
      ),
      <String>['bulletList', 'text', 'emphasis', 'text'],
    );
  });

  test('a shifted row carries its new row, runs and shared paragraphs', () {
    final LayoutInputs inputs = _inputs('- a\n- The **fog** lifted');
    final List<LayoutRow> rows = layoutRowsOf(inputs);
    final LaidOutRow original = stackRows(inputs, rows)[1];
    final LayoutRow moved = LayoutRow(
      index: 7,
      blockIndex: rows[1].blockIndex,
      kind: rows[1].kind,
      gapRole: rows[1].gapRole,
      block: rows[1].block,
      sourceRange: rows[1].sourceRange,
      visibleRange: TextRange(
        start: rows[1].visibleRange.start + 3,
        end: rows[1].visibleRange.end + 3,
      ),
      gapBefore: rows[1].gapBefore,
      layoutContext: rows[1].layoutContext,
    );
    final LaidOutRow shifted = original.shifted(
      const Offset(0, 40),
      3,
      row: moved,
    );
    expect(shifted.row, moved);
    expect(shifted.top, original.top + 40);
    expect(shifted.bottom, original.bottom + 40);
    for (int i = 0; i < original.fragments.length; i++) {
      final LineFragment before = original.fragments[i];
      final LineFragment after = shifted.fragments[i];
      expect(after.rowIndex, 7);
      expect(identical(after.paragraph, before.paragraph), isTrue);
      expect(after.origin, before.origin + const Offset(0, 40));
      expect(after.visibleRange.start, before.visibleRange.start + 3);
      expect(after.lines.first.top, closeTo(before.lines.first.top + 40, 1e-9));
    }
    expect(shifted.styleRuns, hasLength(original.styleRuns.length));
    for (int i = 0; i < original.styleRuns.length; i++) {
      expect(shifted.styleRuns[i].styleKind, original.styleRuns[i].styleKind);
      expect(
        shifted.styleRuns[i].visibleRange.start,
        original.styleRuns[i].visibleRange.start + 3,
      );
    }
    final LaidOutRow kept = original.shifted(const Offset(0, 5), 0);
    expect(kept.row, original.row);
    expect(kept.fragments.first.rowIndex, original.row.index);
  });

  test('only code and table header backgrounds paint behind text', () {
    const Rect rect = Rect.fromLTWH(0, 0, 10, 10);
    expect(
      <RowDecorationKind, bool>{
        for (final RowDecorationKind kind in RowDecorationKind.values)
          kind: RowDecoration(kind: kind, rect: rect).paintsBehindText,
      },
      <RowDecorationKind, bool>{
        RowDecorationKind.quoteRule: false,
        RowDecorationKind.codeBackground: true,
        RowDecorationKind.dividerRule: false,
        RowDecorationKind.tableHeaderBackground: true,
        RowDecorationKind.tableGridLine: false,
      },
    );
  });

  test('the layout context keys on every container fact', () {
    Object contextOf(String source, int row, {int? activeLine}) => layoutRowsOf(
      _inputs(source, activeLine: activeLine),
    )[row].layoutContext;

    expect(contextOf('- x', 0), isNot(contextOf('- a\n  - x', 1)));
    expect(contextOf('- x', 0), isNot(contextOf('- x', 0, activeLine: 0)));
    expect(contextOf('- a\n\n  b', 2), isNot(contextOf('1. a\n\n   b', 2)));
    expect(contextOf('- a\n  - x', 1), contextOf('- a\n  - x', 1));
    expect(contextOf('- x', 0), contextOf('- x', 0));
  });

  test('photo and table rows are laid out elsewhere', () {
    for (final String source in <String>[
      '![p](photo/abc123abc123)',
      '| a |\n| - |\n| b |',
    ]) {
      final LayoutInputs inputs = _inputs(source);
      final List<LayoutRow> rows = layoutRowsOf(inputs);
      expect(rows.single.kind, anyOf(LayoutRowKind.photo, LayoutRowKind.table));
      expect(() => stackRows(inputs, rows), throwsArgumentError);
      expect(
        () => layoutRow(
          inputs,
          rows.single,
          const RowRegion(top: 0, left: 0, width: 688),
        ),
        throwsArgumentError,
      );
    }
  });

  test('the same inputs lay out to the same geometry', () {
    const String source =
        '# Harbour day\n\n> The **fog** lifted\n\n- [x] passport\n'
        '  1. tickets\n\n```\nlet x\n```\n---\nend';
    for (final int? activeLine in <int?>[null, 4, 8]) {
      final List<LaidOutRow> first = _stack(
        _inputs(source, activeLine: activeLine),
      );
      final List<LaidOutRow> second = _stack(
        _inputs(source, activeLine: activeLine),
      );
      expect(second, hasLength(first.length));
      for (int i = 0; i < first.length; i++) {
        expect(second[i].row, first[i].row);
        expect(second[i].top, first[i].top);
        expect(second[i].bottom, first[i].bottom);
        expect(second[i].decorations, first[i].decorations);
        expect(second[i].styleRuns, first[i].styleRuns);
        expect(second[i].fragments, hasLength(first[i].fragments.length));
        for (int j = 0; j < first[i].fragments.length; j++) {
          final LineFragment a = first[i].fragments[j];
          final LineFragment b = second[i].fragments[j];
          expect(b.kind, a.kind);
          expect(b.visibleRange, a.visibleRange);
          expect(b.rect, a.rect);
          expect(b.lines, a.lines);
        }
      }
    }
  });
}
