import 'dart:math';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/history.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:flutter/widgets.dart' show CharacterRange;
import 'package:flutter_test/flutter_test.dart';

import '../../../support/note_generators.dart';

const int _sequenceCount = 10000;

const int _undoLimit = 1000;

MdTree _incremental(
  EditorState previous,
  Transaction transaction,
  String source,
) {
  final ChangeSet changes = transaction.changes;
  final MdEdit edit;
  if (changes.isEmpty) {
    final int at =
        previous.composing?.start ?? transaction.composing?.start ?? 0;
    edit = MdEdit(start: at, end: at, inserted: '');
  } else {
    final int start = changes.replacements.first.from;
    final int oldEnd = changes.replacements.last.to;
    final int newEnd = oldEnd + (source.length - previous.source.length);
    edit = MdEdit(
      start: start,
      end: oldEnd,
      inserted: source.substring(start, newEnd),
    );
  }
  return const MdIncrementalParser()
      .reparse(
        previous.tree,
        previous.source,
        source,
        edit,
        composing: transaction.composing,
        previousComposing: previous.composing,
      )
      .tree;
}

MdTree _flat(String source) =>
    MdTree(sourceLength: source.length, blocks: const <MdBlock>[]);

String _shown(String text) => text
    .replaceAll('\\', r'\\')
    .replaceAll('\r', r'\r')
    .replaceAll('\n', r'\n')
    .replaceAll('\t', r'\t');

void _checkTree(EditorState state, int i, String note, String phase, int step) {
  if (state.composing != null) {
    return;
  }
  final MdTree full = parseNoteTree(state.source);
  if (state.tree != full) {
    fail(
      'sequence $i, $phase step $step: incremental tree differs from a full '
      'parse\nnote: ${_shown(note)}\nsource: ${_shown(state.source)}\n'
      'incremental: ${state.tree}\nfull: $full',
    );
  }
}

List<String> _trace(int seed) {
  final Random random = Random(seed);
  final String note = randomNote(random);
  EditorState state = EditorState.create(
    note,
    parse: _flat,
    selection: randomSelection(random, note),
    history: const NoteHistory(),
  );
  final List<String> trace = <String>[
    note,
    '${state.selection}',
    '${randomEdit(random, note)}',
  ];
  for (int step = 0; step < 30; step++) {
    final Transaction transaction = randomTransaction(
      random,
      state,
      time: Duration(milliseconds: step * 100),
    );
    state = state.apply(transaction);
    trace.add('$transaction');
  }
  return trace;
}

Set<int> _boundaries(String source) {
  final CharacterRange range = CharacterRange(source);
  final Set<int> result = <int>{0};
  while (range.moveNext()) {
    result.add(source.length - range.stringAfterLength);
  }
  return result;
}

bool _anyBlock(List<MdBlock> blocks, bool Function(MdBlock block) test) =>
    blocks.any((MdBlock block) => test(block) || _anyBlock(block.blocks, test));

int _cells(String row) {
  int count = 0;
  for (int i = 0; i < row.length; i++) {
    if (row.codeUnitAt(i) == 0x7C &&
        (i == 0 || row.codeUnitAt(i - 1) != 0x5C)) {
      count += 1;
    }
  }
  return count - 1;
}

