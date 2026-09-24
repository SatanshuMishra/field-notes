import 'dart:math';

import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/history.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

MdTree _parse(String s) =>
    MdTree(sourceLength: s.length, blocks: const <MdBlock>[]);

EditorState _start(
  String source, {
  NoteSelection selection = const NoteSelection.collapsed(0),
}) => EditorState.create(
  source,
  parse: _parse,
  selection: selection,
  history: const NoteHistory(),
);

NoteHistory _history(EditorState state) => state.history as NoteHistory;

EditorState _type(EditorState state, String text, int ms) {
  final int n = state.source.length;
  final int caret = state.selection.end;
  return state.apply(
    Transaction(
      changes: ChangeSet.single(n, caret, caret, text),
      selection: NoteSelection.collapsed(caret + text.length),
      event: TransactionEvent.inputType,
      time: Duration(milliseconds: ms),
    ),
  );
}

EditorState _backspace(EditorState state, int ms) {
  final int n = state.source.length;
  final int caret = state.selection.end;
  return state.apply(
    Transaction(
      changes: ChangeSet.single(n, caret - 1, caret, ''),
      selection: NoteSelection.collapsed(caret - 1),
      event: TransactionEvent.inputDelete,
      time: Duration(milliseconds: ms),
    ),
  );
}

EditorState _typeAll(EditorState state, List<String> letters, int startMs) {
  EditorState result = state;
  for (int i = 0; i < letters.length; i++) {
    result = _type(result, letters[i], startMs + i * 10);
  }
  return result;
}

EditorState _compose(
  EditorState state,
  List<int> times, {
  bool addToHistory = false,
}) {
  final EditorState first = state.apply(
    Transaction(
      changes: ChangeSet.single(1, 1, 1, 'n'),
      selection: const NoteSelection.collapsed(2),
      event: TransactionEvent.inputIme,
      composing: const MdRange(1, 2),
      addToHistory: addToHistory,
      time: Duration(milliseconds: times[0]),
    ),
  );
  final EditorState second = first.apply(
    Transaction(
      changes: ChangeSet.single(2, 1, 2, '\u306b'),
      selection: const NoteSelection.collapsed(2),
      event: TransactionEvent.inputIme,
      composing: const MdRange(1, 2),
      addToHistory: addToHistory,
      time: Duration(milliseconds: times[1]),
    ),
  );
  expect(_history(second).undoDepth, 1);
  return second.apply(
    Transaction(
      changes: ChangeSet.single(2, 1, 2, '\u65e5\u672c'),
      selection: const NoteSelection.collapsed(3),
      event: TransactionEvent.inputIme,
      addToHistory: addToHistory,
      time: Duration(milliseconds: times[2]),
    ),
  );
}

EditorState _outside(EditorState state, ChangeSet changes, int caret) =>
    state.apply(
      Transaction(
        changes: changes,
        selection: NoteSelection.collapsed(caret),
        event: TransactionEvent.format,
        addToHistory: false,
        time: const Duration(milliseconds: 1100),
      ),
    );

EditorState _command(EditorState state, TransactionEvent event, int ms) {
  final int n = state.source.length;
  return state.apply(
    Transaction(
      changes: ChangeSet.single(n, n, n, 'x'),
      selection: NoteSelection.collapsed(n + 1),
      event: event,
      time: Duration(milliseconds: ms),
    ),
  );
}

void _checkCompositionCommit({required bool addToHistory}) {
  final EditorState typed = _type(_start(''), 'a', 0);
  final EditorState committed = _compose(typed, const <int>[
    100,
    150,
    200,
  ], addToHistory: addToHistory);
  expect(_history(committed).undoDepth, 1);
  expect(committed.source, 'a\u65e5\u672c');
  final EditorState undone = committed.undo();
  expect(undone.source, '');
  expect(undone.selection, const NoteSelection.collapsed(0));
  final EditorState redone = undone.redo();
  expect(redone.source, 'a\u65e5\u672c');
  expect(redone.selection, const NoteSelection.collapsed(3));

  final EditorState late = _compose(_type(_start(''), 'a', 0), const <int>[
    700,
    750,
    800,
  ], addToHistory: addToHistory);
  expect(_history(late).undoDepth, 2);
  final EditorState once = late.undo();
  expect(once.source, 'a');
  expect(once.selection, const NoteSelection.collapsed(1));
  expect(once.undo().source, '');
}

