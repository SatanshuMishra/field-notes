import 'dart:math';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/input/delta_mapping.dart';
import 'package:field_notes/features/note_engine/projection/active_line.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/offset_map_builder.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_test/flutter_test.dart';

const NoteVisibleProjector _projector = NoteVisibleProjector();

const String _family = '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}';
const String _photoNote = 'A\n![p](photo/abc123abc123)\nB';
const String _photoVisible = 'A\n\u{FFFC}\nB';

EditorState _state(String source, NoteSelection selection) =>
    EditorState.create(source, parse: parseNoteTree, selection: selection);

EditorState _caret(String source, int offset) =>
    _state(source, NoteSelection.collapsed(offset));

VisibleText _visibleOf(EditorState state) {
  final ActiveLine active = activeLineAt(
    state.source,
    state.tree,
    state.selection,
  );
  return _projector.project(
    state.source,
    state.tree,
    active.line,
    activeCell: active.cell,
  );
}

TextEditingValue _value(
  String text,
  TextSelection selection, [
  TextRange composing = TextRange.empty,
]) => TextEditingValue(text: text, selection: selection, composing: composing);

TextEditingValue _caretValue(String text, int offset) =>
    _value(text, TextSelection.collapsed(offset: offset));

TextEditingDeltaInsertion _insert(
  String oldText,
  int offset,
  String text, {
  TextRange composing = TextRange.empty,
  TextAffinity affinity = TextAffinity.downstream,
}) => TextEditingDeltaInsertion(
  oldText: oldText,
  textInserted: text,
  insertionOffset: offset,
  selection: TextSelection.collapsed(
    offset: offset + text.length,
    affinity: affinity,
  ),
  composing: composing,
);

TextEditingDeltaDeletion _delete(String oldText, int start, int end) =>
    TextEditingDeltaDeletion(
      oldText: oldText,
      deletedRange: TextRange(start: start, end: end),
      selection: TextSelection.collapsed(offset: start),
      composing: TextRange.empty,
    );

TextEditingDeltaReplacement _replace(
  String oldText,
  int start,
  int end,
  String text, {
  TextRange composing = TextRange.empty,
}) => TextEditingDeltaReplacement(
  oldText: oldText,
  replacementText: text,
  replacedRange: TextRange(start: start, end: end),
  selection: TextSelection.collapsed(offset: start + text.length),
  composing: composing,
);

DeltaOutcome _map(
  EditorState state,
  TextEditingValue before,
  TextEditingDelta delta,
) => mapDelta(
  state: state,
  visible: _visibleOf(state),
  windowBase: 0,
  platformBefore: before,
  delta: delta,
);

Transaction _transaction(DeltaOutcome outcome) {
  expect(outcome, isA<MappedEdit>());
  return (outcome as MappedEdit).transaction;
}

void _expectUntouchedOutside(String before, String after, ChangeSet changes) {
  final List<TextReplacement> replacements = changes.replacements;
  if (replacements.isEmpty) {
    expect(after, before);
    return;
  }
  final int from = replacements.first.from;
  final int to = replacements.last.to;
  expect(after.substring(0, from), before.substring(0, from));
  expect(
    after.substring(after.length - (before.length - to)),
    before.substring(to),
  );
}

bool _splitsCrlf(String source, int offset) =>
    offset > 0 &&
    offset < source.length &&
    source[offset - 1] == '\r' &&
    source[offset] == '\n';