void main() {
  test(
    'undo to the start and redo to the end reproduce the sources byte for byte',
    () {
      for (int i = 0; i < _sequenceCount; i++) {
        final Random random = Random(noteGeneratorSeed + i);
        final String note = randomNote(random);
        EditorState state = EditorState.create(
          note,
          parse: (String s) => parseNoteTree(s),
          update: _incremental,
          selection: randomSelection(random, note),
          history: const NoteHistory(),
        );
        final int edits = 1 + random.nextInt(50);
        Duration time = Duration.zero;
        for (int step = 0; step < edits; step++) {
          time += Duration(milliseconds: random.nextInt(700));
          if (state.composing == null && random.nextInt(10) == 0) {
            state = state.withSelection(randomSelection(random, state.source));
          }
          state = state.apply(randomTransaction(random, state, time: time));
          _checkTree(state, i, note, 'edit', step);
        }
        if (state.composing != null) {
          state = state.apply(
            Transaction(
              changes: ChangeSet.empty(state.source.length),
              selection: state.selection,
              event: TransactionEvent.inputIme,
              addToHistory: false,
            ),
          );
          _checkTree(state, i, note, 'commit', edits);
        }
        final String edited = state.source;
        int undos = 0;
        while (state.history.canUndo) {
          if (undos == _undoLimit) {
            fail(
              'sequence $i: more than $_undoLimit undos\n'
              'note: ${_shown(note)}',
            );
          }
          state = state.undo();
          undos += 1;
          _checkTree(state, i, note, 'undo', undos);
        }
        if (state.source != note) {
          fail(
            'sequence $i: undo to the start after $undos undos\n'
            'note: ${_shown(note)}\nsource: ${_shown(state.source)}',
          );
        }
        int redos = 0;
        while (state.history.canRedo) {
          state = state.redo();
          redos += 1;
          _checkTree(state, i, note, 'redo', redos);
        }
        if (state.source != edited) {
          fail(
            'sequence $i: redo to the end after $redos redos\n'
            'note: ${_shown(note)}\nedited: ${_shown(edited)}\n'
            'source: ${_shown(state.source)}',
          );
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test('the same seed yields the same notes, edits and transactions', () {
    for (int i = 0; i < 200; i++) {
      expect(_trace(noteGeneratorSeed + i), _trace(noteGeneratorSeed + i));
    }
    expect(_trace(noteGeneratorSeed), isNot(_trace(noteGeneratorSeed + 1)));
  });

  test('randomBoundary never splits a cluster or a CRLF', () {
    final Random random = Random(noteGeneratorSeed);
    for (int i = 0; i < 1000; i++) {
      final String note = randomNote(random);
      final Set<int> boundaries = _boundaries(note);
      for (int k = 0; k < 20; k++) {
        final int at = randomBoundary(random, note);
        expect(boundaries, contains(at), reason: 'note $i: ${_shown(note)}');
        expect(
          at > 0 &&
              at < note.length &&
              note.codeUnitAt(at - 1) == 0x0D &&
              note.codeUnitAt(at) == 0x0A,
          isFalse,
          reason: 'note $i splits a CRLF at $at',
        );
      }
    }
  });

  test('randomEdit returns change sets whose length equals the source', () {
    final Random random = Random(noteGeneratorSeed);
    for (int i = 0; i < 1000; i++) {
      final String note = randomNote(random);
      final Set<int> boundaries = _boundaries(note);
      final ChangeSet changes = randomEdit(random, note);
      expect(changes.length, note.length);
      expect(changes.apply(note).length, changes.newLength);
      for (final TextReplacement r in changes.replacements) {
        expect(boundaries, contains(r.from));
        expect(boundaries, contains(r.to));
      }
    }
  });

  test('randomTransaction keeps history flags and ranges valid', () {
    final Set<TransactionEvent> seen = <TransactionEvent>{};
    for (int i = 0; i < 500; i++) {
      final Random random = Random(noteGeneratorSeed + i);
      final String note = randomNote(random);
      EditorState state = EditorState.create(
        note,
        parse: _flat,
        selection: randomSelection(random, note),
        history: const NoteHistory(),
      );
      for (int step = 0; step < 50; step++) {
        final Transaction transaction = randomTransaction(
          random,
          state,
          time: Duration(milliseconds: step * 300),
        );
        final bool composes =
            state.composing != null || transaction.composing != null;
        final int length = transaction.changes.newLength;
        seen.add(transaction.event);
        expect(transaction.event, isNot(TransactionEvent.restore));
        expect(transaction.changes.length, state.source.length);
        expect(transaction.addToHistory, !composes);
        if (composes) {
          expect(transaction.event, TransactionEvent.inputIme);
        }
        expect(transaction.selection.end, lessThanOrEqualTo(length));
        final MdRange? composing = transaction.composing;
        if (composing != null) {
          expect(composing.end, lessThanOrEqualTo(length));
          expect(composing.isEmpty, isFalse);
        }
        state = state.apply(transaction);
      }
    }
    expect(
      seen,
      containsAll(<TransactionEvent>[
        TransactionEvent.inputType,
        TransactionEvent.inputDelete,
        TransactionEvent.inputIme,
        TransactionEvent.format,
        TransactionEvent.external,
      ]),
    );
  });

  test('the first 500 notes reach every construct and edge case', () {
    final Set<String> reached = <String>{};
    for (int i = 0; i < 500; i++) {
      final String note = randomNote(Random(noteGeneratorSeed + i));
      final MdTree tree = parseNoteTree(note);
      final List<MdBlock> blocks = tree.blocks;
      if (note.isEmpty) {
        reached.add('empty note');
      }
      if (note.contains('\r\n')) {
        reached.add('CRLF');
      }
      if (RegExp('\r(?!\n)').hasMatch(note)) {
        reached.add('lone CR');
      }
      if (note.contains('\u00A0')) {
        reached.add('NBSP');
      }
      if (note.contains('\u200D')) {
        reached.add('ZWJ sequence');
      }
      if (note.contains('\u{1F1EB}\u{1F1F7}')) {
        reached.add('flag');
      }
      if (note.contains('\u{1F3FD}')) {
        reached.add('skin tone');
      }
      for (final MdBlock block in blocks) {
        final MdBlockData? data = block.data;
        if (data is MdHeadingData) {
          reached.add('heading ${data.level}');
        }
        if (data is MdFenceData && !data.isClosed) {
          reached.add('unclosed fence');
        }
        final String text = block.sourceRange.sliceOf(note);
        if (text.contains('](photo/')) {
          switch (block.kind) {
            case MdBlockKind.fencedCode:
              reached.add('photo in code');
            case MdBlockKind.blockQuote:
              reached.add('photo in quote');
            case MdBlockKind.bulletList || MdBlockKind.orderedList:
              reached.add('photo in list item');
            case _:
              break;
          }
        }
        if (block.kind == MdBlockKind.photoLine) {
          reached.add('photo line');
        }
        if (block.kind == MdBlockKind.table) {
          reached.add('table');
          final List<int> counts = <int>[
            for (final MdBlock row in block.blocks)
              _cells(row.sourceRange.sliceOf(note).trim()),
          ];
          if (counts.skip(1).any((int c) => c < counts.first)) {
            reached.add('table row with fewer cells');
          }
          if (counts.skip(1).any((int c) => c > counts.first)) {
            reached.add('table row with more cells');
          }
        }
      }
      for (int b = 1; b < blocks.length; b++) {
        if (blocks[b - 1].kind == MdBlockKind.photoLine &&
            blocks[b].kind == MdBlockKind.photoLine) {
          reached.add('consecutive photo lines');
        }
      }
      if (_anyBlock(blocks, (MdBlock block) {
        final MdBlockData? data = block.data;
        return data is MdListItemData && data.taskState == MdTaskState.checked;
      })) {
        reached.add('checked task');
      }
    }
    expect(
      reached,
      containsAll(<String>[
        for (int level = 1; level <= 6; level++) 'heading $level',
        'checked task',
        'table',
        'table row with fewer cells',
        'table row with more cells',
        'photo line',
        'consecutive photo lines',
        'photo in code',
        'photo in quote',
        'photo in list item',
        'unclosed fence',
        'CRLF',
        'lone CR',
        'NBSP',
        'ZWJ sequence',
        'flag',
        'skin tone',
        'empty note',
      ]),
    );
  });
}
