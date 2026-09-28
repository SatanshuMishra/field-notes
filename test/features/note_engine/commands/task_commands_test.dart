import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/commands/task_commands.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

EditorState _state(String source, NoteSelection selection) =>
    EditorState.create(source, parse: parseNoteTree, selection: selection);

EditorState _caret(String source, int offset) =>
    _state(source, NoteSelection.collapsed(offset));

Transaction _sure(Transaction? transaction) {
  expect(transaction, isNotNull);
  expect(transaction!.event, TransactionEvent.list);
  expect(transaction.addToHistory, isTrue);
  expect(transaction.composing, isNull);
  expect(transaction.time, Duration.zero);
  return transaction;
}

String _toggled(String source, int offset) {
  final EditorState state = _caret(source, source.length);
  final Transaction transaction = _sure(toggleTaskAt(state, offset));
  expect(transaction.selection, state.selection);
  return transaction.changes.apply(source);
}

void _expectLine(EditorState state, String source, int caret) {
  final Transaction transaction = _sure(toggleTaskOnCaretLine(state));
  expect(transaction.changes.apply(state.source), source);
  expect(transaction.selection, NoteSelection.collapsed(caret));
}

const String _photo = '![c](photo/0123456789abcdef)';

void main() {
  test(
    'toggling a checkbox changes only the character between the brackets',
    () {
      final EditorState state = _caret('- [ ] passport', 14);
      final Transaction checked = _sure(toggleTaskAt(state, 2));
      expect(checked.changes.apply(state.source), '- [x] passport');
      expect(
        checked.changes,
        ChangeSet(
          length: 14,
          replacements: const <TextReplacement>[TextReplacement(3, 4, 'x')],
        ),
      );
      expect(checked.selection, const NoteSelection.collapsed(14));

      final EditorState next = state.apply(checked);
      final Transaction unchecked = _sure(toggleTaskAt(next, 2));
      expect(unchecked.changes, ChangeSet.single(14, 3, 4, ' '));

      expect(_toggled('- [X] a', 2), '- [ ] a');
      expect(_toggled('1. [x] a', 3), '1. [ ] a');

      final EditorState crlf = _caret('a\r\n- [ ] b\r\n', 0);
      final Transaction line2 = _sure(toggleTaskAt(crlf, 3));
      expect(line2.changes, ChangeSet.single(12, 6, 7, 'x'));
    },
  );

  test('command l makes a plain line a task item', () {
    _expectLine(_caret('pack', 2), '- [ ] pack', 8);
    _expectLine(_caret('- pack', 6), '- [ ] pack', 10);
    _expectLine(_caret('- [ ] pack', 10), '- [x] pack', 10);
    _expectLine(_caret('1. pack', 7), '1. [ ] pack', 11);
  });

  test('toggling a line without a task item returns null', () {
    expect(toggleTaskAt(_caret('- a', 0), 1), isNull);
    expect(toggleTaskAt(_caret('plain', 0), 2), isNull);
    expect(toggleTaskAt(_caret('- a\n  - ', 0), 7), isNull);
  });

  test('a box holding a tab is unchecked', () {
    expect(_toggled('- [\t] a', 2), '- [x] a');
  });

  test('a nested task item toggles only its own box', () {
    final EditorState state = _caret('- a\n  - [ ] b', 0);
    final Transaction transaction = _sure(toggleTaskAt(state, 11));
    expect(transaction.changes, ChangeSet.single(13, 9, 10, 'x'));
  });

  test('user story two toggles the box and keeps the caret', () {
    final EditorState state = _caret('- [ ] passport\n  - [ ] tickets', 30);
    final Transaction transaction = _sure(toggleTaskAt(state, 2));
    expect(
      transaction.changes.apply(state.source),
      '- [x] passport\n  - [ ] tickets',
    );
    expect(transaction.selection, const NoteSelection.collapsed(30));
  });

  test('a range selection is kept across a toggle', () {
    const NoteSelection range = NoteSelection(anchor: 12, head: 7);
    final EditorState state = _state('- [ ] passport', range);
    expect(_sure(toggleTaskAt(state, 2)).selection, range);
    expect(_sure(toggleTaskOnCaretLine(state)).selection, range);
  });

  test('a task item inside a quote toggles', () {
    expect(_toggled('> - [ ] a', 4), '> - [x] a');
  });

  test('command l does not apply to headings, code, photos or lazy lines', () {
    expect(toggleTaskOnCaretLine(_caret('# a', 3)), isNull);
    expect(toggleTaskOnCaretLine(_caret('- a\n  - ', 8)), isNull);
    expect(toggleTaskOnCaretLine(_caret('1. a\nb', 6)), isNull);
    expect(toggleTaskOnCaretLine(_caret('```\ncode\n```', 6)), isNull);
    expect(toggleTaskOnCaretLine(_caret(_photo, 4)), isNull);
    expect(toggleTaskOnCaretLine(_caret('---', 1)), isNull);
    expect(toggleTaskOnCaretLine(_caret('| a |\n| - |', 2)), isNull);
  });

  test('command l completes a bare marker and an empty line', () {
    _expectLine(_caret('- a\n-', 5), '- a\n- [ ] ', 10);
    _expectLine(_caret('', 0), '- [ ] ', 6);
    _expectLine(_caret('a\n\nb', 2), 'a\n- [ ] \nb', 8);
    _expectLine(_caret('> a', 3), '> - [ ] a', 9);
  });

  test('command l with a two line range acts only on the head line', () {
    final EditorState state = _state(
      'one\ntwo',
      const NoteSelection(anchor: 1, head: 6),
    );
    final Transaction transaction = _sure(toggleTaskOnCaretLine(state));
    expect(transaction.changes.apply(state.source), 'one\n- [ ] two');
    expect(transaction.selection, const NoteSelection(anchor: 1, head: 12));
  });

  test('a crlf note keeps its line endings through command l', () {
    _expectLine(_caret('a\r\nb\r\nc', 3), 'a\r\n- [ ] b\r\nc', 9);
  });
}