const String _alphabet = 'abc de\tf';

String _randomNote(Random random) {
  final StringBuffer buffer = StringBuffer();
  final int units = random.nextInt(41);
  while (buffer.length < units) {
    final int pick = random.nextInt(10);
    if (pick == 0) {
      buffer.write('\n');
    } else if (pick == 1 && buffer.length + 2 <= units) {
      buffer.write('\r\n');
    } else {
      buffer.write(_alphabet[random.nextInt(_alphabet.length)]);
    }
  }
  return buffer.toString();
}

List<int> _unsplitOffsets(String source) => <int>[
  for (int i = 0; i <= source.length; i++)
    if (i == 0 ||
        i == source.length ||
        !(source.codeUnitAt(i - 1) == 0x0D && source.codeUnitAt(i) == 0x0A))
      i,
];

String _randomText(Random random) {
  final int length = random.nextInt(4);
  return String.fromCharCodes(<int>[
    for (int i = 0; i < length; i++)
      random.nextInt(8) == 0 ? 0x0A : 0x61 + random.nextInt(26),
  ]);
}

ChangeSet _randomOutside(Random random, String source) {
  final List<int> offsets = _unsplitOffsets(source);
  final int count = 1 + random.nextInt(2);
  final List<int> picks = <int>[
    for (int i = 0; i < count * 2; i++) offsets[random.nextInt(offsets.length)],
  ]..sort();
  final List<TextReplacement> replacements = <TextReplacement>[
    for (int i = 0; i < count; i++)
      TextReplacement(picks[i * 2], picks[i * 2 + 1], _randomText(random)),
  ];
  final ChangeSet changes = ChangeSet(
    length: source.length,
    replacements: replacements,
  );
  return changes.isEmpty
      ? ChangeSet.single(source.length, picks.first, picks.first, 'z')
      : changes;
}

EditorState _randomStep(Random random, EditorState state, int ms) {
  final int n = state.source.length;
  final int caret = state.selection.end;
  switch (random.nextInt(4)) {
    case 0:
      return _type(state, _alphabet[random.nextInt(_alphabet.length)], ms);
    case 1:
      return caret == 0 ? _type(state, 'q', ms) : _backspace(state, ms);
    case 2:
      final int at = random.nextInt(n + 1);
      return state.apply(
        Transaction(
          changes: ChangeSet.single(n, at, at, '**'),
          selection: NoteSelection.collapsed(at + 2),
          event: TransactionEvent.format,
          time: Duration(milliseconds: ms),
        ),
      );
    default:
      final ChangeSet changes = _randomOutside(random, state.source);
      return state.apply(
        Transaction(
          changes: changes,
          selection: NoteSelection.collapsed(
            random.nextInt(changes.newLength + 1),
          ),
          event: TransactionEvent.format,
          addToHistory: false,
          time: Duration(milliseconds: ms),
        ),
      );
  }
}

EditorState _formattedAbd() =>
    _start('abd', selection: const NoteSelection.collapsed(2)).apply(
      Transaction(
        changes: ChangeSet.single(3, 2, 2, 'cQ'),
        selection: const NoteSelection.collapsed(3),
        event: TransactionEvent.format,
      ),
    );

EditorState _typedOverC() => _formattedAbd()
    .withSelection(const NoteSelection(anchor: 2, head: 3))
    .apply(
      Transaction(
        changes: ChangeSet.single(5, 2, 3, 'k'),
        selection: const NoteSelection.collapsed(3),
        event: TransactionEvent.inputType,
        time: const Duration(milliseconds: 100),
      ),
    );

String _fresh(int base, int length) =>
    String.fromCharCodes(<int>[for (int k = 0; k < length; k++) base + k]);

Set<int> _units(String source) => source.codeUnits.toSet();

String _ordered(String source, Set<int> units) =>
    String.fromCharCodes(source.codeUnits.where(units.contains));

