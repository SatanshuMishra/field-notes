import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/commands/table_commands.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

EditorState _state(String source, NoteSelection selection) =>
    EditorState.create(source, parse: parseNoteTree, selection: selection);

EditorState _caret(String source, int offset) =>
    _state(source, NoteSelection.collapsed(offset));

EditorState _range(String source, int anchor, int head) =>
    _state(source, NoteSelection(anchor: anchor, head: head));

Transaction _sure(Transaction? transaction) {
  expect(transaction, isNotNull);
  expect(transaction!.composing, isNull);
  expect(transaction.time, Duration.zero);
  return transaction;
}

String _apply(EditorState state, Transaction? transaction) =>
    _sure(transaction).changes.apply(state.source);

void _expectMove(EditorState state, Transaction? transaction, int caret) {
  final Transaction move = _sure(transaction);
  expect(move.changes, ChangeSet.empty(state.source.length));
  expect(move.selection, NoteSelection.collapsed(caret));
  expect(move.event, TransactionEvent.table);
  expect(move.addToHistory, isFalse);
}

void _expectNoOp(EditorState state, Transaction? transaction) {
  final Transaction noOp = _sure(transaction);
  expect(noOp.changes, ChangeSet.empty(state.source.length));
  expect(noOp.selection, state.selection);
  expect(noOp.addToHistory, isFalse);
}

void _expectEdit(EditorState state, TableEdit edit, String source, int caret) {
  final Transaction transaction = _sure(editTable(state, edit));
  expect(transaction.changes.apply(state.source), source);
  expect(transaction.selection, NoteSelection.collapsed(caret));
  expect(transaction.event, TransactionEvent.table);
  expect(transaction.addToHistory, isTrue);
}

List<int> _rowWidths(String source) {
  final MdBlock table = parseNoteTree(source).blocks.single;
  expect(table.kind, MdBlockKind.table);
  return <int>[for (final MdBlock row in table.blocks) row.blocks.length];
}

const String _t = '| a | b |\n| --- | --- |\n| c | d |';
const String _empty = '|  |  |  |\n| --- | --- | --- |\n|  |  |  |';