void main() {
  test(
    'a one grapheme deletion before the caret is classified as backspace',
    () {
      const String source = 'ab$_family';
      expect(source.length, 10);
      final EditorState atEnd = _caret(source, 10);
      final TextEditingValue caretAtEnd = _caretValue(source, 10);
      expect(
        _map(atEnd, caretAtEnd, _delete(source, 2, 10)),
        const BackspaceEdit(),
      );
      expect(
        _map(_caret(source, 0), _caretValue(source, 0), _delete(source, 0, 1)),
        const ForwardDeleteEdit(),
      );

      final Transaction twoClusters = _transaction(
        _map(atEnd, caretAtEnd, _delete(source, 1, 10)),
      );
      expect(
        twoClusters.changes,
        ChangeSet(
          length: 10,
          replacements: const <TextReplacement>[TextReplacement(1, 10, '')],
        ),
      );
      expect(twoClusters.event, TransactionEvent.inputDelete);

      final Transaction composing = _transaction(
        _map(
          atEnd,
          _value(
            source,
            const TextSelection.collapsed(offset: 10),
            const TextRange(start: 0, end: 10),
          ),
          _delete(source, 2, 10),
        ),
      );
      expect(composing.event, TransactionEvent.inputIme);
      expect(composing.addToHistory, isFalse);

      final Transaction overSelection = _transaction(
        _map(
          atEnd,
          _value(source, const TextSelection(baseOffset: 0, extentOffset: 10)),
          _delete(source, 2, 10),
        ),
      );
      expect(overSelection.changes.replacements, const <TextReplacement>[
        TextReplacement(2, 10, ''),
      ]);
    },
  );

  test('typing over a selected photo goes on a new line after it', () {
    expect(_photoNote.length, 28);
    final EditorState state = _state(
      _photoNote,
      const NoteSelection(anchor: 2, head: 26),
    );
    final VisibleText visible = _visibleOf(state);
    expect(visible.text, _photoVisible);
    final TextSelection selection = visibleSelectionFor(
      visible: visible,
      selection: state.selection,
      windowBase: 0,
    );
    expect(selection, const TextSelection(baseOffset: 2, extentOffset: 3));
    final TextEditingValue before = _value(_photoVisible, selection);

    final List<DeltaOutcome> outcomes = <DeltaOutcome>[
      _map(state, before, _replace(_photoVisible, 2, 3, 'h')),
      _map(state, before, _insert(_photoVisible, 3, 'h')),
      _map(state, before, _replace(_photoVisible, 2, 3, '\n')),
      _map(
        state,
        before,
        _replace(
          _photoVisible,
          2,
          3,
          'n',
          composing: const TextRange(start: 2, end: 3),
        ),
      ),
    ];
    expect(outcomes, const <DeltaOutcome>[
      TypeAfterPhotoEdit(
        photoLine: MdRange(2, 26),
        text: 'h',
        composing: false,
      ),
      TypeAfterPhotoEdit(
        photoLine: MdRange(2, 26),
        text: 'h',
        composing: false,
      ),
      TypeAfterPhotoEdit(
        photoLine: MdRange(2, 26),
        text: '\n',
        composing: false,
      ),
      TypeAfterPhotoEdit(photoLine: MdRange(2, 26), text: 'n', composing: true),
    ]);
    expect(outcomes.whereType<MappedEdit>(), isEmpty);
  });

  test('a replaced range never includes neighbouring hidden markers', () {
    const String source = 'The **fog** lifted\nnext';
    expect(source.length, 23);
    final EditorState state = _caret(source, 23);
    final VisibleText visible = _visibleOf(state);
    const String text = 'The fog lifted\nnext';
    expect(visible.text, text);
    final TextEditingValue before = _caretValue(text, 19);

    void expectEdit(
      TextEditingDelta delta,
      TextReplacement replacement,
      String result,
    ) {
      final Transaction transaction = _transaction(_map(state, before, delta));
      expect(transaction.changes.replacements, <TextReplacement>[replacement]);
      final String after = transaction.changes.apply(source);
      expect(after, result);
      _expectUntouchedOutside(source, after, transaction.changes);
    }

    expectEdit(
      _replace(text, 5, 7, 'ir'),
      const TextReplacement(7, 9, 'ir'),
      'The **fir** lifted\nnext',
    );
    expectEdit(
      _delete(text, 0, 4),
      const TextReplacement(0, 4, ''),
      '**fog** lifted\nnext',
    );
    expectEdit(
      _delete(text, 7, 14),
      const TextReplacement(11, 18, ''),
      'The **fog**\nnext',
    );
    expectEdit(
      _delete(text, 4, 7),
      const TextReplacement(4, 11, ''),
      'The  lifted\nnext',
    );
  });

  test('an insertion never lands between cr and lf', () {
    const String source = 'first\r\nsecond\r\nthird';
    expect(source.length, 20);
    final EditorState state = _caret(source, 13);
    final VisibleText visible = _visibleOf(state);
    const String text = 'first\nsecond\nthird';
    expect(visible.text, text);
    const Map<int, int> exact = <int, int>{5: 5, 6: 7, 12: 13, 13: 15};
    for (int offset = 0; offset <= 18; offset++) {
      for (final TextAffinity affinity in TextAffinity.values) {
        final int position = sourcePositionForVisible(
          state: state,
          visible: visible,
          visibleOffset: offset,
          affinity: affinity,
        );
        expect(_splitsCrlf(source, position), isFalse, reason: '$offset');
        final Transaction transaction = _transaction(
          _map(
            state,
            _caretValue(text, offset),
            _insert(text, offset, 'x', affinity: affinity),
          ),
        );
        final TextReplacement replacement =
            transaction.changes.replacements.single;
        expect(replacement.from, replacement.to);
        expect(replacement.from, position);
        expect(_splitsCrlf(source, replacement.from), isFalse);
        final int? expected = exact[offset];
        if (expected != null) {
          expect(position, expected, reason: '$offset $affinity');
        }
      }
    }
    final Transaction lineBreak = _transaction(
      _map(
        state,
        _value(text, const TextSelection(baseOffset: 5, extentOffset: 6)),
        _delete(text, 5, 6),
      ),
    );
    expect(lineBreak.changes.replacements, const <TextReplacement>[
      TextReplacement(5, 7, ''),
    ]);

    const String table = '| a | b |\r\n| --- | --- |\r\n| c | d |';
    expect(table.length, 35);
    final EditorState inCell = _caret(table, 29);
    const String cells = 'a\tb\nc\td';
    expect(_visibleOf(inCell).text, cells);
    final Transaction typed = _transaction(
      _map(inCell, _caretValue(cells, 5), _insert(cells, 4, 'x')),
    );
    expect(typed.changes.replacements, const <TextReplacement>[
      TextReplacement(28, 28, 'x'),
    ]);
  });

  test(
    'random deltas re-project to the platform text without a resync',
    () {
      int classified = 0;
      for (int seed = 0; seed < 10000; seed++) {
        final _Case? generated = _generateCase(seed);
        if (generated == null) {
          classified++;
          continue;
        }
        final _Case c = generated;
        final DeltaOutcome outcome = mapDelta(
          state: c.state,
          visible: c.visible,
          windowBase: 0,
          platformBefore: c.before,
          delta: c.delta,
        );
        if (outcome is ClassifiedEdit) {
          classified++;
          continue;
        }
        final String reason =
            'seed $seed, source ${_escaped(c.state.source)}, '
            'delta ${c.delta.runtimeType} ${_describe(c.delta)}';
        expect(outcome, isA<MappedEdit>(), reason: reason);
        final Transaction transaction = (outcome as MappedEdit).transaction;
        final EditorState next = c.state.apply(transaction);
        final ActiveLine active = activeLineAt(
          next.source,
          next.tree,
          next.selection,
        );
        final VisibleText reprojected = _projector.project(
          next.source,
          next.tree,
          active.line,
          activeCell: active.cell,
        );
        expect(reprojected.text, c.delta.apply(c.before).text, reason: reason);
        final List<TextReplacement> replacements =
            transaction.changes.replacements;
        expect(replacements, isNotEmpty, reason: reason);
        final int from = replacements.first.from;
        final int to = replacements.last.to;
        final String before = c.state.source;
        expect(
          next.source.substring(0, from),
          before.substring(0, from),
          reason: reason,
        );
        expect(
          next.source.substring(next.source.length - (before.length - to)),
          before.substring(to),
          reason: reason,
        );
      }
      expect(classified, lessThanOrEqualTo(1000));
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test('a backspace after a photo selects it and a delete removes it', () {
    final EditorState afterPhoto = _caret(_photoNote, 27);
    expect(
      _map(
        afterPhoto,
        _caretValue(_photoVisible, 4),
        _delete(_photoVisible, 3, 4),
      ),
      const SelectPhotoEdit(MdRange(2, 26)),
    );
    final EditorState selected = _state(
      _photoNote,
      const NoteSelection(anchor: 2, head: 26),
    );
    expect(
      _map(
        selected,
        _value(
          _photoVisible,
          const TextSelection(baseOffset: 2, extentOffset: 3),
        ),
        _delete(_photoVisible, 2, 3),
      ),
      const RemovePhotoEdit(MdRange(2, 26)),
    );
  });

  test('a selected photo is exactly its object replacement character', () {
    TextSelection selectionFor(String source, NoteSelection selection) {
      final EditorState state = _state(source, selection);
      return visibleSelectionFor(
        visible: _visibleOf(state),
        selection: selection,
        windowBase: 0,
      );
    }

    const TextSelection photo = TextSelection(baseOffset: 2, extentOffset: 3);
    expect(
      selectionFor(_photoNote, const NoteSelection(anchor: 2, head: 26)),
      photo,
    );
    expect(
      selectionFor(_photoNote, const NoteSelection(anchor: 2, head: 27)),
      photo,
    );
    expect(selectionFor(_photoNote, const NoteSelection.collapsed(10)), photo);
    expect(
      selectionFor(_photoNote, const NoteSelection(anchor: 1, head: 26)),
      const TextSelection(baseOffset: 1, extentOffset: 3),
    );
    expect(
      selectedPhotoLine(
        _state(_photoNote, const NoteSelection(anchor: 1, head: 26)),
      ),
      isNull,
    );
  });

  test('a selected photo line may include its own line break', () {
    expect(
      selectedPhotoLine(
        _state(_photoNote, const NoteSelection(anchor: 2, head: 27)),
      ),
      const MdRange(2, 26),
    );
    expect(
      selectedPhotoLine(
        _state(_photoNote, const NoteSelection(anchor: 2, head: 28)),
      ),
      isNull,
    );
    const String crlf = 'A\r\n![p](photo/abc123abc123)\r\nB';
    const NoteSelection withBreak = NoteSelection(anchor: 3, head: 29);
    final EditorState state = _state(crlf, withBreak);
    expect(selectedPhotoLine(state), const MdRange(3, 27));
    final VisibleText visible = _visibleOf(state);
    expect(visible.text, _photoVisible);
    expect(
      visibleSelectionFor(
        visible: visible,
        selection: withBreak,
        windowBase: 0,
      ),
      const TextSelection(baseOffset: 2, extentOffset: 3),
    );
  });

  test('deleting inside the active list marker runs the item command', () {
    expect(
      _map(
        _caret('- milk', 6),
        _caretValue('- milk', 6),
        _delete('- milk', 0, 1),
      ),
      const ListMarkerEdit(2),
    );
  });

  test('a line break inserts as enter unless a composition is active', () {
    final EditorState state = _caret('milk', 4);
    expect(
      _map(state, _caretValue('milk', 4), _insert('milk', 4, '\n')),
      const EnterEdit(),
    );
    final Transaction composed = _transaction(
      _map(
        state,
        _value(
          'milk',
          const TextSelection.collapsed(offset: 4),
          const TextRange(start: 0, end: 4),
        ),
        _insert('milk', 4, '\n'),
      ),
    );
    expect(composed.event, TransactionEvent.inputIme);
    expect(composed.changes.replacements, const <TextReplacement>[
      TextReplacement(4, 4, '\n'),
    ]);
  });

  test('a pipe typed into a cell and a deleted separator are classified', () {
    const String source = '| a | b |\n| - | - |';
    const String cells = 'a\tb';
    final EditorState first = _caret(source, 3);
    expect(_visibleOf(first).text, cells);
    expect(
      _map(first, _caretValue(cells, 1), _insert(cells, 1, 'a|b')),
      const TableCellTextEdit(replaced: MdRange(3, 3), text: 'a|b'),
    );
    final EditorState second = _caret(source, 6);
    expect(
      _map(second, _caretValue(cells, 2), _delete(cells, 1, 2)),
      const RejectedEdit(),
    );
    expect(
      _map(
        second,
        _value(cells, const TextSelection(baseOffset: 1, extentOffset: 2)),
        _delete(cells, 1, 2),
      ),
      const RejectedEdit(),
    );
  });

  test('a deletion touching part of a checkbox removes the whole box', () {
    const String source = '- [ ] milk\nnext';
    final EditorState state = _caret(source, 11);
    final VisibleText visible = _visibleOf(state);
    const String text = '\u{2610} milk\nnext';
    expect(visible.text, text);
    expect(
      visible.atomicAtVisible(0),
      const AtomicObject(
        kind: AtomicKind.checkbox,
        sourceRange: MdRange(2, 6),
        visibleOffset: 0,
        visibleLength: 2,
      ),
    );
    final Transaction transaction = _transaction(
      _map(state, _caretValue(text, 3), _delete(text, 1, 3)),
    );
    expect(transaction.changes.replacements, const <TextReplacement>[
      TextReplacement(2, 7, ''),
    ]);
    expect(transaction.changes.apply(source), '- ilk\nnext');
  });

  test(
    'a delta over the whole platform selection replaces the whole source selection',
    () {
      const String source = '# Title\nThe **fog**';
      expect(source.length, 19);
      final EditorState state = _state(
        source,
        const NoteSelection(anchor: 0, head: 19),
      );
      final String text = _visibleOf(state).text;
      expect(text.length, 17);
      final Transaction transaction = _transaction(
        _map(
          state,
          _value(text, const TextSelection(baseOffset: 0, extentOffset: 17)),
          _replace(text, 0, 17, 'x'),
        ),
      );
      expect(transaction.changes.apply(source), 'x');
    },
  );

  test('a selection-only delta maps its selection and composing range', () {
    final EditorState state = _caret('hello', 5);
    expect(
      _map(
        state,
        _caretValue('hello', 5),
        const TextEditingDeltaNonTextUpdate(
          oldText: 'hello',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange(start: 1, end: 3),
        ),
      ),
      const SelectionEdit(
        selection: NoteSelection.collapsed(3),
        composing: MdRange(1, 3),
      ),
    );
  });

  test('an insertion point is clamped into its line content', () {
    const String source = '# Title\nx';
    final EditorState state = _caret(source, 9);
    final VisibleText visible = _visibleOf(state);
    expect(visible.text, 'Title\nx');
    for (final TextAffinity affinity in TextAffinity.values) {
      expect(
        sourcePositionForVisible(
          state: state,
          visible: visible,
          visibleOffset: 0,
          affinity: affinity,
        ),
        2,
      );
    }
    expect(
      _transaction(
        _map(state, _caretValue('Title\nx', 0), _insert('Title\nx', 0, 'A')),
      ).changes.replacements,
      const <TextReplacement>[TextReplacement(2, 2, 'A')],
    );
  });

  test('typing after hidden closing markers lands inside the node', () {
    const String source = 'The **fog**\nx';
    final EditorState state = _caret(source, 13);
    const String text = 'The fog\nx';
    expect(_visibleOf(state).text, text);
    for (final TextAffinity affinity in TextAffinity.values) {
      final Transaction transaction = _transaction(
        _map(
          state,
          _caretValue(text, 7),
          _insert(text, 7, 's', affinity: affinity),
        ),
      );
      expect(transaction.changes.replacements, const <TextReplacement>[
        TextReplacement(9, 9, 's'),
      ]);
      expect(transaction.changes.apply(source), 'The **fogs**\nx');
    }
  });

  test('a visible selection is offset by the window base', () {
    final String source = 'a' * 300;
    final EditorState state = _state(
      source,
      const NoteSelection(anchor: 150, head: 160),
    );
    expect(
      visibleSelectionFor(
        visible: _visibleOf(state),
        selection: state.selection,
        windowBase: 100,
      ),
      const TextSelection(baseOffset: 50, extentOffset: 60),
    );
  });

  test('every classified edit compares by value', () {
    List<ClassifiedEdit> build(int n) => <ClassifiedEdit>[
      const BackspaceEdit(),
      const ForwardDeleteEdit(),
      TypeAfterPhotoEdit(
        photoLine: MdRange(n, n + 24),
        text: 'h$n',
        composing: n.isOdd,
      ),
      SelectPhotoEdit(MdRange(n, n + 24)),
      RemovePhotoEdit(MdRange(n, n + 24)),
      ListMarkerEdit(n),
      const EnterEdit(),
      TableCellTextEdit(replaced: MdRange(n, n + 1), text: 'a|$n'),
      const RejectedEdit(),
    ];
    final List<ClassifiedEdit> a = build(2);
    final List<ClassifiedEdit> b = build(2);
    final List<ClassifiedEdit> c = build(3);
    for (int i = 0; i < a.length; i++) {
      expect(a[i], b[i]);
      expect(a[i].hashCode, b[i].hashCode);
      for (int j = 0; j < a.length; j++) {
        if (i != j) {
          expect(a[i], isNot(b[j]));
        }
      }
    }
    for (final int i in <int>[2, 3, 4, 5, 7]) {
      expect(a[i], isNot(c[i]));
    }
    expect(
      const SelectPhotoEdit(MdRange(2, 26)).toString(),
      'SelectPhotoEdit(MdRange(2, 26))',
    );
  });
}

final class _Case {
  const _Case({
    required this.state,
    required this.visible,
    required this.before,
    required this.delta,
  });

  final EditorState state;
  final VisibleText visible;
  final TextEditingValue before;
  final TextEditingDelta delta;
}

const List<String> _neutral = <String>[
  'a',
  'q',
  'z',
  'A',
  'M',
  'Z',
  '0',
  '7',
  '9',
  '\u{E9}',
  '\u{DF}',
  '\u{65E5}',
  '\u{672C}',
  '\u{1F44D}\u{1F3FD}',
  _family,
  '\u{1F1EF}\u{1F1F5}',
];

const String _hex = '0123456789abcdef';

String _word(Random random) {
  final int length = 2 + random.nextInt(6);
  return String.fromCharCodes(<int>[
    for (int i = 0; i < length; i++) 0x61 + random.nextInt(26),
  ]);
}

String _words(Random random, int min, int max) => <String>[
  for (int i = 0, n = min + random.nextInt(max - min + 1); i < n; i++)
    _word(random),
].join(' ');

String _run(Random random) {
  final String w = _word(random);
  return switch (random.nextInt(6)) {
    0 => '**$w**',
    1 => '*$w*',
    2 => '~~$w~~',
    3 => '==$w==',
    4 => '`$w`',
    _ => '[$w](https://x.y)',
  };
}

String _paragraphLine(Random random) {
  final List<String> parts = <String>[
    for (int i = 0, n = 1 + random.nextInt(4); i < n; i++) _word(random),
  ];
  if (random.nextBool()) {
    parts.insert(random.nextInt(parts.length + 1), _run(random));
  }
  return parts.join(' ');
}

String _block(Random random) {
  switch (random.nextInt(9)) {
    case 0:
      return <String>[
        for (int i = 0, n = 1 + random.nextInt(2); i < n; i++)
          _paragraphLine(random),
      ].join('\n');
    case 1:
      return '${'#' * (1 + random.nextInt(6))} ${_words(random, 1, 3)}';
    case 2:
    case 3:
      final int kind = random.nextInt(3);
      return <String>[
        for (int i = 0, n = 1 + random.nextInt(3); i < n; i++)
          '${i > 0 && random.nextInt(3) == 0 ? '  ' : ''}'
              '${switch (kind) {
                0 => '- ',
                1 => '${i + 1}. ',
                _ => random.nextBool() ? '- [ ] ' : '- [x] ',
              }}'
              '${_words(random, 1, 3)}',
      ].join('\n');
    case 4:
      return <String>[
        for (int i = 0, n = 1 + random.nextInt(2); i < n; i++)
          '> ${_words(random, 1, 3)}',
      ].join('\n');
    case 5:
      return '```\n${_words(random, 1, 3)}\n```';
    case 6:
      return '---';
    case 7:
      final String reference = String.fromCharCodes(<int>[
        for (int i = 0; i < 12; i++) _hex.codeUnitAt(random.nextInt(16)),
      ]);
      const List<String> titles = <String>[
        '',
        ' "left medium"',
        ' "right small"',
        ' "centre large"',
        ' "full"',
      ];
      return '![${_word(random)}](photo/$reference'
          '${titles[random.nextInt(titles.length)]})';
    default:
      final int columns = 2 + random.nextInt(2);
      String row(String Function() cell) =>
          '| ${<String>[for (int i = 0; i < columns; i++) cell()].join(' | ')} |';
      return <String>[
        row(() => _word(random)),
        row(() => '---'),
        for (int i = 0, n = 1 + random.nextInt(2); i < n; i++)
          row(() => _words(random, 1, 2)),
      ].join('\n');
  }
}