ChangeSet _uniqueOutside(Random random, String source, int caret, int base) {
  final int n = source.length;
  final int count = 1 + random.nextInt(2);
  final List<int> picks = <int>[
    for (int i = 0; i < count * 2; i++)
      random.nextBool() ? caret : random.nextInt(n + 1),
  ]..sort();
  final ChangeSet changes = ChangeSet(
    length: n,
    replacements: <TextReplacement>[
      for (int i = 0; i < count; i++)
        TextReplacement(
          picks[i * 2],
          picks[i * 2 + 1],
          _fresh(base + i * 4, random.nextInt(4)),
        ),
    ],
  );
  return changes.isEmpty
      ? ChangeSet.single(n, caret, caret, _fresh(base, 1))
      : changes;
}

(EditorState, bool) _uniqueStep(
  Random random,
  EditorState state,
  int step,
  int ms,
) {
  final int n = state.source.length;
  final int caret = state.selection.end;
  final int base = 0x4E00 + step * 8;
  final Duration time = Duration(milliseconds: ms);
  final int pick = random.nextInt(6);
  if (pick == 1 && caret > 0) {
    return (_backspace(state, ms), false);
  }
  if (pick == 2 && n > 0) {
    final int from = random.nextInt(n);
    final int to = from + 1 + random.nextInt(n - from);
    final String inserted = _fresh(base, 1 + random.nextInt(3));
    return (
      state
          .withSelection(NoteSelection(anchor: from, head: to))
          .apply(
            Transaction(
              changes: ChangeSet.single(n, from, to, inserted),
              selection: NoteSelection.collapsed(from + inserted.length),
              event: TransactionEvent.format,
              time: time,
            ),
          ),
      false,
    );
  }
  if (pick == 3 && state.history.canUndo) {
    return (state.undo(), false);
  }
  if (pick == 4 && state.history.canRedo) {
    return (state.redo(), false);
  }
  if (pick == 5) {
    final ChangeSet changes = _uniqueOutside(random, state.source, caret, base);
    return (
      state.apply(
        Transaction(
          changes: changes,
          selection: NoteSelection.collapsed(
            random.nextInt(changes.newLength + 1),
          ),
          event: TransactionEvent.format,
          addToHistory: false,
          time: time,
        ),
      ),
      true,
    );
  }
  return (_type(state, _fresh(base, 1), ms), false);
}

