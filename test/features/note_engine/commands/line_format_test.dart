import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/commands/line_format.dart';
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

EditorState _all(String source) => _range(source, 0, source.length);

Transaction _sure(Transaction? transaction) {
  expect(transaction, isNotNull);
  expect(transaction!.addToHistory, isTrue);
  expect(transaction.composing, isNull);
  expect(transaction.time, Duration.zero);
  return transaction;
}

String _heading(EditorState state) =>
    _sure(cycleHeading(state)).changes.apply(state.source);

String _list(EditorState state, NoteListKind kind) =>
    _sure(toggleList(state, kind)).changes.apply(state.source);

String _quote(EditorState state) =>
    _sure(toggleQuote(state)).changes.apply(state.source);

const String _photo = '![c](photo/0123456789abcdef)';

void main() {
  test('the heading button cycles plain, h1, h2, h3, plain', () {
    EditorState state = _caret('Harbour', 3);
    final List<(String, int)> expected = <(String, int)>[
      ('# Harbour', 5),
      ('## Harbour', 6),
      ('### Harbour', 7),
      ('Harbour', 3),
    ];
    for (final (String source, int caret) in expected) {
      final Transaction transaction = _sure(cycleHeading(state));
      expect(transaction.event, TransactionEvent.format);
      expect(transaction.changes.replacements, hasLength(1));
      state = state.apply(transaction);
      expect(state.source, source);
      expect(state.selection, NoteSelection.collapsed(caret));
    }

    final EditorState deep = _caret('#### Harbour', 8);
    final Transaction plain = _sure(cycleHeading(deep));
    expect(plain.changes.apply(deep.source), 'Harbour');
    expect(plain.selection, const NoteSelection.collapsed(3));
    expect(_heading(_caret('###### x', 7)), 'x');
  });

  test('list toggles switch between list kinds', () {
    EditorState state = _all('- a\n- b');
    final List<(NoteListKind, String)> steps = <(NoteListKind, String)>[
      (NoteListKind.numbered, '1. a\n2. b'),
      (NoteListKind.task, '- [ ] a\n- [ ] b'),
      (NoteListKind.bullet, '- a\n- b'),
      (NoteListKind.bullet, 'a\nb'),
    ];
    for (final (NoteListKind kind, String source) in steps) {
      final Transaction transaction = _sure(toggleList(state, kind));
      expect(transaction.event, TransactionEvent.list);
      state = _all(transaction.changes.apply(state.source));
      expect(state.source, source);
    }

    final String bulleted = _list(_range('a\nb\nc', 0, 5), NoteListKind.bullet);
    expect(bulleted, '- a\n- b\n- c');
    expect(_list(_all(bulleted), NoteListKind.bullet), 'a\nb\nc');
  });

  test('a quote toggle adds and removes the marker on every selected line', () {
    final String quoted = _quote(_range('a\nb\nc', 0, 5));
    expect(quoted, '> a\n> b\n> c');
    expect(_quote(_all(quoted)), 'a\nb\nc');

    final Transaction lazy = _sure(toggleQuote(_range('> a\nb', 0, 5)));
    expect(lazy.event, TransactionEvent.format);
    expect(
      lazy.changes,
      ChangeSet(
        length: 5,
        replacements: const <TextReplacement>[TextReplacement(4, 4, '> ')],
      ),
    );
    expect(lazy.changes.apply('> a\nb'), '> a\n> b');

    final Transaction tight = _sure(toggleQuote(_caret('>a', 1)));
    expect(tight.changes.apply('>a'), 'a');
    expect(tight.selection, const NoteSelection.collapsed(0));
  });

  test('the heading cycle writes after list and quote markers', () {
    expect(_heading(_caret('- a', 3)), '- # a');
    expect(_heading(_caret('> a', 3)), '> # a');
    expect(_heading(_caret('-', 1)), '- # ');
    expect(_heading(_caret('- # a', 5)), '- ## a');
    expect(_heading(_caret('  ### a', 7)), 'a');
  });

  test('blank lines stay blank inside a multi line selection', () {
    expect(_list(_all('a\n\nb'), NoteListKind.bullet), '- a\n\n- b');
    expect(_quote(_all('a\n\nb')), '> a\n>\n> b');
    expect(_quote(_all('> a\n>\n> b')), 'a\n\nb');
    expect(_heading(_all('a\n\nb')), '# a\n\n# b');
  });

  test('a fenced code block is untouched by headings and lists', () {
    const String source = 'a\n```\ncode\n```\nb';
    expect(_heading(_all(source)), '# a\n```\ncode\n```\n# b');
    expect(
      _list(_all(source), NoteListKind.bullet),
      '- a\n```\ncode\n```\n- b',
    );
    expect(
      _list(_all(source), NoteListKind.numbered),
      '1. a\n```\ncode\n```\n1. b',
    );
    expect(_quote(_all(source)), '> a\n> ```\n> code\n> ```\n> b');
  });

  test('nested items keep their nesting when the marker width changes', () {
    expect(_list(_all('- a\n  - b'), NoteListKind.numbered), '1. a\n   1. b');
    expect(_list(_all('- a\n  - b'), NoteListKind.bullet), 'a\nb');
    expect(_list(_all('1. a\n   1. b'), NoteListKind.bullet), '- a\n  - b');
    expect(_list(_all('- a\n  - b'), NoteListKind.task), '- [ ] a\n  - [ ] b');
  });

  test('a crlf list keeps its line endings', () {
    expect(_list(_all('a\r\nb'), NoteListKind.bullet), '- a\r\n- b');
    expect(_list(_all('- a\r\n- b'), NoteListKind.bullet), 'a\r\nb');
  });

  test('a numbered run stays one list', () {
    expect(_list(_all('1. a\n- b'), NoteListKind.numbered), '1. a\n2. b');
    expect(_list(_all('1) a\n- b'), NoteListKind.numbered), '1) a\n2) b');
    expect(_list(_all('a\nb\nc'), NoteListKind.numbered), '1. a\n2. b\n3. c');
  });

  test('a lazy continuation line is not eligible', () {
    expect(_list(_all('1. a\nb'), NoteListKind.numbered), 'a\nb');
  });

  test('a lone empty line takes a marker', () {
    expect(_list(_caret('', 0), NoteListKind.bullet), '- ');
    expect(_heading(_caret('', 0)), '# ');
    expect(_list(_caret('a\n\nb', 2), NoteListKind.task), 'a\n- [ ] \nb');
    expect(_quote(_caret('', 0)), '>');
  });

  test('a selection ending at a line start leaves that line', () {
    const String source = 'a\nb\nc';
    expect(_list(_range(source, 0, 4), NoteListKind.bullet), '- a\n- b\nc');
    expect(_heading(_range(source, 0, 4)), '# a\n# b\nc');
    expect(_quote(_range(source, 0, 4)), '> a\n> b\nc');
  });

  test('a photo line is never changed', () {
    const String source = 'a\n$_photo\nb';
    expect(_heading(_all(source)), '# a\n$_photo\n# b');
    for (final NoteListKind kind in NoteListKind.values) {
      final String result = _list(_all(source), kind);
      expect(result.split('\n')[1], _photo);
    }
    expect(_quote(_all(source)), '> a\n$_photo\n> b');
    expect(cycleHeading(_caret(_photo, 3)), isNull);
    expect(toggleList(_caret(_photo, 3), NoteListKind.bullet), isNull);
    expect(toggleQuote(_caret(_photo, 3)), isNull);
  });

  test('bytes outside the touched lines are identical in a crlf note', () {
    const String source = 'one\r\n\r\n- two\r\n  - three\r\n\r\nfour';
    final int start = source.indexOf('- two');
    final int end = source.indexOf('three') + 5;
    final String numbered = _list(
      _range(source, start, end),
      NoteListKind.numbered,
    );
    expect(numbered.substring(0, start), source.substring(0, start));
    expect(numbered.endsWith('\r\n\r\nfour'), isTrue);
    expect(numbered, 'one\r\n\r\n1. two\r\n   1. three\r\n\r\nfour');
    final String headed = _heading(_range(source, 0, 3));
    expect(headed, '# $source');
    final String quoted = _quote(_range(source, start, end));
    expect(quoted, 'one\r\n\r\n> - two\r\n>   - three\r\n\r\nfour');
  });

  test('seeded selections always give a parseable list toggle', () {
    const String source =
        'one\n\n- two\n  - three\n> four\n\n```\nx\n```\nfive';
    for (int seed = 1; seed <= 20; seed++) {
      final int anchor = (seed * 11) % (source.length + 1);
      final int head = (seed * 17) % (source.length + 1);
      for (final NoteListKind kind in NoteListKind.values) {
        final Transaction? transaction = toggleList(
          _range(source, anchor, head),
          kind,
        );
        if (transaction == null) {
          continue;
        }
        final String result = transaction.changes.apply(source);
        expect(result.contains('```\nx\n```'), isTrue, reason: '$seed $kind');
        expect(transaction.selection.end, lessThanOrEqualTo(result.length));
      }
    }
  });
}