String _note(Random random) {
  final StringBuffer buffer = StringBuffer();
  for (int i = 0, n = 3 + random.nextInt(10); i < n; i++) {
    if (i > 0) {
      buffer.write(random.nextBool() ? '\n' : '\n\n');
    }
    buffer.write(_block(random));
  }
  final String note = buffer.toString();
  return random.nextBool() ? note : note.replaceAll('\n', '\r\n');
}

String _neutralText(Random random, int graphemes) {
  final List<String> parts = <String>[
    for (int i = 0; i < graphemes; i++)
      _neutral[random.nextInt(_neutral.length)],
  ];
  if (graphemes >= 3 && random.nextInt(3) == 0) {
    parts[1] = ' ';
  }
  return parts.join();
}

bool _isWordUnit(int unit) =>
    (unit >= 0x61 && unit <= 0x7A) ||
    (unit >= 0x41 && unit <= 0x5A) ||
    (unit >= 0x30 && unit <= 0x39);

List<MdRange> _wordRuns(VisibleText visible, VisibleLine line) {
  final List<MdRange> runs = <MdRange>[];
  for (final VisibleSpan span in line.spans) {
    if (span.kind != VisibleSpanKind.text) {
      continue;
    }
    int at = span.visibleRange.start;
    while (at < span.visibleRange.end) {
      if (!_isWordUnit(visible.text.codeUnitAt(at))) {
        at++;
        continue;
      }
      final int start = at;
      while (at < span.visibleRange.end &&
          _isWordUnit(visible.text.codeUnitAt(at))) {
        at++;
      }
      runs.add(MdRange(start, at));
    }
  }
  return runs;
}