void main() {
  test('typing in a cell changes only that cell', () {
    final EditorState state = _caret(_t, 27);
    final Transaction typed = _sure(replaceInCell(state, 'x'));
    expect(typed.changes.apply(_t), '| a | b |\n| --- | --- |\n| cx | d |');
    expect(typed.changes, ChangeSet.single(_t.length, 27, 27, 'x'));
    expect(typed.selection, const NoteSelection.collapsed(28));
    expect(typed.event, TransactionEvent.inputType);

    const String blank = '|  |  |\n| --- | --- |';
    final EditorState empty = _caret(blank, 2);
    final Transaction day = _sure(replaceInCell(empty, 'Day'));
    expect(day.changes.apply(blank), '| Day |  |\n| --- | --- |');
    expect(day.changes, ChangeSet.single(blank.length, 2, 2, 'Day'));
  });

  test('a typed pipe is escaped and pasted line breaks become spaces', () {
    final EditorState selected = _range(_t, 26, 27);
    final Transaction pipe = _sure(replaceInCell(selected, 'a|b'));
    final List<String> rows = pipe.changes.apply(_t).split('\n');
    expect(rows[2], r'| a\|b | d |');
    expect(rows.take(2).join('\n'), _t.split('\n').take(2).join('\n'));
    expect(pipe.changes, ChangeSet.single(_t.length, 26, 27, r'a\|b'));

    final EditorState caret = _caret(_t, 27);
    final Transaction pasted = _sure(
      replaceInCell(caret, 'x\ny\r\nz', paste: true),
    );
    expect(pasted.changes.apply(_t).split('\n')[2], '| cx y z | d |');
    expect(pasted.event, TransactionEvent.inputPaste);
  });

  test('the table button inserts a three by two table', () {
    final EditorState empty = _caret('', 0);
    final Transaction first = _sure(insertTable(empty));
    expect(first.changes.apply(''), _empty);
    expect(first.selection, const NoteSelection.collapsed(2));
    expect(first.event, TransactionEvent.table);
    expect(first.addToHistory, isTrue);

    final EditorState between = _caret('A\n\nB', 0);
    final Transaction second = _sure(insertTable(between));
    expect(second.changes.apply('A\n\nB'), 'A\n$_empty\n\nB');
    expect(second.selection, const NoteSelection.collapsed(4));

    final EditorState heading = _caret('# H\nB', 1);
    final Transaction third = _sure(insertTable(heading));
    expect(third.changes.apply('# H\nB'), '# H\n$_empty\n\nB');
    expect(third.selection, const NoteSelection.collapsed(6));
  });

  test('alignment writes the gfm delimiter forms', () {
    const String source = '| a | b |\n| --- | --- |';
    EditorState state = _caret(source, 3);
    final Transaction centre = _sure(editTable(state, TableEdit.alignCentre));
    expect(centre.changes.apply(source), '| a | b |\n| :---: | --- |');
    expect(centre.changes.replacements, hasLength(1));
    expect(centre.changes.replacements.single.from, 10);
    state = _caret(centre.changes.apply(source), 7);
    final String right = _apply(state, editTable(state, TableEdit.alignRight));
    expect(right, '| a | b |\n| :---: | ---: |');
    state = _caret(right, 3);
    final String left = _apply(state, editTable(state, TableEdit.alignLeft));
    expect(left, '| a | b |\n| :--- | ---: |');
    expect(editTable(_caret(left, 3), TableEdit.alignLeft), isNull);
  });

  test('column right adds a cell to every row and the delimiter row', () {
    _expectEdit(
      _caret('| a | b |\n| --- | --- |\n| c | d |\n| e | f |', 3),
      TableEdit.columnRight,
      '| a |  | b |\n| --- | --- | --- |\n| c |  | d |\n| e |  | f |',
      6,
    );
    _expectEdit(
      _caret('| a | b |\n| --- | --- |\n| c | d |', 27),
      TableEdit.columnLeft,
      '|  | a | b |\n| --- | --- | --- |\n|  | c | d |',
      35,
    );
  });

  test('a new column keeps the alignment of the others', () {
    final EditorState state = _caret('| a | b |\n| :---: | ---: |', 3);
    final String result = _apply(
      state,
      editTable(state, TableEdit.columnRight),
    );
    expect(result, '| a |  | b |\n| :---: | --- | ---: |');
  });

  test('rows are added below and above', () {
    _expectEdit(_caret(_t, 27), TableEdit.rowBelow, '$_t\n|  |  |', 36);
    _expectEdit(
      _caret(_t, 31),
      TableEdit.rowAbove,
      '| a | b |\n| --- | --- |\n|  |  |\n| c | d |',
      29,
    );
    _expectEdit(
      _caret(_t, 3),
      TableEdit.rowBelow,
      '| a | b |\n| --- | --- |\n|  |  |\n| c | d |',
      26,
    );
    expect(editTable(_caret(_t, 3), TableEdit.rowAbove), isNull);
  });

  test('delete row moves the caret to a neighbouring row', () {
    const String three = '| a | b |\n| --- | --- |\n| c | d |\n| e | f |';
    _expectEdit(
      _caret(three, 36),
      TableEdit.deleteRow,
      '| a | b |\n| --- | --- |\n| c | d |',
      27,
    );
    _expectEdit(
      _caret(three, 27),
      TableEdit.deleteRow,
      '| a | b |\n| --- | --- |\n| e | f |',
      27,
    );
    _expectEdit(
      _caret(_t, 31),
      TableEdit.deleteRow,
      '| a | b |\n| --- | --- |',
      7,
    );
    expect(editTable(_caret(_t, 3), TableEdit.deleteRow), isNull);
  });

  test('delete column rewrites every row without it', () {
    _expectEdit(
      _caret(_t, 27),
      TableEdit.deleteColumn,
      '| b |\n| --- |\n| d |',
      17,
    );
    _expectEdit(
      _caret(_t, 31),
      TableEdit.deleteColumn,
      '| a |\n| --- |\n| c |',
      17,
    );
    expect(
      editTable(_caret('| a |\n| --- |\n| c |', 3), TableEdit.deleteColumn),
      isNull,
    );
  });

  test('delete table removes one separator', () {
    const String source = 'A\n\n| a |\n| --- |\n\nB';
    _expectEdit(_caret(source, 5), TableEdit.deleteTable, 'A\n\nB', 3);
    _expectEdit(
      _caret('| a |\n| --- |\n\nB', 2),
      TableEdit.deleteTable,
      'B',
      0,
    );
    _expectEdit(
      _caret('A\n\n| a |\n| --- |', 5),
      TableEdit.deleteTable,
      'A',
      1,
    );
    _expectEdit(_caret('| a |\n| --- |', 12), TableEdit.deleteTable, '', 0);
  });

  test('tab walks every cell and appends a row after the last', () {
    final EditorState state = _caret(_t, 3);
    _expectMove(state, nextCell(state), 7);
    _expectMove(_caret(_t, 7), nextCell(_caret(_t, 7)), 27);
    _expectMove(_caret(_t, 27), nextCell(_caret(_t, 27)), 31);
    const String header = '| a | b |\n| --- | --- |';
    final EditorState last = _caret(header, 7);
    final Transaction added = _sure(nextCell(last));
    expect(added.changes.apply(header), '$header\n|  |  |');
    expect(added.selection, const NoteSelection.collapsed(26));
    expect(added.event, TransactionEvent.table);
    expect(added.addToHistory, isTrue);
  });

  test('shift tab moves back and stops in the first header cell', () {
    _expectMove(_caret(_t, 27), previousCell(_caret(_t, 27)), 7);
    _expectMove(_caret(_t, 7), previousCell(_caret(_t, 7)), 3);
    _expectNoOp(_caret(_t, 3), previousCell(_caret(_t, 3)));
  });

  test('enter moves down a column and adds a row after the last', () {
    _expectMove(_caret(_t, 7), cellBelow(_caret(_t, 7)), 31);
    final EditorState last = _caret(_t, 31);
    final Transaction added = _sure(cellBelow(last));
    expect(added.changes.apply(_t), '$_t\n|  |  |');
    expect(added.selection, const NoteSelection.collapsed(39));
    expect(added.addToHistory, isTrue);
  });

  test('deleting at a cell edge never takes a separator', () {
    _expectNoOp(_caret(_t, 26), deleteInCell(_caret(_t, 26), forward: false));
    _expectNoOp(_caret(_t, 27), deleteInCell(_caret(_t, 27), forward: true));
    const String escaped = '| a\\|b |\n| --- |';
    final EditorState state = _caret(escaped, 5);
    final Transaction deleted = _sure(deleteInCell(state, forward: false));
    expect(deleted.changes.apply(escaped), '| ab |\n| --- |');
    expect(deleted.selection, const NoteSelection.collapsed(3));
    expect(deleted.event, TransactionEvent.inputDelete);
    final Transaction forward = _sure(
      deleteInCell(_caret(escaped, 3), forward: true),
    );
    expect(forward.changes.apply(escaped), '| ab |\n| --- |');
    final Transaction plain = _sure(
      deleteInCell(_caret(_t, 27), forward: false),
    );
    expect(plain.changes.apply(_t), '| a | b |\n| --- | --- |\n|  | d |');
  });

  test('a selection across cells empties them without writing separators', () {
    final EditorState state = _range(_t, 2, 31);
    final String result = _apply(state, replaceInCell(state, 'z'));
    expect(result, '| z |  |\n| --- | --- |\n|  |  |');
  });

  test('typing on a pipe or in padding does not apply', () {
    expect(replaceInCell(_caret(_t, 4), 'x'), isNull);
    expect(replaceInCell(_caret(_t, 0), 'x'), isNull);
    expect(replaceInCell(_caret(_t, 15), 'x'), isNull);
    expect(replaceInCell(_caret('plain', 2), 'x'), isNull);
  });

  test('typing into a hand aligned table changes only that cell', () {
    const String source = '|  a  |  b |\n|:-|-:|';
    final EditorState state = _caret(source, 4);
    final Transaction typed = _sure(replaceInCell(state, 'x'));
    expect(typed.changes.apply(source), '|  ax  |  b |\n|:-|-:|');
    expect(typed.changes, ChangeSet.single(source.length, 4, 4, 'x'));
  });

  test('tab into a missing cell pads the short row', () {
    const String source = '| a | b |\n| - | - |\n| c |';
    final EditorState state = _caret(source, 23);
    final Transaction padded = _sure(nextCell(state));
    expect(padded.changes.apply(source), '| a | b |\n| - | - |\n| c |  |');
    expect(padded.selection, const NoteSelection.collapsed(26));
    expect(padded.event, TransactionEvent.table);
    expect(padded.addToHistory, isTrue);
  });

  test('a short row gains cells without repadding the cells it has', () {
    const String padded = '| a | b |\n| - | - |\n|   c   |';
    final Transaction tab = _sure(nextCell(_caret(padded, 25)));
    expect(tab.changes, ChangeSet.single(padded.length, 29, 29, '  |'));
    expect(tab.changes.apply(padded), '| a | b |\n| - | - |\n|   c   |  |');
    expect(tab.selection, const NoteSelection.collapsed(30));
    expect(tab.event, TransactionEvent.table);
    expect(tab.addToHistory, isTrue);

    const String wide = '| a | b | c |\n| - | - | - |\n| d |';
    final Transaction below = _sure(cellBelow(_caret(wide, 11)));
    expect(below.changes, ChangeSet.single(wide.length, 33, 33, '  |  |'));
    expect(below.selection, const NoteSelection.collapsed(37));

    const String open = '| a | b |\n| - | - |\n| c';
    final Transaction closed = _sure(nextCell(_caret(open, 23)));
    expect(closed.changes.apply(open), '| a | b |\n| - | - |\n| c|  |');
    expect(closed.selection, const NoteSelection.collapsed(25));
    expect(_rowWidths(closed.changes.apply(open)), <int>[2, 2]);

    const String slash = '| a | b |\n| - | - |\n| c\\';
    final Transaction guarded = _sure(nextCell(_caret(slash, 24)));
    expect(guarded.changes.apply(slash), '| a | b |\n| - | - |\n| c\\ |  |');
    expect(guarded.selection, const NoteSelection.collapsed(27));
    expect(_rowWidths(guarded.changes.apply(slash)), <int>[2, 2]);
  });

  test('a backslash left against a closing pipe gains a padding space', () {
    const String bare = '|a|b|\n|-|-|';
    final Transaction typed = _sure(replaceInCell(_caret(bare, 2), r'\'));
    expect(typed.changes, ChangeSet.single(bare.length, 2, 2, r'\ '));
    expect(typed.changes.apply(bare), '|a\\ |b|\n|-|-|');
    expect(typed.selection, const NoteSelection.collapsed(3));
    expect(_rowWidths(typed.changes.apply(bare)), <int>[2]);

    const String escaping = '|\\x|y|\n|-|-|';
    final Transaction backward = _sure(
      deleteInCell(_caret(escaping, 3), forward: false),
    );
    expect(backward.changes.apply(escaping), '|\\ |y|\n|-|-|');
    expect(backward.selection, const NoteSelection.collapsed(2));
    expect(_rowWidths(backward.changes.apply(escaping)), <int>[2]);

    final Transaction forward = _sure(
      deleteInCell(_caret(escaping, 2), forward: true),
    );
    expect(forward.changes.apply(escaping), '|\\ |y|\n|-|-|');
    expect(forward.selection, const NoteSelection.collapsed(2));

    const String spanning = '|a\\b|c|\n|-|-|';
    final Transaction across = _sure(
      deleteInCell(_range(spanning, 3, 6), forward: false),
    );
    expect(across.changes.apply(spanning), '|a\\ ||\n|-|-|');
    expect(across.selection, const NoteSelection.collapsed(3));
    expect(_rowWidths(across.changes.apply(spanning)), <int>[2]);

    const String emptyCell = '||b|\n|-|-|';
    final Transaction intoEmpty = _sure(
      replaceInCell(_caret(emptyCell, 1), r'x\'),
    );
    expect(intoEmpty.changes.apply(emptyCell), '|x\\ |b|\n|-|-|');
    expect(intoEmpty.selection, const NoteSelection.collapsed(3));
  });

  test('user story three fills a new table', () {
    EditorState state = _caret('', 0);
    state = state.apply(_sure(insertTable(state)));
    final List<Transaction? Function(EditorState)> steps =
        <Transaction? Function(EditorState)>[
          (EditorState s) => replaceInCell(s, 'Day'),
          nextCell,
          (EditorState s) => replaceInCell(s, 'Route'),
          nextCell,
          (EditorState s) => replaceInCell(s, 'Notes'),
          nextCell,
          (EditorState s) => replaceInCell(s, 'Mon'),
          nextCell,
          (EditorState s) => replaceInCell(s, 'Coast | ridge'),
        ];
    for (final Transaction? Function(EditorState) step in steps) {
      state = state.apply(_sure(step(state)));
    }
    expect(
      state.source,
      '| Day | Route | Notes |\n| --- | --- | --- |\n'
      r'| Mon | Coast \| ridge |  |',
    );
  });

  test('insert table on an empty line matches the caret in the line above', () {
    final EditorState empty = _caret('A\n\nB', 2);
    final Transaction transaction = _sure(insertTable(empty));
    expect(transaction.changes.apply('A\n\nB'), 'A\n$_empty\n\nB');
    expect(transaction.selection, const NoteSelection.collapsed(4));
  });

  test('insert table writes crlf line breaks in a crlf note', () {
    const String source = 'A\r\n\r\nB';
    final EditorState state = _caret(source, 0);
    final String result = _apply(state, insertTable(state));
    expect(result, 'A\r\n${_empty.replaceAll('\n', '\r\n')}\r\n\r\nB');
    expect(result.replaceAll('\r\n', ''), isNot(contains('\n')));
  });

  test('insert table after a list leaves a blank line before the header', () {
    final EditorState state = _caret('- a', 1);
    final Transaction transaction = _sure(insertTable(state));
    expect(transaction.changes.apply('- a'), '- a\n\n$_empty');
    expect(transaction.selection, const NoteSelection.collapsed(7));
  });

  test('insert table never lands inside an unclosed fence', () {
    const String fenced = 'A\n\n```\ncode';
    final EditorState state = _caret(fenced, 9);
    final Transaction transaction = _sure(insertTable(state));
    expect(transaction.changes.apply(fenced), 'A\n$_empty\n\n```\ncode');
    expect(transaction.selection, const NoteSelection.collapsed(4));

    const String alone = '```\ncode';
    final EditorState first = _caret(alone, 5);
    final Transaction atStart = _sure(insertTable(first));
    expect(atStart.changes.apply(alone), '$_empty\n\n```\ncode');
    expect(atStart.selection, const NoteSelection.collapsed(2));
  });

  test('a twenty column table takes column right', () {
    final String header = '|${' h |' * 20}';
    final String delimiter = '|${' --- |' * 20}';
    final String source = '$header\n$delimiter';
    final EditorState state = _caret(source, 2);
    final String result = _apply(
      state,
      editTable(state, TableEdit.columnRight),
    );
    expect(
      MdTables.splitRow(result, MdRange(0, result.indexOf('\n'))),
      hasLength(21),
    );
  });

  test('every command but insert table returns null with tables off', () {
    final EditorState state = EditorState.create(
      _t,
      parse: (String source) => parseNoteTree(source, tables: false),
      selection: const NoteSelection.collapsed(27),
    );
    expect(replaceInCell(state, 'x'), isNull);
    expect(deleteInCell(state, forward: false), isNull);
    expect(nextCell(state), isNull);
    expect(previousCell(state), isNull);
    expect(cellBelow(state), isNull);
    for (final TableEdit edit in TableEdit.values) {
      expect(editTable(state, edit), isNull);
    }
  });

  test('the delimiter row is in no cell', () {
    final EditorState state = _caret(_t, 15);
    expect(nextCell(state), isNull);
    expect(editTable(state, TableEdit.columnRight), isNull);
    expect(editTable(state, TableEdit.deleteTable), isNotNull);
  });
}
