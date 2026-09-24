import 'dart:math';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/projection/active_line.dart';
import 'package:flutter_test/flutter_test.dart';

const String _note = '# Title\nThe **fog** lifted\n';
const String _table = '| a | b |\n| - | - |\n| c | d |\n\nafter';

ActiveLine _at(String source, int head, {int? anchor, bool tables = true}) =>
    activeLineAt(
      source,
      parseNoteTree(source, tables: tables),
      NoteSelection(anchor: anchor ?? head, head: head),
    );

ActiveLine? _next(
  String source,
  int head, {
  required ActiveLine? previous,
  bool focused = true,
  bool composing = false,
  bool dragging = false,
}) => nextActiveLine(
  previous: previous,
  source: source,
  tree: parseNoteTree(source),
  selection: NoteSelection.collapsed(head),
  focused: focused,
  composing: composing,
  dragging: dragging,
);

void main() {
  test('the active line is the line of the selection head', () {
    expect(_note.length, 27);
    final List<int> heads = <int>[0, 7, 8, 26, 27];
    final List<int> lines = <int>[0, 0, 1, 1, 2];
    for (int i = 0; i < heads.length; i++) {
      expect(_at(_note, heads[i]), ActiveLine(line: lines[i]));
    }
    expect(_at(_note, 20, anchor: 0), const ActiveLine(line: 1));
    expect(_at(_note, 3, anchor: 20), const ActiveLine(line: 0));
    expect(_at('a\r\nb', 1), const ActiveLine(line: 0));
    expect(_at('a\r\nb', 2), const ActiveLine(line: 0));
    expect(_at('a\r\nb', 3), const ActiveLine(line: 1));
    expect(_at('a\rb', 3), const ActiveLine(line: 0));
    expect(_at(_note, 20).cell, isNull);
  });

  test('an unfocused editor has no active line', () {
    expect(
      _next(_note, 8, previous: const ActiveLine(line: 1), focused: false),
      isNull,
    );
    expect(_next(_note, 8, previous: null), const ActiveLine(line: 1));
  });

  test('the active line is frozen while composing and during a drag', () {
    expect(
      _next(_note, 10, previous: const ActiveLine(line: 0), composing: true),
      const ActiveLine(line: 0),
    );
    expect(
      _next(_note, 10, previous: const ActiveLine(line: 0)),
      const ActiveLine(line: 1),
    );
    expect(
      _next(_note, 3, previous: const ActiveLine(line: 1), dragging: true),
      const ActiveLine(line: 1),
    );
    expect(
      _next(_note, 3, previous: const ActiveLine(line: 1)),
      const ActiveLine(line: 0),
    );
    expect(_next(_note, 3, previous: null, dragging: true), isNull);
    expect(
      _next(
        _table,
        22,
        previous: const ActiveLine(line: 2, cell: 1),
        composing: true,
      ),
      const ActiveLine(line: 2, cell: 1),
    );
  });

  test('inside a table the active cell plays the active line', () {
    final List<int> heads = <int>[2, 6, 4, 5, 0, 9];
    final List<int> cells = <int>[0, 1, 0, 1, 0, 1];
    for (int i = 0; i < heads.length; i++) {
      expect(_at(_table, heads[i]), ActiveLine(line: 0, cell: cells[i]));
    }
    expect(_at(_table, 12), const ActiveLine(line: 1));
    expect(_at(_table, 22), const ActiveLine(line: 2, cell: 0));
    expect(_at(_table, 26), const ActiveLine(line: 2, cell: 1));
    expect(_at(_table, 30), const ActiveLine(line: 3));
    expect(_at(_table, 31), const ActiveLine(line: 4));
  });

  test('an escaped pipe is cell content', () {
    const String source =
        r'| a \| b | c |'
        '\n| - | - |';
    expect(_at(source, 6).cell, 0);
    expect(_at(source, 10).cell, 1);
  });

  test('a head in an excess cell belongs to the last cell node', () {
    expect(
      _at('| a |\n| - |\n| b | c |', 18),
      const ActiveLine(line: 2, cell: 0),
    );
  });

  test('a table inside a quote has no active cell', () {
    expect(_at('> | a | b |\n> | - | - |', 4).cell, isNull);
  });

  test('a note parsed without tables has no active cell', () {
    expect(_at(_table, 22, tables: false), const ActiveLine(line: 2));
  });

  test('an empty source has line 0 active', () {
    expect(_at('', 0), const ActiveLine(line: 0));
  });

  test('active lines are equal by value', () {
    expect(const ActiveLine(line: 2, cell: 1), ActiveLine(line: 2, cell: 1));
    expect(
      const ActiveLine(line: 2, cell: 1).hashCode,
      ActiveLine(line: 2, cell: 1).hashCode,
    );
    expect(
      const ActiveLine(line: 2),
      isNot(const ActiveLine(line: 2, cell: 0)),
    );
    expect(const ActiveLine(line: 2), isNot(const ActiveLine(line: 3)));
    expect(const ActiveLine(line: 2, cell: 1).toString(), contains('2'));
  });

  test('nextActiveLine gives equal results for equal inputs', () {
    final Random random = Random(20260923);
    const List<String> sources = <String>[_note, _table, 'a\r\nb', ''];
    for (int i = 0; i < 200; i++) {
      final String source = sources[random.nextInt(sources.length)];
      final int head = random.nextInt(source.length + 1);
      final ActiveLine? previous = random.nextBool()
          ? null
          : ActiveLine(line: random.nextInt(4), cell: random.nextInt(2));
      final bool focused = random.nextBool();
      final bool composing = random.nextBool();
      final bool dragging = random.nextBool();
      ActiveLine? run() => _next(
        source,
        head,
        previous: previous,
        focused: focused,
        composing: composing,
        dragging: dragging,
      );
      expect(run(), run());
    }
  });

  test('a head beyond the source or a tree of another length throws', () {
    expect(
      () => activeLineAt(
        'ab',
        parseNoteTree('ab'),
        const NoteSelection.collapsed(3),
      ),
      throwsArgumentError,
    );
    expect(
      () => activeLineAt(
        'ab',
        parseNoteTree('abc'),
        const NoteSelection.collapsed(1),
      ),
      throwsArgumentError,
    );
    expect(
      () => nextActiveLine(
        previous: null,
        source: 'ab',
        tree: parseNoteTree('abc'),
        selection: const NoteSelection.collapsed(1),
        focused: true,
        composing: false,
        dragging: false,
      ),
      throwsArgumentError,
    );
  });
}
