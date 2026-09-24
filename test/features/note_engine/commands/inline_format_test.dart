import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/commands/inline_format.dart';
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

Transaction _toggle(EditorState state, InlineFormat format) {
  final Transaction? transaction = toggleInlineFormat(state, format);
  expect(transaction, isNotNull);
  return transaction!;
}

String _result(EditorState state, Transaction transaction) =>
    transaction.changes.apply(state.source);

void _expectToggle(
  EditorState state,
  InlineFormat format,
  String source,
  NoteSelection selection,
) {
  final Transaction transaction = _toggle(state, format);
  expect(_result(state, transaction), source);
  expect(transaction.selection, selection);
  expect(transaction.event, TransactionEvent.format);
  expect(transaction.addToHistory, isTrue);
  expect(transaction.composing, isNull);
  expect(transaction.time, Duration.zero);
}

const String _photo = '![c](photo/0123456789abcdef)';

void main() {
  test('bold wraps the word around a collapsed caret', () {
    final EditorState state = _caret('the quick fox', 6);
    final Transaction transaction = _toggle(state, InlineFormat.bold);
    expect(_result(state, transaction), 'the **quick** fox');
    expect(
      transaction.changes,
      ChangeSet(
        length: 13,
        replacements: const <TextReplacement>[
          TextReplacement(4, 4, '**'),
          TextReplacement(9, 9, '**'),
        ],
      ),
    );
    expect(transaction.selection, const NoteSelection.collapsed(8));
    expect(transaction.event, TransactionEvent.format);
    expect(transaction.addToHistory, isTrue);
  });

  test('italic writes single stars', () {
    final EditorState atCaret = _caret('the quick fox', 6);
    final Transaction first = _toggle(atCaret, InlineFormat.italic);
    expect(_result(atCaret, first), 'the *quick* fox');
    expect(first.selection, const NoteSelection.collapsed(7));
    expect(_result(atCaret, first), isNot(contains('_')));

    final EditorState overRange = _range('the quick fox', 4, 9);
    final Transaction second = _toggle(overRange, InlineFormat.italic);
    expect(_result(overRange, second), 'the *quick* fox');
    expect(second.selection, const NoteSelection(anchor: 5, head: 10));
    expect(_result(overRange, second), isNot(contains('_')));
  });

  test('a toggle inside a node removes its markers', () {
    final EditorState bold = _caret('the **quick** fox', 8);
    final Transaction removed = _toggle(bold, InlineFormat.bold);
    expect(_result(bold, removed), 'the quick fox');
    expect(removed.selection, const NoteSelection.collapsed(6));
    expect(
      removed.changes,
      ChangeSet(
        length: 17,
        replacements: const <TextReplacement>[
          TextReplacement(4, 6, ''),
          TextReplacement(11, 13, ''),
        ],
      ),
    );

    final EditorState boldRange = _range('the **quick** fox', 7, 9);
    final Transaction rangeRemoved = _toggle(boldRange, InlineFormat.bold);
    expect(_result(boldRange, rangeRemoved), 'the quick fox');
    expect(rangeRemoved.selection, const NoteSelection(anchor: 5, head: 7));

    _expectToggle(
      _caret('see [map](https://x.y) now', 6),
      InlineFormat.link,
      'see map now',
      const NoteSelection.collapsed(5),
    );
    final EditorState italic = _caret('a *b* c', 3);
    expect(_result(italic, _toggle(italic, InlineFormat.italic)), 'a b c');
  });

  test('a multi line selection is wrapped line by line', () {
    final EditorState lines = _range('alpha\nbeta\ngamma', 2, 13);
    final Transaction wrapped = _toggle(lines, InlineFormat.bold);
    expect(_result(lines, wrapped), 'al**pha**\n**beta**\n**ga**mma');
    expect(
      wrapped.changes,
      ChangeSet(
        length: 16,
        replacements: const <TextReplacement>[
          TextReplacement(2, 2, '**'),
          TextReplacement(5, 5, '**'),
          TextReplacement(6, 6, '**'),
          TextReplacement(10, 10, '**'),
          TextReplacement(11, 11, '**'),
          TextReplacement(13, 13, '**'),
        ],
      ),
    );
    expect(wrapped.selection, const NoteSelection(anchor: 4, head: 23));

    final EditorState crlf = _range('alpha\r\nbeta', 0, 11);
    expect(
      _result(crlf, _toggle(crlf, InlineFormat.bold)),
      '**alpha**\r\n**beta**',
    );

    final EditorState list = _range('- a\n- b', 0, 7);
    expect(_result(list, _toggle(list, InlineFormat.bold)), '- **a**\n- **b**');
  });

  test('strikethrough and highlight wrap the word at the caret', () {
    _expectToggle(
      _caret('the quick fox', 6),
      InlineFormat.strikethrough,
      'the ~~quick~~ fox',
      const NoteSelection.collapsed(8),
    );
    _expectToggle(
      _caret('the quick fox', 6),
      InlineFormat.highlight,
      'the ==quick== fox',
      const NoteSelection.collapsed(8),
    );
  });

  test('a link wraps with the caret in the destination or inserts a pair', () {
    _expectToggle(
      _range('the quick fox', 4, 9),
      InlineFormat.link,
      'the [quick]() fox',
      const NoteSelection.collapsed(12),
    );
    _expectToggle(
      _caret('a ', 2),
      InlineFormat.link,
      'a []()',
      const NoteSelection.collapsed(3),
    );
    _expectToggle(
      _caret('the quick fox', 6),
      InlineFormat.link,
      'the [quick]() fox',
      const NoteSelection.collapsed(12),
    );
  });

  test('code fences a part holding backticks with a longer run', () {
    final EditorState state = _range('a`b', 0, 3);
    expect(_result(state, _toggle(state, InlineFormat.code)), '``a`b``');
    final EditorState padded = _range('`a', 0, 2);
    expect(_result(padded, _toggle(padded, InlineFormat.code)), '`` `a ``');
  });

  test('a second bold removes the empty pair a first bold inserted', () {
    final EditorState state = _caret('a ', 2);
    final Transaction first = _toggle(state, InlineFormat.bold);
    expect(_result(state, first), 'a ****');
    expect(first.selection, const NoteSelection.collapsed(4));
    final EditorState next = state.apply(first);
    final Transaction second = _toggle(next, InlineFormat.bold);
    expect(_result(next, second), 'a ');
    expect(second.selection, const NoteSelection.collapsed(2));
  });

  test('runs of two stars are not an italic pair', () {
    _expectToggle(
      _caret('a ****', 4),
      InlineFormat.italic,
      'a ******',
      const NoteSelection.collapsed(5),
    );
    _expectToggle(
      _caret('a *****', 5),
      InlineFormat.bold,
      'a *********',
      const NoteSelection.collapsed(7),
    );
  });

  test('empty pairs of every format are removed', () {
    final Map<InlineFormat, String> pairs = <InlineFormat, String>{
      InlineFormat.italic: 'x *|* y',
      InlineFormat.strikethrough: 'x ~~|~~ y',
      InlineFormat.highlight: 'x ==|== y',
      InlineFormat.code: 'x `|` y',
      InlineFormat.link: 'x [|]() y',
    };
    for (final MapEntry<InlineFormat, String> pair in pairs.entries) {
      final int caret = pair.value.indexOf('|');
      _expectToggle(
        _caret(pair.value.replaceAll('|', ''), caret),
        pair.key,
        'x  y',
        const NoteSelection.collapsed(2),
      );
    }
  });

  test('a caret at the edge of a word inserts an empty pair', () {
    _expectToggle(
      _caret('the quick fox', 4),
      InlineFormat.bold,
      'the ****quick fox',
      const NoteSelection.collapsed(6),
    );
  });

  test('spaces at the ends of a selected part stay outside the markers', () {
    _expectToggle(
      _range('the quick fox', 3, 10),
      InlineFormat.bold,
      'the **quick** fox',
      const NoteSelection(anchor: 3, head: 14),
    );
    _expectToggle(
      _range('the quick fox', 10, 3),
      InlineFormat.bold,
      'the **quick** fox',
      const NoteSelection(anchor: 14, head: 3),
    );
  });

  test('italic around strong leaves the strong markers', () {
    final EditorState state = _caret('***a***', 4);
    expect(_result(state, _toggle(state, InlineFormat.italic)), '**a**');
  });

  test('a heading keeps its marker outside the pair', () {
    _expectToggle(
      _range('# Title', 0, 7),
      InlineFormat.bold,
      '# **Title**',
      const NoteSelection(anchor: 0, head: 9),
    );
    _expectToggle(
      _caret('# Title', 0),
      InlineFormat.bold,
      '# ****Title',
      const NoteSelection.collapsed(4),
    );
    _expectToggle(
      _caret('# Title ##', 10),
      InlineFormat.bold,
      '# Title**** ##',
      const NoteSelection.collapsed(9),
    );
  });

  test('a point in a list marker or task box moves to the content', () {
    _expectToggle(
      _caret('- [ ] a', 1),
      InlineFormat.bold,
      '- [ ] ****a',
      const NoteSelection.collapsed(8),
    );
    _expectToggle(
      _caret('>   b', 1),
      InlineFormat.bold,
      '>   ****b',
      const NoteSelection.collapsed(6),
    );
  });

  test('a table row keeps its pipes and padding outside the pair', () {
    _expectToggle(
      _caret('| a |\n| - |', 5),
      InlineFormat.bold,
      '| a**** |\n| - |',
      const NoteSelection.collapsed(5),
    );
    final EditorState cells = _range('| a b | c |\n| --- | --- |', 4, 9);
    final String result = _result(cells, _toggle(cells, InlineFormat.bold));
    expect(result.split('\n').first, '| a **b** | **c** |');
    expect(result.split('\n').last, '| --- | --- |');
  });

  test('code blocks, code spans and photo lines do not apply', () {
    expect(
      toggleInlineFormat(_caret('```\nlet word\n```', 8), InlineFormat.bold),
      isNull,
    );
    expect(
      toggleInlineFormat(
        _range('```\nlet word\n```', 5, 11),
        InlineFormat.italic,
      ),
      isNull,
    );
    expect(
      toggleInlineFormat(_caret('`code` b', 2), InlineFormat.bold),
      isNull,
    );
    expect(
      toggleInlineFormat(_caret('a\n\n$_photo', 6), InlineFormat.bold),
      isNull,
    );
    expect(toggleInlineFormat(_caret('---', 1), InlineFormat.bold), isNull);
    expect(
      toggleInlineFormat(_caret('| a |\n| --- |', 9), InlineFormat.bold),
      isNull,
    );
  });

  test('a caret right after a code span is outside it', () {
    _expectToggle(
      _caret('`a` b', 3),
      InlineFormat.bold,
      '`a`**** b',
      const NoteSelection.collapsed(5),
    );
  });

  test('a combining accent is part of its word', () {
    _expectToggle(
      _caret('café noir', 2),
      InlineFormat.bold,
      '**café** noir',
      const NoteSelection.collapsed(4),
    );
  });

  test('a caret between two emoji clusters is not inside a word', () {
    const String flags = '\u{1F1EB}\u{1F1F7}\u{1F1E9}\u{1F1EA}';
    _expectToggle(
      _caret(flags, 4),
      InlineFormat.bold,
      '\u{1F1EB}\u{1F1F7}****\u{1F1E9}\u{1F1EA}',
      const NoteSelection.collapsed(6),
    );
  });

  test('bold on paragraph three leaves every other byte of a crlf note', () {
    const String source = 'one\r\n\r\ntwo\r\n\r\nthe quick fox\r\n\r\nfour';
    final int caret = source.indexOf('quick') + 2;
    final EditorState state = _caret(source, caret);
    final String result = _result(state, _toggle(state, InlineFormat.bold));
    final int start = source.indexOf('the quick fox');
    final int end = start + 'the quick fox'.length;
    expect(result.substring(0, start), source.substring(0, start));
    expect(
      result.substring(result.length - (source.length - end)),
      source.substring(end),
    );
    expect(result.substring(start, end + 4), 'the **quick** fox');
  });

  test('each format pressed twice restores the source', () {
    for (final InlineFormat format in InlineFormat.values) {
      final EditorState state = _caret('the quick fox', 6);
      final EditorState once = state.apply(_toggle(state, format));
      final EditorState twice = once.apply(_toggle(once, format));
      expect(twice.source, 'the quick fox', reason: format.name);
    }
  });

  test('seeded random selections only insert or delete markers', () {
    const String source =
        'alpha **beta** gamma\r\n\r\n- one two\n- three\n\n# Head';
    final List<int> seeds = <int>[3, 17, 29, 41, 53];
    for (final int seed in seeds) {
      final int anchor = (seed * 7) % source.length;
      final int head = (seed * 13) % source.length;
      for (final InlineFormat format in InlineFormat.values) {
        final Transaction? transaction = toggleInlineFormat(
          _range(source, anchor, head),
          format,
        );
        if (transaction == null) {
          continue;
        }
        final String result = transaction.changes.apply(source);
        expect(
          result.split('\r\n').length,
          source.split('\r\n').length,
          reason: '$seed ${format.name}',
        );
        for (final TextReplacement replacement
            in transaction.changes.replacements) {
          expect(
            replacement.inserted.isEmpty || replacement.from == replacement.to,
            isTrue,
          );
        }
      }
    }
  });
}
