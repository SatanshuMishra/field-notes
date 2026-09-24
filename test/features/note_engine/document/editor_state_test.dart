import 'dart:ui' show TextAffinity;

import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

final RegExp _photoLine = RegExp(r'^!\[([^\]]*)\]\(photo/([0-9a-fA-F]+)\)$');

MdTree _fakeParse(String source) {
  final List<MdBlock> blocks = <MdBlock>[];
  int lineStart = 0;
  while (lineStart <= source.length) {
    final int lineFeed = source.indexOf('\n', lineStart);
    final int lineBreak = lineFeed < 0 ? source.length : lineFeed;
    final int lineEnd =
        lineFeed >= 0 &&
            lineBreak > lineStart &&
            source.codeUnitAt(lineBreak - 1) == 0x0D
        ? lineBreak - 1
        : lineBreak;
    final String line = source.substring(lineStart, lineEnd);
    final RegExpMatch? match = _photoLine.firstMatch(line);
    final MdRange lineRange = MdRange(lineStart, lineEnd);
    if (match != null) {
      final String caption = match.group(1)!;
      final String reference = match.group(2)!;
      final MdRange captionRange = MdRange(
        lineStart + 2,
        lineStart + 2 + caption.length,
      );
      final int referenceStart = captionRange.end + 8;
      blocks.add(
        MdBlock(
          kind: MdBlockKind.photoLine,
          sourceRange: lineRange,
          contentRange: captionRange,
          markerRanges: <MdRange>[
            MdRange(lineStart, captionRange.start),
            MdRange(captionRange.end, lineEnd),
          ],
          data: MdPhotoLineData(
            reference: reference,
            referenceRange: MdRange(
              referenceStart,
              referenceStart + reference.length,
            ),
            caption: caption,
            captionRange: captionRange,
            title: null,
            titleRange: null,
          ),
        ),
      );
    } else if (line.isNotEmpty) {
      blocks.add(
        MdBlock(
          kind: MdBlockKind.paragraph,
          sourceRange: lineRange,
          contentRange: lineRange,
        ),
      );
    }
    if (lineFeed < 0) {
      break;
    }
    lineStart = lineFeed + 1;
  }
  return MdTree(sourceLength: source.length, blocks: blocks);
}

final class _RecordingHistory implements HistoryPort {
  const _RecordingHistory({
    this.records = const <(EditorState, Transaction)>[],
    this.closed = 0,
    this.undoStep,
    this.redoStep,
  });

  final List<(EditorState, Transaction)> records;
  final int closed;
  final HistoryStep? undoStep;
  final HistoryStep? redoStep;

  @override
  bool get canUndo => undoStep != null;

  @override
  bool get canRedo => redoStep != null;

  @override
  HistoryPort record(EditorState before, Transaction transaction) =>
      _RecordingHistory(
        records: <(EditorState, Transaction)>[
          ...records,
          (before, transaction),
        ],
        closed: closed,
        undoStep: undoStep,
        redoStep: redoStep,
      );

  @override
  HistoryPort closeGroup() => _RecordingHistory(
    records: records,
    closed: closed + 1,
    undoStep: undoStep,
    redoStep: redoStep,
  );

  @override
  HistoryStep? undo(EditorState state) => undoStep;

  @override
  HistoryStep? redo(EditorState state) => redoStep;
}

final class _CountingParser {
  int calls = 0;

  MdTree call(String source) {
    calls += 1;
    return _fakeParse(source);
  }
}

EditorState _empty() => EditorState.create('', parse: _fakeParse);

Transaction _restore(String text) =>
    _empty().externalWrite(text, selectionBase: -1, selectionExtent: -1);

