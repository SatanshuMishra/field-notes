import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/commands/inline_format.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

EditorState _caret(String source, int offset) => EditorState.create(
  source,
  parse: parseNoteTree,
  selection: NoteSelection.collapsed(offset),
);

void _expectCaretMove(String source, int from, InlineFormat format, int to) {
  final EditorState state = _caret(source, from);
  final Transaction? transaction = toggleInlineFormat(state, format);
  expect(transaction, isNotNull);
  expect(transaction!.changes.apply(source), source);
  expect(transaction.selection, NoteSelection.collapsed(to));
}

void main() {
  test(
    'bold at the end of a bold run moves the caret past its closing marker',
    () {
      _expectCaretMove('the **quick** fox', 11, InlineFormat.bold, 13);
    },
  );

  test('every inline format exits at the end of its run', () {
    _expectCaretMove('the *quick* fox', 10, InlineFormat.italic, 11);
    _expectCaretMove('the ~~quick~~ fox', 11, InlineFormat.strikethrough, 13);
    _expectCaretMove('the ==quick== fox', 11, InlineFormat.highlight, 13);
    _expectCaretMove('the `quick` fox', 10, InlineFormat.code, 11);
  });

  test('bold right after a closing marker re-enters the run', () {
    _expectCaretMove('the **quick** fox', 13, InlineFormat.bold, 11);
  });

  test('bold exits only a run of its own kind', () {
    _expectCaretMove('***both***', 7, InlineFormat.bold, 9);
  });
}