_Case? _generateCase(int seed) {
  final Random random = Random(seed);
  final String source = _note(random);
  final MdTree tree = parseNoteTree(source);
  final int lineCount = MdSourceLines.split(source).lines.length;
  final List<int> order = <int>[for (int i = 0; i < lineCount; i++) i]
    ..shuffle(random);
  for (final int line in order) {
    final VisibleText probe = _projector.project(source, tree, line);
    final int? index = VisibleLineIndex(probe).lineForSource(line);
    if (index == null) {
      continue;
    }
    final List<MdRange> runs = _wordRuns(probe, probe.lines[index]);
    if (runs.isEmpty) {
      continue;
    }
    final MdRange run = runs[random.nextInt(runs.length)];
    final int caretVisible = run.start + random.nextInt(run.length + 1);
    final VisibleSpan span = probe.lines[index].spans.firstWhere(
      (VisibleSpan s) =>
          s.kind == VisibleSpanKind.text &&
          s.visibleRange.start <= run.start &&
          run.end <= s.visibleRange.end,
    );
    final int caret =
        span.sourceRange.start + (caretVisible - span.visibleRange.start);
    return _buildCase(random, source, caret, run);
  }
  return null;
}

_Case _buildCase(Random random, String source, int caret, MdRange run) {
  final EditorState atCaret = _caret(source, caret);
  final VisibleText visible = _visibleOf(atCaret);
  final TextEditingValue caretValue = _value(
    visible.text,
    visibleSelectionFor(
      visible: visible,
      selection: atCaret.selection,
      windowBase: 0,
    ),
  );
  final int v = caretValue.selection.baseOffset;
  final int kind = random.nextInt(4);
  if (kind == 1 && run.length >= 3) {
    final int count =
        2 + random.nextInt(run.length - 2 < 3 ? run.length - 2 : 3);
    final int start = run.start + random.nextInt(run.length - count + 1);
    return _Case(
      state: atCaret,
      visible: visible,
      before: caretValue,
      delta: _delete(visible.text, start, start + count),
    );
  }
  if (kind == 2) {
    final int start = run.start + random.nextInt(run.length);
    final int end = start + 1 + random.nextInt(run.end - start);
    final MdRange selected = sourceRangeForVisible(
      state: atCaret,
      visible: visible,
      visibleRange: TextRange(start: start, end: end),
    );
    final EditorState withSelection = _state(
      source,
      NoteSelection(anchor: selected.start, head: selected.end),
    );
    final VisibleText selectedVisible = _visibleOf(withSelection);
    final TextSelection platform = visibleSelectionFor(
      visible: selectedVisible,
      selection: withSelection.selection,
      windowBase: 0,
    );
    return _Case(
      state: withSelection,
      visible: selectedVisible,
      before: _value(selectedVisible.text, platform),
      delta: _replace(
        selectedVisible.text,
        platform.start,
        platform.end,
        _neutralText(random, 1 + random.nextInt(3)),
      ),
    );
  }
  final String text = _neutralText(random, 1 + random.nextInt(3));
  return _Case(
    state: atCaret,
    visible: visible,
    before: caretValue,
    delta: _insert(
      visible.text,
      v,
      text,
      composing: kind == 3
          ? TextRange(start: v, end: v + text.length)
          : TextRange.empty,
    ),
  );
}

String _escaped(String text) => text
    .replaceAll('\r', r'\r')
    .replaceAll('\n', r'\n')
    .replaceAll('\t', r'\t');

String _describe(TextEditingDelta delta) => switch (delta) {
  final TextEditingDeltaInsertion d =>
    "insert '${_escaped(d.textInserted)}' at ${d.insertionOffset}"
        ' (${d.textInserted.characters.length} graphemes)',
  final TextEditingDeltaDeletion d =>
    'delete ${d.deletedRange.start}..${d.deletedRange.end}',
  final TextEditingDeltaReplacement d =>
    "replace ${d.replacedRange.start}..${d.replacedRange.end} "
        "with '${_escaped(d.replacementText)}'",
  _ => 'selection ${delta.selection}',
};
