import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/input/delta_mapping.dart';
import 'package:field_notes/features/note_engine/input/delta_mirror.dart';
import 'package:field_notes/features/note_engine/projection/active_line.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const NoteVisibleProjector _projector = NoteVisibleProjector();

EditorState _caret(String source, int offset) => EditorState.create(
  source,
  parse: parseNoteTree,
  selection: NoteSelection.collapsed(offset),
);

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

KnownValue _known(EditorState state, int version) {
  final VisibleText visible = _visibleOf(state);
  return KnownValue(
    value: TextEditingValue(
      text: visible.text,
      selection: visibleSelectionFor(
        visible: visible,
        selection: state.selection,
        windowBase: 0,
      ),
    ),
    state: state,
    visible: visible,
    windowBase: 0,
    version: version,
  );
}

TextEditingDeltaInsertion _insert(
  String oldText,
  int offset,
  String text, {
  TextRange composing = TextRange.empty,
}) => TextEditingDeltaInsertion(
  oldText: oldText,
  textInserted: text,
  insertionOffset: offset,
  selection: TextSelection.collapsed(offset: offset + text.length),
  composing: composing,
);

TextEditingDeltaDeletion _delete(String oldText, int start, int end) =>
    TextEditingDeltaDeletion(
      oldText: oldText,
      deletedRange: TextRange(start: start, end: end),
      selection: TextSelection.collapsed(offset: start),
      composing: TextRange.empty,
    );

({DeltaMirror mirror, MirrorStep step}) _step(
  DeltaMirror mirror,
  TextEditingDelta delta,
  EditorState current,
) => mirror.step(delta, current: current, localSelection: current.selection);

Transaction _rebased(MirrorStep step) {
  expect(step, isA<RebasedDelta>());
  return (step as RebasedDelta).transaction;
}

EditorState _numbered(int i) {
  final String source = 'value $i';
  return _caret(source, source.length);
}

ChangeSet _renumber(int from, int to) {
  final int length = 'value $from'.length;
  return ChangeSet.single(length, 6, length, '$to');
}

DeltaMirror _sentNumbered(int count) {
  DeltaMirror mirror = const DeltaMirror.empty();
  for (int i = 0; i < count; i++) {
    if (i > 0) {
      mirror = mirror.recordSourceChange(_renumber(i - 1, i));
    }
    mirror = mirror.recordSent(_known(_numbered(i), i));
  }
  return mirror;
}

