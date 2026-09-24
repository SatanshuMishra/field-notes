import 'dart:ui' as ui;

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/caret_geometry.dart';
import 'package:field_notes/features/note_engine/layout/float_flow.dart';
import 'package:field_notes/features/note_engine/layout/hit_testing.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/table_layout.dart';
import 'package:field_notes/features/note_engine/layout/vertical_motion.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const String _leftMedium = '![](photo/a1b2c3d4e5f6 "left medium")';

String _harbours(int count) => List<String>.filled(count, 'harbour').join(' ');

final String _floatFixture = '$_leftMedium\n${_harbours(150)}';

LayoutInputs _inputs(
  String source, {
  int? activeLine,
  int? activeCell,
  double columnWidth = 688,
  Map<String, Size>? mediaDimensions,
  Set<String> unavailableMedia = const <String>{},
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
    textScaler: TextScaler.noScaling,
    boldText: false,
    locale: const ui.Locale('en', 'US'),
    readerMode: false,
    mediaDimensions:
        mediaDimensions ??
        <String, Size>{'a1b2c3d4e5f6': const Size(1200, 800)},
    unavailableMedia: unavailableMedia,
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

NoteFlow _flowOf(LayoutInputs inputs) =>
    flowNote(inputs, rowLayouter: _routeRow);

ActiveLayout _activeFor(LayoutInputs inputs, [List<(int, int?)>? calls]) =>
    (int activeLine, {int? activeCell}) {
      calls?.add((activeLine, activeCell));
      return _flowOf(
        LayoutInputs(
          source: inputs.source,
          tree: inputs.tree,
          visibleText: const NoteVisibleProjector().project(
            inputs.source,
            inputs.tree,
            activeLine,
            activeCell: activeCell,
          ),
          activeLine: activeLine,
          columnWidth: inputs.columnWidth,
          textScaler: inputs.textScaler,
          boldText: inputs.boldText,
          locale: inputs.locale,
          readerMode: inputs.readerMode,
          mediaDimensions: inputs.mediaDimensions,
          unavailableMedia: inputs.unavailableMedia,
        ),
      );
    };

TextPosition _move(
  LayoutInputs inputs,
  TextPosition from,
  double goalX,
  VerticalMove direction, [
  List<(int, int?)>? calls,
]) => findVerticalTarget(
  flow: _flowOf(inputs),
  position: from.offset,
  affinity: from.affinity,
  goalX: goalX,
  direction: direction,
  layoutWithActive: _activeFor(inputs, calls),
);

List<LocatedLine> _textLines(NoteFlow flow) => <LocatedLine>[
  for (final LineFragment fragment in flow.fragments)
    if (fragment.kind == FragmentKind.text)
      for (final VisualLine line in fragment.lines)
        (fragment: fragment, line: line),
];

List<LocatedLine> _bandLines(NoteFlow flow) => <LocatedLine>[
  for (final LocatedLine line in _textLines(flow))
    if (line.fragment.besideFloat) line,
];

List<LocatedLine> _fullWidthLines(NoteFlow flow) => <LocatedLine>[
  for (final LocatedLine line in _textLines(flow))
    if (!line.fragment.besideFloat) line,
];

int _startOf(NoteFlow flow, VisualLine line) => flow.inputs.visibleText.map
    .visibleToSource(line.visibleRange.start)
    .downstream;

double _advanceAt(LocatedLine located, double x) {
  final LineFragment fragment = located.fragment;
  final int base = fragment.visibleRange.start;
  for (
    int i = located.line.visibleRange.start;
    i < located.line.visibleRange.end;
    i++
  ) {
    for (final TextBox box in fragment.paragraph!.getBoxesForRange(
      i - base,
      i + 1 - base,
      boxWidthStyle: ui.BoxWidthStyle.tight,
    )) {
      final double left = box.left + fragment.origin.dx;
      final double right = box.right + fragment.origin.dx;
      if (x >= left && x <= right) {
        return right - left;
      }
    }
  }
  return 0;
}

List<MdBlock> _tableRows(String source) => <MdBlock>[
  for (final MdBlock row
      in parseNoteTree(source).blocks
          .firstWhere((MdBlock block) => block.kind == MdBlockKind.table)
          .blocks)
    if (row.kind == MdBlockKind.tableRow) row,
];

TextPosition Function(int, TextAffinity, double, VerticalMove) _recording(
  LayoutInputs inputs,
  List<double> seen,
) =>
    (
      int position,
      TextAffinity affinity,
      double goalX,
      VerticalMove direction,
    ) {
      seen.add(goalX);
      return _move(
        inputs,
        TextPosition(offset: position, affinity: affinity),
        goalX,
        direction,
      );
    };

void main() {
  test('down keeps the goal within one glyph advance across a float', () {
    final LayoutInputs inputs = _inputs(_floatFixture, activeLine: 1);
    final NoteFlow flow = _flowOf(inputs);
    final List<LocatedLine> band = _bandLines(flow);
    final List<LocatedLine> full = _fullWidthLines(flow);
    expect(band, hasLength(9));
    final List<LocatedLine> expected = <LocatedLine>[
      band[7],
      band[8],
      full[0],
      full[1],
      full[2],
    ];
    final CaretGeometry geometry = CaretGeometry(flow: flow);
    TextPosition position = NoteHitTester(
      flow: flow,
    ).positionInLine(band[6].line, 380);
    for (final LocatedLine line in expected) {
      position = _move(inputs, position, 380, VerticalMove.down);
      final LocatedLine reached = geometry.locate(
        position.offset,
        position.affinity,
      );
      expect(reached.line.top, closeTo(line.line.top, 0.01));
      final double caretX = geometry
          .caretRect(position.offset, position.affinity)
          .left;
      final double advance = _advanceAt(reached, 380);
      expect(advance, greaterThan(0));
      expect((caretX - 380).abs(), lessThanOrEqualTo(advance));
    }
  });

  test('the target line is placed as it looks once active', () {
    const String source =
        'alpha beta gamma delta epsilon\nThe **fog** lifted at noon';
    final LayoutInputs inputs = _inputs(source, activeLine: 0);
    final NoteFlow flow = _flowOf(inputs);
    final String visible = inputs.visibleText.text;
    final int l = visible.indexOf('lifted');
    final LineFragment second = flow.fragments.lastWhere(
      (LineFragment fragment) => fragment.kind == FragmentKind.text,
    );
    expect(
      visible.substring(second.visibleRange.start, second.visibleRange.end),
      'The fog lifted at noon',
    );
    final double goalX =
        second.paragraph!
            .getBoxesForRange(
              l - second.visibleRange.start,
              l + 1 - second.visibleRange.start,
              boxWidthStyle: ui.BoxWidthStyle.tight,
            )
            .first
            .left +
        second.origin.dx;
    final TextPosition result = _move(
      inputs,
      TextPosition(offset: source.indexOf('gamma') + 2),
      goalX,
      VerticalMove.down,
    );
    final NoteFlow active = _activeFor(inputs)(1);
    final VisualLine line = CaretGeometry(
      flow: active,
    ).locate(source.indexOf('The'), TextAffinity.downstream).line;
    expect(
      active.inputs.visibleText.text.substring(
        line.visibleRange.start,
        line.visibleRange.end,
      ),
      'The **fog** lifted at noon',
    );
    expect(
      result.offset,
      NoteHitTester(
        flow: active,
      ).positionAt(Offset(goalX, line.box.center.dy)).offset,
    );
    expect(result.offset, isNot(source.indexOf('lifted')));
  });

  test('the goal resets on an edit or a resize', () {
    final LayoutInputs first = _inputs(_floatFixture, activeLine: 1);
    final NoteFlow flow = _flowOf(first);
    final int start = _startOf(flow, _bandLines(flow)[6].line);
    final List<double> seen1 = <double>[];
    final VerticalStep step1 = moveVertically(
      inputs: first,
      caret: start,
      affinity: TextAffinity.downstream,
      direction: VerticalMove.down,
      goal: null,
      caretX: (int position, TextAffinity affinity) => 380,
      target: _recording(first, seen1),
    );
    expect(seen1, <double>[380]);
    expect(step1.goal.x, 380);

    final LayoutInputs rebuilt = _inputs(
      _floatFixture,
      activeLine: 1,
      mediaDimensions: <String, Size>{'a1b2c3d4e5f6': const Size(1200, 800)},
    );
    expect(identical(rebuilt.mediaDimensions, first.mediaDimensions), isFalse);
    final List<double> seen2 = <double>[];
    final VerticalStep step2 = moveVertically(
      inputs: rebuilt,
      caret: step1.position.offset,
      affinity: step1.position.affinity,
      direction: VerticalMove.down,
      goal: step1.goal,
      caretX: (int position, TextAffinity affinity) => 123,
      target: _recording(rebuilt, seen2),
    );
    expect(seen2, <double>[380]);
    expect(step2.goal.x, step1.goal.x);

    final LayoutInputs edited = _inputs('${_floatFixture}x', activeLine: 1);
    final List<double> seenEdit = <double>[];
    final VerticalStep afterEdit = moveVertically(
      inputs: edited,
      caret: step2.position.offset,
      affinity: step2.position.affinity,
      direction: VerticalMove.down,
      goal: step2.goal,
      caretX: (int position, TextAffinity affinity) => 123,
      target: _recording(edited, seenEdit),
    );
    expect(seenEdit, <double>[123]);
    expect(afterEdit.goal.x, 123);

    final LayoutInputs resized = _inputs(
      _floatFixture,
      activeLine: 1,
      columnWidth: 700,
    );
    final List<double> seenResize = <double>[];
    moveVertically(
      inputs: resized,
      caret: step2.position.offset,
      affinity: step2.position.affinity,
      direction: VerticalMove.down,
      goal: step2.goal,
      caretX: (int position, TextAffinity affinity) => 123,
      target: _recording(resized, seenResize),
    );
    expect(seenResize, <double>[123]);
  });

  test('up on the first line and down on the last reach the ends', () {
    const String source = 'Alpha words\nBeta words';
    final LayoutInputs inputs = _inputs(source, activeLine: 0);
    expect(
      _move(inputs, const TextPosition(offset: 3), 40, VerticalMove.up).offset,
      0,
    );
    final LayoutInputs last = _inputs(source, activeLine: 1);
    expect(
      _move(last, const TextPosition(offset: 15), 40, VerticalMove.down).offset,
      source.length,
    );
  });

  test('a photo is one step and the goal carries past it', () {
    final String source = 'Intro line\n$_leftMedium\n${_harbours(60)}';
    final LayoutInputs inputs = _inputs(source, activeLine: 0);
    final TextPosition onPhoto = _move(
      inputs,
      const TextPosition(offset: 4),
      400,
      VerticalMove.down,
    );
    expect(onPhoto.offset, 11);
    final LayoutInputs photoLine = _inputs(source, activeLine: 1);
    final TextPosition below = _move(
      photoLine,
      onPhoto,
      400,
      VerticalMove.down,
    );
    final NoteFlow active = _activeFor(photoLine)(2);
    final LocatedLine reached = CaretGeometry(
      flow: active,
    ).locate(below.offset, below.affinity);
    expect(reached.fragment.besideFloat, isTrue);
    expect(reached.line, _bandLines(active).first.line);
    final TextPosition back = _move(
      _inputs(source, activeLine: 2),
      below,
      400,
      VerticalMove.up,
    );
    expect(back.offset, 11);
  });

  test('down from the photo line with a goal over the figure', () {
    final LayoutInputs inputs = _inputs(_floatFixture, activeLine: 0);
    final TextPosition result = _move(
      inputs,
      const TextPosition(offset: 0),
      100,
      VerticalMove.down,
    );
    expect(result.offset, _leftMedium.length + 1);
  });

  test('each empty line is one step', () {
    const String source = 'Alpha\n\n\nOmega';
    TextPosition position = const TextPosition(offset: 2);
    final List<int> reached = <int>[];
    for (final int active in <int>[0, 1, 2]) {
      position = _move(
        _inputs(source, activeLine: active),
        position,
        20,
        VerticalMove.down,
      );
      reached.add(position.offset);
    }
    expect(reached.take(2), <int>[6, 7]);
    expect(reached.last, inInclusiveRange(8, source.length));
  });

  test('down in a table moves by cell lines and then across rows', () {
    const String source = '| head | more |\n| --- | --- |\n| alpha | beta |';
    final LayoutInputs inputs = _inputs(source, activeLine: 0, activeCell: 1);
    final NoteFlow flow = _flowOf(inputs);
    final List<MdBlock> rows = _tableRows(source);
    final LineFragment more = flow.fragments.firstWhere(
      (LineFragment fragment) => fragment.tableColumn == 1,
    );
    final List<(int, int?)> calls = <(int, int?)>[];
    final TextPosition result = _move(
      inputs,
      TextPosition(offset: rows.first.blocks[1].contentRange.start + 1),
      more.origin.dx + 4,
      VerticalMove.down,
      calls,
    );
    final MdRange beta = rows.last.blocks[1].contentRange;
    expect(result.offset, inInclusiveRange(beta.start, beta.end));
    expect(calls, <(int, int?)>[(2, 1)]);

    final String wrapping = '| h | long |\n| - | - |\n| a | ${_harbours(30)} |';
    final LayoutInputs wide = _inputs(wrapping, activeLine: 2, activeCell: 1);
    final NoteFlow wideFlow = _flowOf(wide);
    final LineFragment long = wideFlow.fragments.lastWhere(
      (LineFragment fragment) => fragment.tableColumn == 1,
    );
    expect(long.lines.length, greaterThan(1));
    final TextPosition next = _move(
      wide,
      TextPosition(offset: _startOf(wideFlow, long.lines.first) + 2),
      long.origin.dx + 20,
      VerticalMove.down,
    );
    final LocatedLine landed = CaretGeometry(
      flow: _activeFor(wide)(2, activeCell: 1),
    ).locate(next.offset, next.affinity);
    expect(landed.fragment.tableColumn, 1);
    expect(landed.line, isNot(landed.fragment.lines.first));
  });

  test('a line shorter than the goal gives its end', () {
    const String source =
        'A long line of plain words running well across\nShort';
    final LayoutInputs inputs = _inputs(source, activeLine: 0);
    expect(
      _move(
        inputs,
        const TextPosition(offset: 44),
        600,
        VerticalMove.down,
      ).offset,
      source.length,
    );
  });

  test('the goal holds when only the active line changes', () {
    final LayoutInputs before = _inputs(_floatFixture, activeLine: 1);
    final VerticalGoal goal = VerticalGoal.start(before, x: 250, position: 90);
    final LayoutInputs after = _inputs(_floatFixture, activeLine: 0);
    final List<double> seen = <double>[];
    moveVertically(
      inputs: after,
      caret: 90,
      affinity: TextAffinity.downstream,
      direction: VerticalMove.down,
      goal: goal,
      caretX: (int position, TextAffinity affinity) => 17,
      target:
          (
            int position,
            TextAffinity affinity,
            double goalX,
            VerticalMove direction,
          ) {
            seen.add(goalX);
            return TextPosition(offset: position);
          },
    );
    expect(seen, <double>[250]);
  });

  test('the goal compares media by entries and resets on a change', () {
    final LayoutInputs inputs = _inputs(_floatFixture, activeLine: 1);
    final VerticalGoal goal = VerticalGoal.start(inputs, x: 250, position: 90);
    expect(goal.holdsFor(inputs, 90), isTrue);
    expect(goal.holdsFor(inputs, 91), isFalse);
    expect(
      goal.holdsFor(
        _inputs(
          _floatFixture,
          activeLine: 1,
          mediaDimensions: <String, Size>{
            'a1b2c3d4e5f6': const Size(1600, 1200),
          },
        ),
        90,
      ),
      isFalse,
    );
    expect(
      goal.holdsFor(
        _inputs(
          _floatFixture,
          activeLine: 1,
          unavailableMedia: <String>{'a1b2c3d4e5f6'},
        ),
        90,
      ),
      isFalse,
    );
    final VerticalGoal twin = VerticalGoal.start(
      _inputs(
        _floatFixture,
        activeLine: 1,
        mediaDimensions: <String, Size>{'a1b2c3d4e5f6': const Size(1200, 800)},
        unavailableMedia: <String>{},
      ),
      x: 250,
      position: 90,
    );
    expect(twin, goal);
    expect(twin.hashCode, goal.hashCode);
    expect(VerticalGoal.start(inputs, x: 251, position: 90), isNot(goal));
  });

  test('up is symmetric with down', () {
    final LayoutInputs inputs = _inputs(_floatFixture, activeLine: 1);
    final NoteFlow flow = _flowOf(inputs);
    final List<LocatedLine> band = _bandLines(flow);
    final List<LocatedLine> full = _fullWidthLines(flow);
    final CaretGeometry geometry = CaretGeometry(flow: flow);
    TextPosition position = NoteHitTester(
      flow: flow,
    ).positionInLine(full[2].line, 380);
    for (final LocatedLine line in <LocatedLine>[
      full[1],
      full[0],
      band[8],
      band[7],
      band[6],
    ]) {
      position = _move(inputs, position, 380, VerticalMove.up);
      final LocatedLine reached = geometry.locate(
        position.offset,
        position.affinity,
      );
      expect(reached.line.top, closeTo(line.line.top, 0.01));
      final double caretX = geometry
          .caretRect(position.offset, position.affinity)
          .left;
      expect((caretX - 380).abs(), lessThanOrEqualTo(_advanceAt(reached, 380)));
    }
  });
}
