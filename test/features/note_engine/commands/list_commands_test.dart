import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/commands/list_commands.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Command = Transaction? Function(EditorState state);

EditorState _state(String source, NoteSelection selection) =>
    EditorState.create(source, parse: parseNoteTree, selection: selection);

EditorState _caret(String source, int offset) =>
    _state(source, NoteSelection.collapsed(offset));

Transaction _sure(Transaction? transaction) {
  expect(transaction, isNotNull);
  expect(transaction!.composing, isNull);
  expect(transaction.time, Duration.zero);
  return transaction;
}

EditorState _press(
  EditorState state,
  _Command command,
  String source,
  int caret, {
  TransactionEvent event = TransactionEvent.list,
}) {
  final Transaction transaction = _sure(command(state));
  expect(transaction.changes.apply(state.source), source);
  expect(transaction.selection, NoteSelection.collapsed(caret));
  expect(transaction.event, event);
  expect(transaction.addToHistory, isTrue);
  return state.apply(transaction);
}

void _expectNoOp(EditorState state, _Command command) {
  final Transaction transaction = _sure(command(state));
  expect(transaction.changes, ChangeSet.empty(state.source.length));
  expect(transaction.selection, state.selection);
  expect(transaction.addToHistory, isFalse);
}

const String _photo = '![c](photo/0123456789abcdef)';