void main() {
  test('a stale delta matching a recent sent value is rebased not dropped', () {
    final EditorState s0 = _caret('- a', 3);
    final KnownValue sent = _known(s0, 0);
    expect(sent.value.text, '- a');
    DeltaMirror mirror = const DeltaMirror.empty().recordSent(sent);

    final ({DeltaMirror mirror, MirrorStep step}) first = _step(
      mirror,
      _insert('- a', 3, '\n'),
      s0,
    );
    expect(first.step, isA<CurrentDelta>());
    expect((first.step as CurrentDelta).against, same(sent));
    expect(first.mirror.value.text, '- a\n');

    final ChangeSet enter = ChangeSet.single(3, 3, 3, '\n- ');
    final EditorState s1 = s0.apply(
      Transaction(
        changes: enter,
        selection: const NoteSelection.collapsed(6),
        event: TransactionEvent.list,
      ),
    );
    expect(s1.source, '- a\n- ');
    mirror = first.mirror.recordSourceChange(enter).recordSent(_known(s1, 1));

    final ({DeltaMirror mirror, MirrorStep step}) second = _step(
      mirror,
      _insert('- a\n', 4, 'b'),
      s1,
    );
    final Transaction transaction = _rebased(second.step);
    expect(
      transaction.changes,
      ChangeSet(
        length: 6,
        replacements: const <TextReplacement>[TextReplacement(6, 6, 'b')],
      ),
    );
    expect(transaction.selection, const NoteSelection.collapsed(7));
    expect(s1.apply(transaction).source, '- a\n- b');
    expect(second.mirror.drops, isEmpty);
  });

  test('a delta matching no sent value is dropped and recorded', () {
    final DeltaMirror mirror = const DeltaMirror.empty().recordSent(
      _known(_caret('hello', 5), 0),
    );
    final ({DeltaMirror mirror, MirrorStep step}) result = _step(
      mirror,
      _insert('help', 4, '!'),
      _caret('hello', 5),
    );
    expect(result.step, isA<DroppedDelta>());
    expect(
      (result.step as DroppedDelta).drop,
      const DeltaDrop(
        reason: DeltaDropReason.noMatchingValue,
        oldText: 'help',
        version: 0,
      ),
    );
    expect(result.mirror.drops, hasLength(1));
    expect(result.mirror.value.text, 'hello');
  });

  test('the mirror keeps the last sixteen sent values', () {
    final DeltaMirror mirror = _sentNumbered(17);
    expect(mirror.knownValues, hasLength(16));
    expect(mirror.knownValues.first.value.text, 'value 16');
    expect(mirror.knownValues.last.value.text, 'value 1');

    final EditorState current = _numbered(16);
    final ({DeltaMirror mirror, MirrorStep step}) evicted = _step(
      mirror,
      _insert('value 0', 7, 'x'),
      current,
    );
    expect(evicted.step, isA<DroppedDelta>());
    expect(
      (evicted.step as DroppedDelta).drop.reason,
      DeltaDropReason.noMatchingValue,
    );

    final ({DeltaMirror mirror, MirrorStep step}) oldest = _step(
      mirror,
      _insert('value 1', 7, 'x'),
      current,
    );
    expect(current.apply(_rebased(oldest.step)).source, 'value 16x');
  });

  test('a full value is reduced to a minimal edit', () {
    final DeltaMirror words = const DeltaMirror.empty().recordSent(
      _known(_caret('hello world', 11), 0),
    );
    final TextEditingDelta insertion = words.reduceFullValue(
      const TextEditingValue(
        text: 'hello brave world',
        selection: TextSelection.collapsed(offset: 17),
      ),
    );
    expect(insertion, isA<TextEditingDeltaInsertion>());
    final TextEditingDeltaInsertion inserted =
        insertion as TextEditingDeltaInsertion;
    expect(inserted.oldText, 'hello world');
    expect(inserted.textInserted, 'brave ');
    expect(inserted.insertionOffset, 6);
    expect(inserted.selection, const TextSelection.collapsed(offset: 12));

    const String medium = 'a\u{1F44D}\u{1F3FD}b';
    const String dark = 'a\u{1F44D}\u{1F3FF}b';
    final DeltaMirror emoji = const DeltaMirror.empty().recordSent(
      _known(_caret(medium, 6), 0),
    );
    final TextEditingDelta replacement = emoji.reduceFullValue(
      const TextEditingValue(
        text: dark,
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    expect(replacement, isA<TextEditingDeltaReplacement>());
    final TextEditingDeltaReplacement replaced =
        replacement as TextEditingDeltaReplacement;
    expect(replaced.oldText, medium);
    expect(replaced.replacedRange, const TextRange(start: 1, end: 5));
    expect(replaced.replacementText, '\u{1F44D}\u{1F3FF}');
    expect(replaced.selection, const TextSelection.collapsed(offset: 5));

    final TextEditingDelta moved = words.reduceFullValue(
      const TextEditingValue(
        text: 'hello world',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    expect(moved, isA<TextEditingDeltaNonTextUpdate>());
    expect(moved.selection, const TextSelection.collapsed(offset: 3));
  });

  test('a caret update at the local offset keeps the local affinity', () {
    final EditorState state = _caret('hello', 5);
    final DeltaMirror mirror = const DeltaMirror.empty().recordSent(
      _known(state, 0),
    );
    final ({DeltaMirror mirror, MirrorStep step}) result = mirror.step(
      const TextEditingDeltaNonTextUpdate(
        oldText: 'hello',
        selection: TextSelection.collapsed(
          offset: 5,
          affinity: TextAffinity.upstream,
        ),
        composing: TextRange.empty,
      ),
      current: state,
      localSelection: const NoteSelection.collapsed(5),
    );
    expect(result.step, isA<KeptAffinity>());
    expect(result.mirror.value.selection.affinity, TextAffinity.downstream);
    expect(result.mirror.value.selection.baseOffset, 5);
  });

  test('a batch of ordinary deltas matches the derived values in turn', () {
    final EditorState state = _caret('teh', 3);
    final DeltaMirror mirror = const DeltaMirror.empty().recordSent(
      _known(state, 0),
    );
    final ({DeltaMirror mirror, MirrorStep step}) cleared = _step(
      mirror,
      _delete('teh', 0, 3),
      state,
    );
    expect(cleared.step, isA<CurrentDelta>());
    expect(cleared.mirror.value.text, '');

    final ({DeltaMirror mirror, MirrorStep step}) typed = _step(
      cleared.mirror,
      _insert('', 0, 'the'),
      state,
    );
    expect(typed.step, isA<CurrentDelta>());
    final KnownValue against = (typed.step as CurrentDelta).against;
    expect(against.value.text, '');
    expect(against.platformEdits, hasLength(1));
    expect(typed.mirror.derivedValues, hasLength(2));
    expect(typed.mirror.value.text, 'the');
  });

  test('a delta on the mirror after a source change is rebased', () {
    final EditorState before = _caret('hello', 5);
    final ChangeSet prefix = ChangeSet.single(5, 0, 0, 'ab ');
    final EditorState current = _caret('ab hello', 8);
    final DeltaMirror mirror = const DeltaMirror.empty()
        .recordSent(_known(before, 0))
        .recordSourceChange(prefix);
    expect(mirror.value.text, 'hello');
    final ({DeltaMirror mirror, MirrorStep step}) result = _step(
      mirror,
      _insert('hello', 5, '!'),
      current,
    );
    final Transaction transaction = _rebased(result.step);
    expect(current.apply(transaction).source, 'ab hello!');
    expect(transaction.selection, const NoteSelection.collapsed(9));
  });

  test(
    'a chain of two platform-derived values maps back to the projection',
    () {
      final EditorState state = _caret('abc', 3);
      final DeltaMirror sent = const DeltaMirror.empty().recordSent(
        _known(state, 0),
      );
      final DeltaMirror first = _step(
        sent,
        _insert('abc', 1, 'X'),
        state,
      ).mirror;
      final DeltaMirror second = _step(
        first,
        _insert('aXbc', 3, 'Y'),
        state,
      ).mirror;
      expect(second.value.text, 'aXbYc');
      expect(second.derivedValues.first.platformEdits, hasLength(2));
      final DeltaMirror changed = second
          .recordSourceChange(ChangeSet.single(3, 1, 1, 'X'))
          .recordSourceChange(ChangeSet.single(4, 3, 3, 'Y'));
      final EditorState current = _caret('aXbYc', 5);
      final ({DeltaMirror mirror, MirrorStep step}) result = _step(
        changed,
        _delete('aXbYc', 2, 3),
        current,
      );
      final Transaction transaction = _rebased(result.step);
      expect(
        transaction.changes,
        ChangeSet(
          length: 5,
          replacements: const <TextReplacement>[TextReplacement(2, 3, '')],
        ),
      );
      expect(current.apply(transaction).source, 'aXYc');
      expect(transaction.selection, const NoteSelection.collapsed(2));
    },
  );

  test('a platform insertion maps an offset inside its text to its end', () {
    final EditorState state = _caret('ab', 2);
    final DeltaMirror sent = const DeltaMirror.empty().recordSent(
      _known(state, 0),
    );
    final DeltaMirror typed = _step(
      sent,
      _insert('ab', 1, 'XYZ'),
      state,
    ).mirror.recordSourceChange(ChangeSet.single(2, 1, 1, 'XYZ'));
    final EditorState current = _caret('aXYZb', 4);
    final ({DeltaMirror mirror, MirrorStep step}) result = _step(
      typed,
      _insert('aXYZb', 2, '-'),
      current,
    );
    final Transaction transaction = _rebased(result.step);
    expect(current.apply(transaction).source, 'aXYZ-b');
  });

  test('a stale deletion is rebased past an earlier logged insertion', () {
    final DeltaMirror mirror = const DeltaMirror.empty()
        .recordSent(_known(_caret('hello world', 11), 0))
        .recordSourceChange(ChangeSet.single(11, 0, 0, 'big '));
    final EditorState current = _caret('big hello world', 15);
    final ({DeltaMirror mirror, MirrorStep step}) result = _step(
      mirror,
      _delete('hello world', 6, 11),
      current,
    );
    final Transaction transaction = _rebased(result.step);
    expect(
      transaction.changes,
      ChangeSet(
        length: 15,
        replacements: const <TextReplacement>[TextReplacement(10, 15, '')],
      ),
    );
    expect(current.apply(transaction).source, 'big hello ');
    expect(transaction.selection, const NoteSelection.collapsed(10));
    expect(transaction.event, TransactionEvent.inputDelete);
  });

  test('a stale replacement keeps a selection after its inserted text', () {
    final DeltaMirror mirror = const DeltaMirror.empty()
        .recordSent(_known(_caret('cat dog', 7), 0))
        .recordSourceChange(ChangeSet.single(7, 0, 0, 'my '));
    final EditorState current = _caret('my cat dog', 10);
    final ({DeltaMirror mirror, MirrorStep step}) result = _step(
      mirror,
      const TextEditingDeltaReplacement(
        oldText: 'cat dog',
        replacementText: 'cow',
        replacedRange: TextRange(start: 0, end: 3),
        selection: TextSelection.collapsed(offset: 7),
        composing: TextRange.empty,
      ),
      current,
    );
    final Transaction transaction = _rebased(result.step);
    expect(current.apply(transaction).source, 'my cow dog');
    expect(transaction.selection, const NoteSelection.collapsed(10));
  });

  test(
    'a stale selection update is rebased as a selection-only transaction',
    () {
      final DeltaMirror mirror = const DeltaMirror.empty()
          .recordSent(_known(_caret('hello', 5), 0))
          .recordSourceChange(ChangeSet.single(5, 0, 0, 'ab '));
      final EditorState current = _caret('ab hello', 8);

      final Transaction composing = _rebased(
        _step(
          mirror,
          const TextEditingDeltaNonTextUpdate(
            oldText: 'hello',
            selection: TextSelection.collapsed(offset: 3),
            composing: TextRange(start: 1, end: 3),
          ),
          current,
        ).step,
      );
      expect(composing.changes, ChangeSet.empty(8));
      expect(composing.event, TransactionEvent.inputIme);
      expect(composing.addToHistory, isFalse);
      expect(composing.composing, const MdRange(4, 6));
      expect(composing.selection, const NoteSelection.collapsed(6));

      final Transaction plain = _rebased(
        _step(
          mirror,
          const TextEditingDeltaNonTextUpdate(
            oldText: 'hello',
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange.empty,
          ),
          current,
        ).step,
      );
      expect(plain.changes, ChangeSet.empty(8));
      expect(plain.event, TransactionEvent.inputType);
      expect(plain.addToHistory, isFalse);
      expect(plain.composing, isNull);
      expect(plain.selection, const NoteSelection.collapsed(5));
    },
  );

  test('derived values never take a known projection slot', () {
    DeltaMirror mirror = _sentNumbered(16);
    final List<KnownValue> known = mirror.knownValues;
    final EditorState current = _numbered(15);
    for (int i = 0; i < 20; i++) {
      final String text = mirror.value.text;
      mirror = _step(mirror, _insert(text, text.length, 'x'), current).mirror;
    }
    expect(mirror.derivedValues, hasLength(20));
    expect(mirror.knownValues, hasLength(16));
    for (int i = 0; i < 16; i++) {
      expect(mirror.knownValues[i], same(known[i]));
    }
  });

  test('the change log is trimmed to the oldest known projection', () {
    final DeltaMirror kept = _sentNumbered(16);
    final EditorState first = _numbered(0);
    final EditorState current = _numbered(15);
    final DeltaMirror full = kept.recordSent(_known(first, 0));
    final ({DeltaMirror mirror, MirrorStep step}) inReach = _step(
      full,
      _insert('value 0', 7, 'x'),
      current,
    );
    expect(current.apply(_rebased(inReach.step)).source, 'value 15x');

    final DeltaMirror trimmed = _sentNumbered(17).recordSent(_known(first, 0));
    final ({DeltaMirror mirror, MirrorStep step}) outOfReach = _step(
      trimmed,
      _insert('value 0', 7, 'x'),
      _numbered(16),
    );
    expect(
      (outOfReach.step as DroppedDelta).drop,
      const DeltaDrop(
        reason: DeltaDropReason.rebaseOutOfRange,
        oldText: 'value 0',
        version: 16,
      ),
    );
    expect(outOfReach.mirror.drops, hasLength(1));
  });

  test('a change log that does not chain drops the stale delta', () {
    final DeltaMirror mirror = const DeltaMirror.empty()
        .recordSent(_known(_caret('hello', 5), 0))
        .recordSourceChange(ChangeSet.single(9, 0, 0, 'ab '));
    final EditorState current = _caret('ab hello', 8);
    final ({DeltaMirror mirror, MirrorStep step}) result = _step(
      mirror,
      _insert('hello', 5, '!'),
      current,
    );
    expect(result.step, isA<DroppedDelta>());
    expect(
      (result.step as DroppedDelta).drop,
      const DeltaDrop(
        reason: DeltaDropReason.rebaseOutOfRange,
        oldText: 'hello',
        version: 1,
      ),
    );
    expect(result.mirror.drops, hasLength(1));
  });

  test('a full value never splits a checkbox object', () {
    final EditorState state = _caret('- [ ] milk\nnext', 15);
    final KnownValue sent = _known(state, 0);
    expect(sent.value.text, '☐ milk\nnext');
    expect(sent.value.text.length, 11);
    final DeltaMirror mirror = const DeltaMirror.empty().recordSent(sent);
    final TextEditingDelta delta = mirror.reduceFullValue(
      const TextEditingValue(
        text: ' milk\nnext',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    expect(delta, isA<TextEditingDeltaReplacement>());
    final TextEditingDeltaReplacement replaced =
        delta as TextEditingDeltaReplacement;
    expect(replaced.replacedRange, const TextRange(start: 0, end: 2));
    expect(replaced.replacementText, ' ');
    expect(replaced.selection, const TextSelection.collapsed(offset: 1));
  });

  test('differsFrom compares text, selection and composing', () {
    final DeltaMirror mirror = const DeltaMirror.empty().recordSent(
      _known(_caret('hello', 5), 0),
    );
    const TextEditingValue same = TextEditingValue(
      text: 'hello',
      selection: TextSelection.collapsed(offset: 5),
    );
    expect(mirror.differsFrom(same), isFalse);
    expect(mirror.differsFrom(same.copyWith(text: 'hellp')), isTrue);
    expect(
      mirror.differsFrom(
        same.copyWith(selection: const TextSelection.collapsed(offset: 4)),
      ),
      isTrue,
    );
    expect(
      mirror.differsFrom(
        same.copyWith(composing: const TextRange(start: 0, end: 5)),
      ),
      isTrue,
    );
  });
}