void main() {
  test('a transaction yields the next state as a pure function', () {
    const _RecordingHistory history = _RecordingHistory();
    final EditorState state = EditorState.create(
      'abcdef',
      parse: _fakeParse,
      selection: const NoteSelection.collapsed(3),
      history: history,
    );
    final Transaction typing = Transaction(
      changes: ChangeSet.single(6, 3, 3, 'a'),
      selection: const NoteSelection.collapsed(4),
      event: TransactionEvent.inputType,
    );

    final EditorState next = state.apply(typing);

    expect(next.source, 'abcadef');
    expect(next.selection, const NoteSelection.collapsed(4));
    expect(next.tree, _fakeParse('abcadef'));
    final HistoryPort nextHistory = next.history;
    expect(nextHistory, isA<_RecordingHistory>());
    final List<(EditorState, Transaction)> records =
        (nextHistory as _RecordingHistory).records;
    expect(records, hasLength(1));
    expect(identical(records.single.$1, state), isTrue);
    expect(identical(records.single.$2, typing), isTrue);

    expect(state.source, 'abcdef');
    expect(state.selection, const NoteSelection.collapsed(3));
    expect(identical(state.history, history), isTrue);

    final EditorState again = state.apply(typing);
    expect(again.source, next.source);
    expect(again.selection, next.selection);
    expect(again.tree, next.tree);

    expect(TransactionEvent.inputType.label, 'input.type');
    expect(
      () => state.apply(
        Transaction(
          changes: ChangeSet.single(5, 3, 3, 'a'),
          selection: const NoteSelection.collapsed(4),
          event: TransactionEvent.inputType,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('an external write becomes the minimal replacement', () {
    final EditorState fog = EditorState.create(
      'The fog lifted',
      parse: _fakeParse,
      selection: const NoteSelection.collapsed(14),
    );
    final Transaction thick = fog.externalWrite(
      'The thick fog lifted',
      selectionBase: 10,
      selectionExtent: 10,
    );
    expect(
      thick.changes,
      ChangeSet(
        length: 14,
        replacements: const <TextReplacement>[TextReplacement(4, 4, 'thick ')],
      ),
    );
    expect(thick.event, TransactionEvent.external);
    expect(thick.addToHistory, isTrue);
    expect(thick.selection, const NoteSelection.collapsed(10));
    expect(thick.composing, isNull);

    final Transaction repeated = EditorState.create(
      'aa',
      parse: _fakeParse,
    ).externalWrite('aaa', selectionBase: 3, selectionExtent: 3);
    expect(repeated.changes.replacements, const <TextReplacement>[
      TextReplacement(2, 2, 'a'),
    ]);

    final Transaction unchanged = fog.externalWrite(
      'The fog lifted',
      selectionBase: 3,
      selectionExtent: 5,
    );
    expect(unchanged.changes.isEmpty, isTrue);
    expect(unchanged.event, TransactionEvent.external);
    expect(unchanged.addToHistory, isFalse);
    expect(unchanged.selection, const NoteSelection(anchor: 3, head: 5));
  });

  test('an external write never splits a grapheme cluster', () {
    const List<(String, String, TextReplacement)> cases =
        <(String, String, TextReplacement)>[
          ('cafe\u0301!', 'cafe\u0300!', TextReplacement(3, 5, 'e\u0300')),
          (
            'hi \u{1F44D}\u{1F3FD} there',
            'hi \u{1F44D}\u{1F3FF} there',
            TextReplacement(3, 7, '\u{1F44D}\u{1F3FF}'),
          ),
          (
            '\u{1F1EB}\u{1F1F7}',
            '\u{1F1EB}\u{1F1EE}',
            TextReplacement(0, 4, '\u{1F1EB}\u{1F1EE}'),
          ),
        ];
    for (final (String before, String after, TextReplacement expected)
        in cases) {
      final Transaction write = EditorState.create(
        before,
        parse: _fakeParse,
      ).externalWrite(after, selectionBase: 0, selectionExtent: 0);
      expect(write.changes.replacements, <TextReplacement>[expected]);
      expect(write.changes.apply(before), after);
    }
  });

  test('an invalid selection write is a restore transaction', () {
    final Transaction draft = _restore('draft body');
    expect(draft.event, TransactionEvent.restore);
    expect(draft.addToHistory, isFalse);
    expect(
      draft.changes,
      ChangeSet(
        length: 0,
        replacements: const <TextReplacement>[
          TextReplacement(0, 0, 'draft body'),
        ],
      ),
    );
    expect(draft.selection, const NoteSelection.collapsed(10));

    final EditorState recorded = EditorState.create(
      '',
      parse: _fakeParse,
      history: const _RecordingHistory(),
    ).apply(draft);
    final List<(EditorState, Transaction)> records =
        (recorded.history as _RecordingHistory).records;
    expect(records, hasLength(1));
    expect(identical(records.single.$2, draft), isTrue);
    expect(recorded.source, 'draft body');

    final Transaction beyond = _empty().externalWrite(
      'draft body',
      selectionBase: 99,
      selectionExtent: 99,
    );
    expect(beyond.event, TransactionEvent.restore);

    final Map<String, int> carets = <String, int>{
      'Intro\n![p](photo/abc123abc123)': 5,
      'A\n![p](photo/abc123abc123)\n![q](photo/def456def456)': 1,
      'Walk\n\n![p](photo/abc123abc123)': 4,
      'A\n  \n![p](photo/abc123abc123)': 1,
      '![p](photo/abc123abc123)': 0,
      '\n![p](photo/abc123abc123)': 0,
      'Intro\n![p](photo/abc123abc123)\n': 31,
    };
    expect('Intro\n![p](photo/abc123abc123)'.length, 30);
    expect('A\n![p](photo/abc123abc123)\n![q](photo/def456def456)'.length, 51);
    for (final MapEntry<String, int> entry in carets.entries) {
      final Transaction restore = _restore(entry.key);
      expect(restore.event, TransactionEvent.restore, reason: entry.key);
      expect(
        restore.selection,
        NoteSelection.collapsed(entry.value),
        reason: entry.key,
      );
    }
  });

  test('the fake parser builds the photo line ranges exactly', () {
    final MdBlock photo = _fakeParse(
      'Intro\n![p](photo/abc123abc123)',
    ).blocks.last;
    const int o = 6;
    expect(photo.kind, MdBlockKind.photoLine);
    expect(photo.sourceRange, const MdRange(o, o + 24));
    expect(photo.contentRange, const MdRange(o + 2, o + 3));
    expect(photo.markerRanges, const <MdRange>[
      MdRange(o, o + 2),
      MdRange(o + 3, o + 24),
    ]);
    final MdPhotoLineData data = photo.data! as MdPhotoLineData;
    expect(data.referenceRange, const MdRange(o + 11, o + 23));
    expect(data.reference, 'abc123abc123');
  });

  test(
    'a restore on a CRLF note ends the caret before the carriage return',
    () {
      expect(
        _restore('Intro\r\n\r\n![p](photo/abc123abc123)').selection,
        const NoteSelection.collapsed(5),
      );
      expect(_restore('').selection, const NoteSelection.collapsed(0));
    },
  );

  test('a selection reports its start, end and collapse', () {
    const NoteSelection backwards = NoteSelection(anchor: 7, head: 2);
    expect(backwards.start, 2);
    expect(backwards.end, 7);
    expect(backwards.isCollapsed, isFalse);
    expect(const NoteSelection.collapsed(4).isCollapsed, isTrue);
    expect(
      const NoteSelection.collapsed(4),
      isNot(const NoteSelection.collapsed(4, affinity: TextAffinity.upstream)),
    );
    expect(
      const NoteSelection(anchor: 7, head: 2).hashCode,
      backwards.hashCode,
    );

    final ChangeSet insert = ChangeSet.single(11, 5, 5, 'abc');
    expect(
      const NoteSelection(
        anchor: 5,
        head: 6,
        affinity: TextAffinity.upstream,
      ).mapped(insert, side: MapSide.after),
      const NoteSelection(anchor: 8, head: 9, affinity: TextAffinity.upstream),
    );
    expect(
      const NoteSelection.collapsed(5).mapped(insert, side: MapSide.before),
      const NoteSelection.collapsed(5),
    );
  });

  test('a transaction rejects an invalid shape', () {
    final ChangeSet changes = ChangeSet.empty(6);
    expect(
      () => Transaction(
        changes: changes,
        selection: const NoteSelection.collapsed(7),
        event: TransactionEvent.inputType,
      ),
      throwsArgumentError,
    );
    expect(
      () => Transaction(
        changes: changes,
        selection: const NoteSelection.collapsed(0),
        event: TransactionEvent.inputIme,
        composing: const MdRange(4, 7),
      ),
      throwsArgumentError,
    );
    expect(
      () => Transaction(
        changes: changes,
        selection: const NoteSelection.collapsed(0),
        event: TransactionEvent.inputType,
        composing: const MdRange(1, 3),
      ),
      throwsArgumentError,
    );
    expect(
      () => Transaction(
        changes: changes,
        selection: const NoteSelection.collapsed(0),
        event: TransactionEvent.restore,
      ),
      throwsArgumentError,
    );
    expect(
      () => Transaction(
        changes: changes,
        selection: const NoteSelection.collapsed(0),
        event: TransactionEvent.restore,
        addToHistory: false,
        composing: const MdRange(1, 3),
      ),
      throwsArgumentError,
    );
    expect(
      TransactionEvent.values.map((TransactionEvent e) => e.label).toList(),
      <String>[
        'input.type',
        'input.delete',
        'input.ime',
        'input.paste',
        'input.drop',
        'format',
        'list',
        'table',
        'photo',
        'spell',
        'external',
        'restore',
      ],
    );
  });

  test('a selection-only transaction sets composing and reparses', () {
    final _CountingParser parser = _CountingParser();
    final EditorState state = EditorState.create('abcdef', parse: parser.call);
    expect(parser.calls, 1);
    final EditorState composed = state.apply(
      Transaction(
        changes: ChangeSet.empty(6),
        selection: const NoteSelection.collapsed(3),
        composing: const MdRange(1, 3),
        addToHistory: false,
        event: TransactionEvent.inputIme,
      ),
    );
    expect(composed.composing, const MdRange(1, 3));
    expect(composed.source, 'abcdef');
    expect(parser.calls, 2);
    expect(
      () => Transaction(
        changes: ChangeSet.empty(6),
        selection: const NoteSelection.collapsed(3),
        composing: const MdRange(1, 3),
        addToHistory: false,
        event: TransactionEvent.inputType,
      ),
      throwsArgumentError,
    );
  });

  test('the editor state constructor rejects an inconsistent state', () {
    expect(
      () => EditorState(
        source: 'abc',
        selection: const NoteSelection.collapsed(0),
        tree: _fakeParse('ab'),
        parse: _fakeParse,
      ),
      throwsArgumentError,
    );
    expect(
      () => EditorState(
        source: 'abc',
        selection: const NoteSelection(anchor: 1, head: 4),
        tree: _fakeParse('abc'),
        parse: _fakeParse,
      ),
      throwsArgumentError,
    );
    expect(
      () => EditorState(
        source: 'abc',
        selection: const NoteSelection.collapsed(0),
        tree: _fakeParse('abc'),
        parse: _fakeParse,
        composing: const MdRange(2, 4),
      ),
      throwsArgumentError,
    );
    expect(
      () => EditorState(
        source: 'abc',
        selection: const NoteSelection.collapsed(0),
        tree: _fakeParse('abc'),
        parse: _fakeParse,
        activeLine: 1,
      ),
      throwsArgumentError,
    );
  });

  test('withSelection closes the typing group only on a change', () {
    final EditorState state = EditorState.create(
      'abcdef',
      parse: _fakeParse,
      selection: const NoteSelection.collapsed(2),
      history: const _RecordingHistory(),
    );
    final EditorState same = state.withSelection(
      const NoteSelection.collapsed(2),
    );
    expect((same.history as _RecordingHistory).closed, 0);
    final EditorState moved = state.withSelection(
      const NoteSelection(anchor: 1, head: 4),
    );
    expect(moved.selection, const NoteSelection(anchor: 1, head: 4));
    expect((moved.history as _RecordingHistory).closed, 1);
    expect(moved.source, 'abcdef');
    expect(
      () => state.withSelection(const NoteSelection.collapsed(7)),
      throwsArgumentError,
    );
  });

  test(
    'withActiveLine counts a CRLF as one break and a lone CR as content',
    () {
      final EditorState crlf = EditorState.create('a\r\nb', parse: _fakeParse);
      expect(crlf.withActiveLine(1).activeLine, 1);
      expect(crlf.withActiveLine(null).activeLine, isNull);
      expect(() => crlf.withActiveLine(2), throwsArgumentError);
      expect(() => crlf.withActiveLine(-1), throwsArgumentError);
      final EditorState lone = EditorState.create('a\rb', parse: _fakeParse);
      expect(lone.withActiveLine(0).activeLine, 0);
      expect(() => lone.withActiveLine(1), throwsArgumentError);
      final EditorState moved = crlf.withActiveLine(1);
      expect(moved.source, crlf.source);
      expect(moved.selection, crlf.selection);
      expect(identical(moved.tree, crlf.tree), isTrue);
    },
  );

  test('apply keeps or clamps the active line', () {
    final EditorState state = EditorState.create(
      'a\nb\nc',
      parse: _fakeParse,
    ).withActiveLine(2);
    final EditorState shortened = state.apply(
      Transaction(
        changes: ChangeSet.single(5, 1, 5, ''),
        selection: const NoteSelection.collapsed(1),
        event: TransactionEvent.inputDelete,
      ),
    );
    expect(shortened.activeLine, 0);
    final EditorState typed = state.apply(
      Transaction(
        changes: ChangeSet.single(5, 5, 5, 'd'),
        selection: const NoteSelection.collapsed(6),
        event: TransactionEvent.inputType,
      ),
    );
    expect(typed.activeLine, 2);
  });

  test('the update hook replaces parse and neither runs for no change', () {
    final _CountingParser parser = _CountingParser();
    final List<Transaction> updates = <Transaction>[];
    MdTree update(EditorState previous, Transaction t, String source) {
      updates.add(t);
      return _fakeParse(source);
    }

    final EditorState state = EditorState.create(
      'abcdef',
      parse: parser.call,
      update: update,
    );
    final Transaction typing = Transaction(
      changes: ChangeSet.single(6, 6, 6, 'g'),
      selection: const NoteSelection.collapsed(7),
      event: TransactionEvent.inputType,
    );
    final EditorState next = state.apply(typing);
    expect(parser.calls, 1);
    expect(updates, <Transaction>[typing]);
    expect(next.tree, _fakeParse('abcdefg'));
    expect(identical(next.update, state.update), isTrue);

    final EditorState moved = next.apply(
      Transaction(
        changes: ChangeSet.empty(7),
        selection: const NoteSelection.collapsed(2),
        event: TransactionEvent.inputType,
        addToHistory: false,
      ),
    );
    expect(parser.calls, 1);
    expect(updates, hasLength(1));
    expect(identical(moved.tree, next.tree), isTrue);
  });

  test('undo and redo apply the port step and clear composing', () {
    const _RecordingHistory after = _RecordingHistory(closed: 9);
    final HistoryStep undoStep = HistoryStep(
      transaction: Transaction(
        changes: ChangeSet.single(6, 0, 1, ''),
        selection: const NoteSelection.collapsed(0),
        event: TransactionEvent.inputDelete,
      ),
      history: after,
    );
    final HistoryStep redoStep = HistoryStep(
      transaction: Transaction(
        changes: ChangeSet.single(6, 6, 6, 'g'),
        selection: const NoteSelection.collapsed(7),
        event: TransactionEvent.inputType,
      ),
      history: after,
    );
    final EditorState state = EditorState(
      source: 'abcdef',
      selection: const NoteSelection.collapsed(3),
      tree: _fakeParse('abcdef'),
      parse: _fakeParse,
      composing: const MdRange(1, 3),
      history: _RecordingHistory(undoStep: undoStep, redoStep: redoStep),
    );

    final EditorState undone = state.undo();
    expect(undone.source, 'bcdef');
    expect(undone.selection, const NoteSelection.collapsed(0));
    expect(undone.composing, isNull);
    expect(undone.tree, _fakeParse('bcdef'));
    expect(identical(undone.history, after), isTrue);

    final EditorState redone = state.redo();
    expect(redone.source, 'abcdefg');
    expect(redone.selection, const NoteSelection.collapsed(7));
    expect(redone.composing, isNull);
    expect(identical(redone.history, after), isTrue);

    final EditorState plain = EditorState.create('abc', parse: _fakeParse);
    expect(identical(plain.undo(), plain), isTrue);
    expect(identical(plain.redo(), plain), isTrue);
    expect(const NoHistory().canUndo, isFalse);
    expect(const NoHistory().canRedo, isFalse);
  });

  test('a CRLF collapsing to LF replaces the whole cluster', () {
    final Transaction write = EditorState.create(
      'a\r\nb',
      parse: _fakeParse,
    ).externalWrite('a\nb', selectionBase: 2, selectionExtent: 2);
    expect(write.changes.replacements, const <TextReplacement>[
      TextReplacement(1, 3, '\n'),
    ]);
    expect(write.changes.apply('a\r\nb'), 'a\nb');
  });
}