void main() {
  test(
    'enter continues an ordered item with the displayed number plus one',
    () {
      _press(
        _caret('- first\n  1. second', 19),
        continueOnEnter,
        '- first\n  1. second\n  2. ',
        25,
      );
      _press(_caret('1. a\n1. b', 9), continueOnEnter, '1. a\n1. b\n3. ', 13);
      _press(_caret('3) x', 4), continueOnEnter, '3) x\n4) ', 8);
    },
  );

  test('enter on an empty item outdents or ends the list', () {
    final EditorState outdented = _press(
      _caret('- a\n  - b\n  - ', 14),
      continueOnEnter,
      '- a\n  - b\n- ',
      12,
    );
    _press(outdented, continueOnEnter, '- a\n  - b\n', 10);

    EditorState chain = _caret('- a', 3);
    chain = _press(chain, continueOnEnter, '- a\n- ', 6);
    chain = _press(chain, indentListItem, '- a\n  - ', 8);
    chain = _press(chain, continueOnEnter, '- a\n- ', 6);
    _press(chain, continueOnEnter, '- a\n', 4);
  });

  test('tab nests an ordered item as a new list numbered one', () {
    _press(_caret('1. a\n2. b', 9), indentListItem, '1. a\n   1. b', 12);
    _press(_caret('- a\n- b', 7), indentListItem, '- a\n  - b', 9);
    _expectNoOp(_caret('- a\n- b', 3), indentListItem);
    _press(
      _caret('1. a\n   1. x\n2. b', 17),
      indentListItem,
      '1. a\n   1. x\n   2. b',
      20,
    );
  });

  test('backspace at the start of an item outdents or removes its marker', () {
    final EditorState outdented = _press(
      _caret('- a\n  - b', 8),
      backspaceAtItemStart,
      '- a\n- b',
      6,
    );
    _press(outdented, backspaceAtItemStart, '- a\nb', 4);
    _press(_caret('> q', 2), backspaceAtItemStart, 'q', 0);
    expect(backspaceAtItemStart(_caret('- a', 3)), isNull);
    _press(_caret('- a\n  - ', 8), backspaceAtItemStart, '- a\n- ', 6);
  });

  test('enter continues task items with the same marker', () {
    _press(_caret('* [x] a', 7), continueOnEnter, '* [x] a\n* [ ] ', 14);
    _press(_caret('3. [ ] a', 8), continueOnEnter, '3. [ ] a\n4. [ ] ', 16);
  });

  test('enter inside an item splits it and replaces a range', () {
    _press(_caret('- milk', 4), continueOnEnter, '- mi\n- lk', 7);
    final EditorState range = _state(
      '- milk',
      const NoteSelection(anchor: 3, head: 5),
    );
    final Transaction transaction = _sure(continueOnEnter(range));
    expect(transaction.changes.apply('- milk'), '- m\n- k');
    expect(transaction.changes, ChangeSet.single(6, 3, 5, '\n- '));
    expect(continueOnEnter(_caret('- a', 1)), isNull);
    expect(continueOnEnter(_caret('plain', 5)), isNull);
  });

  test('enter continues and ends quotes', () {
    _press(_caret('> a', 3), continueOnEnter, '> a\n> ', 6);
    _press(_caret('> a\n> ', 6), continueOnEnter, '> a\n', 4);
    _press(_caret('> - a', 5), continueOnEnter, '> - a\n> - ', 10);
  });

  test('enter in a fenced block keeps the leading whitespace', () {
    _press(
      _caret('```\n  let x\n```', 11),
      continueOnEnter,
      '```\n  let x\n  \n```',
      14,
      event: TransactionEvent.inputType,
    );
    _press(
      _caret('- a\n  ```\n  x', 13),
      continueOnEnter,
      '- a\n  ```\n  x\n  ',
      16,
      event: TransactionEvent.inputType,
    );
    _press(
      _caret('```\ncode', 8),
      continueOnEnter,
      '```\ncode\n',
      9,
      event: TransactionEvent.inputType,
    );
  });

  test('shift enter indents to the content column without a marker', () {
    _press(
      _caret('- a', 3),
      insertLineBreakWithoutContinuation,
      '- a\n  ',
      6,
      event: TransactionEvent.inputType,
    );
    _press(
      _caret('1. a', 4),
      insertLineBreakWithoutContinuation,
      '1. a\n   ',
      8,
      event: TransactionEvent.inputType,
    );
    _press(
      _caret('plain', 5),
      insertLineBreakWithoutContinuation,
      'plain\n',
      6,
      event: TransactionEvent.inputType,
    );
    _press(
      _caret('> a', 3),
      insertLineBreakWithoutContinuation,
      '> a\n',
      4,
      event: TransactionEvent.inputType,
    );
    expect(insertLineBreakWithoutContinuation(_caret(_photo, 3)), isNull);
  });

  test('shift tab outdents nested items and marker only lines', () {
    _press(_caret('- a\n  - b', 9), outdentListItem, '- a\n- b', 7);
    _expectNoOp(_caret('- a\n- b', 7), outdentListItem);
    _press(_caret('- a\n  - ', 8), outdentListItem, '- a\n- ', 6);
    _expectNoOp(_caret('- a\n  - ', 8), indentListItem);
    expect(outdentListItem(_caret('plain', 2)), isNull);
    expect(indentListItem(_caret('plain', 2)), isNull);
  });

  test('a marker only line at the top level ends like an empty item', () {
    _press(_caret('para\n- ', 7), continueOnEnter, 'para\n', 5);
    _press(_caret('para\n- ', 7), backspaceAtItemStart, 'para\n', 5);
  });

  test('an empty task item at the top level ends the list', () {
    _press(_caret('- [ ] a\n- [ ] ', 14), continueOnEnter, '- [ ] a\n', 8);
  });

  test('tab carries nested children', () {
    _press(
      _caret('- a\n- b\n  - c', 7),
      indentListItem,
      '- a\n  - b\n    - c',
      9,
    );
  });

  test('a crlf list keeps its line endings', () {
    _press(_caret('- a\r\n- b', 8), continueOnEnter, '- a\r\n- b\n- ', 11);
  });

  test('tab under a bullet sibling list starts an ordered list at one', () {
    _press(
      _caret('1. a\n   - x\n2. b', 16),
      indentListItem,
      '1. a\n   - x\n   1. b',
      19,
    );
  });

  test('user story two nests a task item by the marker width', () {
    EditorState state = _caret('- [ ] passport', 14);
    state = _press(state, continueOnEnter, '- [ ] passport\n- [ ] ', 21);
    state = state.apply(
      Transaction(
        changes: ChangeSet.single(state.source.length, 21, 21, 'tickets'),
        selection: const NoteSelection.collapsed(28),
        event: TransactionEvent.inputType,
      ),
    );
    _press(state, indentListItem, '- [ ] passport\n  - [ ] tickets', 30);
  });

  test('tab moves every item whose first line the selection touches', () {
    final EditorState state = _state(
      '- a\n- b\n- c\n- d',
      const NoteSelection(anchor: 5, head: 9),
    );
    final Transaction transaction = _sure(indentListItem(state));
    expect(transaction.changes.apply(state.source), '- a\n  - b\n  - c\n- d');
  });

  test('a photo line under the caret returns null from every command', () {
    final EditorState state = _caret('a\n$_photo', 5);
    expect(continueOnEnter(state), isNull);
    expect(insertLineBreakWithoutContinuation(state), isNull);
    expect(indentListItem(state), isNull);
    expect(outdentListItem(state), isNull);
    expect(backspaceAtItemStart(state), isNull);
  });

  test('ten nested levels keep their structure through tab and shift tab', () {
    final StringBuffer buffer = StringBuffer('- l0');
    for (int level = 1; level < 10; level++) {
      buffer.write('\n${'  ' * level}- l$level');
    }
    final String source = '$buffer\n- tail';
    final EditorState state = _caret(source, source.length);
    final EditorState nested = state.apply(_sure(indentListItem(state)));
    expect(nested.source, '$buffer\n  - tail');
    final EditorState back = nested.apply(_sure(outdentListItem(nested)));
    expect(back.source, source);
  });
}