void main() {
  test(
    'an outside insertion at an entry insertion point keeps older entries on their bytes',
    () {
      final EditorState deleted = _backspace(_formattedAbd(), 100);
      expect(deleted.source, 'abQd');
      final EditorState outside = _outside(
        deleted,
        ChangeSet.single(4, 2, 2, 'y'),
        3,
      );
      expect(outside.source, 'abyQd');
      final EditorState once = outside.undo();
      expect(once.source, 'abcyQd');
      final EditorState twice = once.undo();
      expect(twice.source, 'abyd');
      expect(twice.history.canUndo, isFalse);
      expect(twice.redo().redo().source, 'abyQd');
    },
  );

  test(
    'an outside edit starting where an entry replacement starts keeps older entries on their bytes',
    () {
      final EditorState typed = _typedOverC();
      expect(typed.source, 'abkQd');

      final EditorState replaced = _outside(
        typed,
        ChangeSet.single(5, 2, 3, 'y'),
        3,
      );
      expect(replaced.source, 'abyQd');
      final EditorState replacedOnce = replaced.undo();
      expect(replacedOnce.source, 'abcyQd');
      expect(replacedOnce.undo().source, 'abyd');

      final EditorState inserted = _outside(
        typed,
        ChangeSet.single(5, 2, 2, 'y'),
        3,
      );
      expect(inserted.source, 'abykQd');
      final EditorState insertedOnce = inserted.undo();
      expect(insertedOnce.source, 'abcyQd');
      expect(insertedOnce.undo().source, 'abyd');
    },
  );

  test(
    'undo after random changes outside history restores exactly the bytes history owns',
    () {
      for (int i = 0; i < 3000; i++) {
        final int seed = 20260924 + i;
        final Random random = Random(seed);
        final String note = _fresh(0x3400, random.nextInt(12));
        EditorState state = _start(
          note,
          selection: NoteSelection.collapsed(random.nextInt(note.length + 1)),
        );
        List<String> seen = <String>[note];
        Set<int> owned = _units(note);
        int ms = 0;
        final int steps = 1 + random.nextInt(30);
        for (int s = 0; s < steps; s++) {
          ms += random.nextInt(800);
          final (EditorState next, bool outside) = _uniqueStep(
            random,
            state,
            s,
            ms,
          );
          if (outside) {
            final Set<int> before = _units(state.source);
            final Set<int> after = _units(next.source);
            owned = owned
                .difference(before.difference(after))
                .union(after.difference(before));
          }
          state = next;
          seen = <String>[...seen, state.source];
        }
        int guard = 0;
        while (state.history.canUndo) {
          state = state.undo();
          guard += 1;
          expect(guard, lessThanOrEqualTo(steps), reason: 'seed $seed');
        }
        final String result = state.source;
        final Set<int> units = _units(result);
        expect(result.length, units.length, reason: 'seed $seed');
        expect(units, owned, reason: 'seed $seed');
        for (final String earlier in seen) {
          final Set<int> both = _units(earlier).intersection(units);
          expect(
            _ordered(result, both),
            _ordered(earlier, both),
            reason: 'seed $seed',
          );
        }
      }
    },
  );

  test(
    'typing groups break on pause, caret move, line break, direction switch and space after a word',
    () {
      final EditorState paused = _type(
        _type(_type(_start(''), 'a', 0), 'b', 500),
        'c',
        1001,
      );
      expect(paused.source, 'abc');
      final EditorState pausedOnce = paused.undo();
      expect(pausedOnce.source, 'ab');
      final EditorState pausedTwice = pausedOnce.undo();
      expect(pausedTwice.source, '');
      expect(pausedTwice.history.canUndo, isFalse);

      final EditorState moved = _type(
        _type(_type(_start(''), 'a', 0), 'b', 10)
            .withSelection(const NoteSelection.collapsed(1))
            .withSelection(const NoteSelection.collapsed(2)),
        'c',
        20,
      );
      expect(moved.source, 'abc');
      expect(moved.undo().source, 'ab');
      expect(moved.undo().undo().source, '');
      final EditorState jumped = _type(
        _type(
          _type(_start(''), 'a', 0),
          'b',
          10,
        ).withSelection(const NoteSelection.collapsed(0)),
        'c',
        20,
      );
      expect(jumped.source, 'cab');
      expect(jumped.undo().source, 'ab');

      final EditorState broken = _type(
        _type(_type(_start(''), 'a', 0), '\n', 10),
        'b',
        20,
      );
      expect(broken.undo().source, 'a\n');
      expect(broken.undo().undo().source, 'a');
      expect(broken.undo().undo().undo().source, '');

      final EditorState switched = _type(
        _backspace(_type(_type(_start(''), 'a', 0), 'b', 10), 20),
        'c',
        30,
      );
      expect(switched.source, 'ac');
      expect(switched.undo().source, 'a');
      expect(switched.undo().undo().source, 'ab');
      expect(switched.undo().undo().undo().source, '');

      final EditorState words = _typeAll(_start(''), const <String>[
        't',
        'h',
        'e',
        ' ',
        'q',
        'u',
        'i',
        'c',
        'k',
      ], 0);
      expect(words.source, 'the quick');
      expect(words.undo().source, 'the ');
      expect(words.undo().undo().source, '');
    },
  );

  test('a committed composition is one ime entry joined to typing', () {
    _checkCompositionCommit(addToHistory: false);
  });

  test('undo and redo restore the selection before and after', () {
    final EditorState typed = _type(
      _start('One\n\nNine', selection: const NoteSelection.collapsed(3)),
      's',
      0,
    ).withSelection(const NoteSelection.collapsed(10));
    expect(typed.source, 'Ones\n\nNine');
    final EditorState undone = typed.undo();
    expect(undone.source, 'One\n\nNine');
    expect(undone.selection, const NoteSelection.collapsed(3));
    final EditorState redone = undone.redo();
    expect(redone.source, 'Ones\n\nNine');
    expect(redone.selection, const NoteSelection.collapsed(4));

    final EditorState replaced =
        _start(
          'One\n\nNine',
          selection: const NoteSelection(anchor: 3, head: 0),
        ).apply(
          Transaction(
            changes: ChangeSet.single(9, 0, 3, 'Two'),
            selection: const NoteSelection.collapsed(3),
            event: TransactionEvent.inputType,
          ),
        );
    expect(replaced.source, 'Two\n\nNine');
    final EditorState restored = replaced.undo();
    expect(restored.source, 'One\n\nNine');
    expect(restored.selection, const NoteSelection(anchor: 3, head: 0));
    expect(restored.redo().selection, const NoteSelection.collapsed(3));
  });

  test('the history keeps exactly the newest one thousand entries', () {
    EditorState state = _start('');
    for (int i = 0; i < 1200; i++) {
      state = _command(state, TransactionEvent.format, i * 10);
    }
    expect(_history(state).undoDepth, 1000);
    for (int i = 0; i < 1000; i++) {
      final int before = state.source.length;
      state = state.undo();
      expect(state.source.length, before - 1);
    }
    expect(state.source, 'x' * 200);
    expect(state.history.canUndo, isFalse);
    final EditorState extra = state.undo();
    expect(extra.source, state.source);
    expect(extra.selection, state.selection);
    expect(_history(state).redoDepth, 1000);

    final EditorState restored = state.apply(
      Transaction(
        changes: ChangeSet.empty(200),
        selection: const NoteSelection.collapsed(200),
        event: TransactionEvent.restore,
        addToHistory: false,
      ),
    );
    expect(restored.history.canUndo, isFalse);
    expect(restored.history.canRedo, isFalse);
  });

  test('changes outside history map every stored entry', () {
    final EditorState typed = _type(
      _type(
        _typeAll(
          _start('Title\n', selection: const NoteSelection.collapsed(6)),
          const <String>['a', 'b', 'c'],
          0,
        ),
        'd',
        1000,
      ),
      'e',
      1010,
    );
    expect(typed.source, 'Title\nabcde');
    final EditorState undone = typed.undo();
    expect(undone.source, 'Title\nabc');
    final EditorState headed = _outside(
      undone,
      ChangeSet.single(9, 0, 0, '# '),
      11,
    );
    expect(headed.source, '# Title\nabc');
    final EditorState redone = headed.redo();
    expect(redone.source, '# Title\nabcde');
    expect(redone.selection, const NoteSelection.collapsed(13));
    final EditorState first = redone.undo();
    expect(first.source, '# Title\nabc');
    expect(first.selection, const NoteSelection.collapsed(11));
    final EditorState second = first.undo();
    expect(second.source, '# Title\n');
    expect(second.selection, const NoteSelection.collapsed(8));
    expect(second.history.canUndo, isFalse);

    final EditorState letters = _typeAll(
      _type(_start(''), 'x', 0),
      const <String>['a', 'b', 'c', 'd', 'e', 'f'],
      1000,
    );
    expect(letters.source, 'xabcdef');
    final EditorState inside = _outside(
      letters,
      ChangeSet.single(7, 3, 5, 'zz'),
      5,
    );
    expect(inside.source, 'xabzzef');
    final EditorState back = inside.undo();
    expect(back.source, 'xzz');
    final EditorState empty = back.undo();
    expect(empty.source, 'zz');
    expect(empty.history.canUndo, isFalse);
    expect(empty.redo().redo().source, 'xabzzef');
  });

  test('each format and external transaction is its own entry', () {
    final EditorState formatted = _command(
      _command(_start(''), TransactionEvent.format, 0),
      TransactionEvent.format,
      10,
    );
    expect(_history(formatted).undoDepth, 2);
    final EditorState external = _command(
      _command(_start(''), TransactionEvent.external, 0),
      TransactionEvent.external,
      10,
    );
    expect(_history(external).undoDepth, 2);
  });

  test('empty change sets record nothing and close only on a moved caret', () {
    final EditorState typed = _type(_start(''), 'a', 0);
    final EditorState same = typed.apply(
      Transaction(
        changes: ChangeSet.empty(1),
        selection: const NoteSelection.collapsed(1),
        event: TransactionEvent.inputType,
        addToHistory: false,
        time: const Duration(milliseconds: 5),
      ),
    );
    expect(_history(same).undoDepth, 1);
    final EditorState joined = _type(same, 'b', 10);
    expect(_history(joined).undoDepth, 1);

    final EditorState moved = typed
        .apply(
          Transaction(
            changes: ChangeSet.empty(1),
            selection: const NoteSelection.collapsed(0),
            event: TransactionEvent.inputType,
            addToHistory: false,
            time: const Duration(milliseconds: 5),
          ),
        )
        .apply(
          Transaction(
            changes: ChangeSet.empty(1),
            selection: const NoteSelection.collapsed(1),
            event: TransactionEvent.inputType,
            addToHistory: false,
            time: const Duration(milliseconds: 6),
          ),
        );
    expect(_history(moved).undoDepth, 1);
    expect(_history(_type(moved, 'b', 10)).undoDepth, 2);
  });

  test('deletion groups ignore the space rule', () {
    EditorState state = _start(
      'the quick',
      selection: const NoteSelection.collapsed(9),
    );
    for (int i = 0; i < 6; i++) {
      state = _backspace(state, i * 10);
    }
    expect(state.source, 'the');
    expect(_history(state).undoDepth, 1);
    expect(state.undo().source, 'the quick');
  });

  test('typing over a selection starts an entry later letters join', () {
    final EditorState over =
        _start(
          'abcd',
          selection: const NoteSelection(anchor: 1, head: 3),
        ).apply(
          Transaction(
            changes: ChangeSet.single(4, 1, 3, 'x'),
            selection: const NoteSelection.collapsed(2),
            event: TransactionEvent.inputType,
          ),
        );
    final EditorState joined = _type(_type(over, 'y', 10), 'z', 20);
    expect(joined.source, 'axyzd');
    expect(_history(over).undoDepth, 1);
    expect(_history(joined).undoDepth, 1);
    expect(joined.undo().source, 'abcd');
  });

  test('a new edit clears the redo stack', () {
    final EditorState undone = _type(_start(''), 'a', 0).undo();
    expect(_history(undone).redoDepth, 1);
    final EditorState edited = _type(undone, 'b', 10);
    expect(_history(edited).redoDepth, 0);
    expect(edited.history.canRedo, isFalse);
  });

  test('undo during a pending composition finalizes it first', () {
    final EditorState composing = _type(_start(''), 'a', 0).apply(
      Transaction(
        changes: ChangeSet.single(1, 1, 1, 'n'),
        selection: const NoteSelection.collapsed(2),
        event: TransactionEvent.inputIme,
        composing: const MdRange(1, 2),
        addToHistory: false,
        time: const Duration(milliseconds: 100),
      ),
    );
    expect(composing.history.canUndo, isTrue);
    final EditorState undone = composing.undo();
    expect(undone.source, '');
    expect(_history(undone).redoDepth, 1);
    expect(undone.redo().source, 'an');
  });

  test('a composition entering the history records the same way', () {
    _checkCompositionCommit(addToHistory: true);
  });

  test('a composing mark without text records nothing', () {
    final EditorState undone = _type(_start('ab'), 'c', 0).undo();
    expect(_history(undone).redoDepth, 1);
    final EditorState marked = undone.apply(
      Transaction(
        changes: ChangeSet.empty(2),
        selection: const NoteSelection.collapsed(0),
        event: TransactionEvent.inputIme,
        composing: const MdRange(0, 2),
        addToHistory: false,
        time: const Duration(milliseconds: 10),
      ),
    );
    expect(marked.history.canRedo, isTrue);
    final EditorState cleared = marked.apply(
      Transaction(
        changes: ChangeSet.empty(2),
        selection: const NoteSelection.collapsed(0),
        event: TransactionEvent.inputIme,
        addToHistory: false,
        time: const Duration(milliseconds: 20),
      ),
    );
    expect(_history(cleared).undoDepth, 0);
    expect(_history(cleared).redoDepth, 1);
    expect(cleared.redo().source, 'cab');
  });

  test('a pending composition blocks redo until it is finalized', () {
    final EditorState undone = _type(_start(''), 'a', 0).undo();
    final EditorState composing = undone.apply(
      Transaction(
        changes: ChangeSet.single(0, 0, 0, 'n'),
        selection: const NoteSelection.collapsed(1),
        event: TransactionEvent.inputIme,
        composing: const MdRange(0, 1),
        addToHistory: false,
        time: const Duration(milliseconds: 100),
      ),
    );
    expect(composing.history.canRedo, isFalse);
    expect(composing.history.redo(composing), isNull);
  });

  test('a committed ime edit without a composing phase is recorded', () {
    Transaction commit(int ms) => Transaction(
      changes: ChangeSet.single(1, 1, 1, 'hi'),
      selection: const NoteSelection.collapsed(3),
      event: TransactionEvent.inputIme,
      addToHistory: false,
      time: Duration(milliseconds: ms),
    );
    final EditorState typed = _type(_start(''), 'a', 0);
    final EditorState joined = typed.apply(commit(10));
    expect(joined.source, 'ahi');
    expect(_history(joined).undoDepth, 1);
    expect(joined.undo().source, '');
    final EditorState apart = typed.apply(commit(700));
    expect(_history(apart).undoDepth, 2);
    expect(apart.undo().source, 'a');
  });

  test('a blur records the net change and an empty net records nothing', () {
    final EditorState composing = _start('').apply(
      Transaction(
        changes: ChangeSet.single(0, 0, 0, 'k'),
        selection: const NoteSelection.collapsed(1),
        event: TransactionEvent.inputIme,
        composing: const MdRange(0, 1),
        addToHistory: false,
        time: const Duration(milliseconds: 10),
      ),
    );
    final EditorState blurred = composing.apply(
      Transaction(
        changes: ChangeSet.empty(1),
        selection: const NoteSelection.collapsed(1),
        event: TransactionEvent.inputIme,
        addToHistory: false,
        time: const Duration(milliseconds: 20),
      ),
    );
    expect(_history(blurred).undoDepth, 1);
    expect(blurred.undo().source, '');

    final EditorState withdrawn = composing
        .apply(
          Transaction(
            changes: ChangeSet.single(1, 0, 1, ''),
            selection: const NoteSelection.collapsed(0),
            event: TransactionEvent.inputIme,
            composing: const MdRange(0, 0),
            addToHistory: false,
            time: const Duration(milliseconds: 20),
          ),
        )
        .apply(
          Transaction(
            changes: ChangeSet.empty(0),
            selection: const NoteSelection.collapsed(0),
            event: TransactionEvent.inputIme,
            addToHistory: false,
            time: const Duration(milliseconds: 30),
          ),
        );
    expect(_history(withdrawn).undoDepth, 0);
    expect(withdrawn.history.canUndo, isFalse);
  });

  test('an outside change that swallows an entry drops it', () {
    final EditorState typed = _type(
      _type(_start('ab', selection: const NoteSelection.collapsed(2)), 'c', 0),
      'd',
      1000,
    );
    expect(_history(typed).undoDepth, 2);
    final EditorState swallowed = _outside(
      typed,
      ChangeSet.single(4, 1, 4, ''),
      1,
    );
    expect(swallowed.source, 'a');
    expect(_history(swallowed).undoDepth, 0);
    expect(swallowed.history.canUndo, isFalse);
  });

  test('record returns a new history and leaves the old one unchanged', () {
    final EditorState state = _start('');
    final NoteHistory before = _history(state);
    final EditorState typed = _type(state, 'a', 0);
    final NoteHistory after = _history(typed);
    expect(identical(before, after), isFalse);
    expect(before.undoDepth, 0);
    expect(before.canUndo, isFalse);
    expect(after.undoDepth, 1);
  });

  test('undo and redo survive random changes outside history', () {
    for (int i = 0; i < 300; i++) {
      final Random random = Random(20260923 + i);
      final String note = _randomNote(random);
      EditorState state = _start(
        note,
        selection: NoteSelection.collapsed(random.nextInt(note.length + 1)),
      );
      int ms = 0;
      final int steps = 1 + random.nextInt(30);
      for (int s = 0; s < steps; s++) {
        ms += random.nextInt(800);
        state = _randomStep(random, state, ms);
      }
      final String edited = state.source;
      int guard = 0;
      while (state.history.canUndo) {
        state = state.undo();
        guard += 1;
        expect(guard, lessThanOrEqualTo(steps + 1));
      }
      while (state.history.canRedo) {
        state = state.redo();
      }
      expect(state.source, edited, reason: 'seed ${20260923 + i}');
    }
  });
}
