import 'dart:ui' show TextAffinity;

import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:flutter/widgets.dart' show CharacterRange;

typedef NoteTreeParser = MdTree Function(String source);

typedef NoteTreeUpdate =
    MdTree Function(
      EditorState previous,
      Transaction transaction,
      String source,
    );

abstract interface class HistoryPort {
  bool get canUndo;

  bool get canRedo;

  HistoryPort record(EditorState before, Transaction transaction);

  HistoryPort closeGroup();

  HistoryStep? undo(EditorState state);

  HistoryStep? redo(EditorState state);
}

final class HistoryStep {
  const HistoryStep({required this.transaction, required this.history});

  final Transaction transaction;
  final HistoryPort history;
}

final class NoHistory implements HistoryPort {
  const NoHistory();

  @override
  bool get canUndo => false;

  @override
  bool get canRedo => false;

  @override
  HistoryPort record(EditorState before, Transaction transaction) => this;

  @override
  HistoryPort closeGroup() => this;

  @override
  HistoryStep? undo(EditorState state) => null;

  @override
  HistoryStep? redo(EditorState state) => null;
}

final class EditorState {
  EditorState({
    required this.source,
    required this.selection,
    required this.tree,
    required this.parse,
    this.update,
    this.composing,
    this.activeLine,
    this.history = const NoHistory(),
  }) {
    if (tree.sourceLength != source.length) {
      throw ArgumentError.value(
        tree.sourceLength,
        'tree',
        'source length must be ${source.length}',
      );
    }
    if (selection.end > source.length) {
      throw ArgumentError.value(
        selection,
        'selection',
        'must end within the source length ${source.length}',
      );
    }
    final MdRange? range = composing;
    if (range != null && range.end > source.length) {
      throw ArgumentError.value(
        range,
        'composing',
        'must lie inside the source length ${source.length}',
      );
    }
    final int? line = activeLine;
    if (line != null && (line < 0 || line >= _lineCount(source))) {
      throw ArgumentError.value(
        line,
        'activeLine',
        'must be a line index of the source',
      );
    }
  }

  factory EditorState.create(
    String source, {
    required NoteTreeParser parse,
    NoteTreeUpdate? update,
    NoteSelection selection = const NoteSelection.collapsed(0),
    HistoryPort history = const NoHistory(),
  }) => EditorState(
    source: source,
    selection: selection,
    tree: parse(source),
    parse: parse,
    update: update,
    history: history,
  );

  final String source;
  final NoteSelection selection;
  final MdRange? composing;
  final MdTree tree;
  final int? activeLine;
  final HistoryPort history;
  final NoteTreeParser parse;
  final NoteTreeUpdate? update;

  EditorState apply(Transaction transaction) => _next(
    transaction,
    history: history.record(this, transaction),
    composing: transaction.composing,
  );

  EditorState undo() {
    final HistoryStep? step = history.undo(this);
    return step == null
        ? this
        : _next(step.transaction, history: step.history, composing: null);
  }

  EditorState redo() {
    final HistoryStep? step = history.redo(this);
    return step == null
        ? this
        : _next(step.transaction, history: step.history, composing: null);
  }

  EditorState withSelection(NoteSelection selection) {
    if (selection == this.selection) {
      return this;
    }
    return EditorState(
      source: source,
      selection: selection,
      tree: tree,
      parse: parse,
      update: update,
      composing: composing,
      activeLine: activeLine,
      history: history.closeGroup(),
    );
  }

  EditorState withActiveLine(int? line) => EditorState(
    source: source,
    selection: selection,
    tree: tree,
    parse: parse,
    update: update,
    composing: composing,
    activeLine: line,
    history: history,
  );

  Transaction externalWrite(
    String text, {
    required int selectionBase,
    required int selectionExtent,
    TextAffinity affinity = TextAffinity.downstream,
    Duration time = Duration.zero,
  }) {
    final ChangeSet changes = _minimalChange(source, text);
    final bool isValid =
        selectionBase >= 0 &&
        selectionBase <= text.length &&
        selectionExtent >= 0 &&
        selectionExtent <= text.length;
    if (!isValid) {
      return Transaction(
        changes: changes,
        selection: NoteSelection.collapsed(_restoreCaret(text, parse(text))),
        event: TransactionEvent.restore,
        addToHistory: false,
        time: time,
      );
    }
    return Transaction(
      changes: changes,
      selection: NoteSelection(
        anchor: selectionBase,
        head: selectionExtent,
        affinity: affinity,
      ),
      event: TransactionEvent.external,
      addToHistory: !changes.isEmpty,
      time: time,
    );
  }

  EditorState _next(
    Transaction transaction, {
    required HistoryPort history,
    required MdRange? composing,
  }) {
    if (transaction.changes.length != source.length) {
      throw ArgumentError.value(
        transaction.changes.length,
        'transaction',
        'change set length must be ${source.length}',
      );
    }
    final String nextSource = transaction.changes.apply(source);
    final NoteTreeUpdate? hook = update;
    final MdTree nextTree =
        transaction.changes.isEmpty && composing == this.composing
        ? tree
        : hook != null
        ? hook(this, transaction, nextSource)
        : parse(nextSource);
    final int? line = activeLine;
    final int lastLine = _lineCount(nextSource) - 1;
    return EditorState(
      source: nextSource,
      selection: transaction.selection,
      tree: nextTree,
      parse: parse,
      update: update,
      composing: composing,
      activeLine: line == null || line <= lastLine ? line : lastLine,
      history: history,
    );
  }
}

int _lineCount(String source) {
  int count = 1;
  for (int i = 0; i < source.length; i++) {
    if (source.codeUnitAt(i) == _lineFeed) {
      count += 1;
    }
  }
  return count;
}

const int _lineFeed = 0x0A;
const int _carriageReturn = 0x0D;
const int _space = 0x20;
const int _tab = 0x09;

ChangeSet _minimalChange(String before, String after) {
  final int shorter = before.length < after.length
      ? before.length
      : after.length;
  int prefix = 0;
  while (prefix < shorter &&
      before.codeUnitAt(prefix) == after.codeUnitAt(prefix)) {
    prefix += 1;
  }
  int suffix = 0;
  while (prefix + suffix < shorter &&
      before.codeUnitAt(before.length - 1 - suffix) ==
          after.codeUnitAt(after.length - 1 - suffix)) {
    suffix += 1;
  }
  final int delta = after.length - before.length;
  int start = prefix;
  int end = before.length - suffix;
  while (true) {
    final CharacterRange inBefore = CharacterRange.at(before, start, end);
    final int beforeStart = inBefore.stringBeforeLength;
    final int beforeEnd = before.length - inBefore.stringAfterLength;
    final CharacterRange inAfter = CharacterRange.at(
      after,
      beforeStart,
      beforeEnd + delta,
    );
    final int afterStart = inAfter.stringBeforeLength;
    final int afterEnd = after.length - inAfter.stringAfterLength - delta;
    if (afterStart == start && afterEnd == end) {
      break;
    }
    start = afterStart;
    end = afterEnd;
  }
  return ChangeSet.single(
    before.length,
    start,
    end,
    after.substring(start, end + delta),
  );
}

int _restoreCaret(String text, MdTree tree) {
  if (tree.blockAt(text.length)?.kind != MdBlockKind.photoLine) {
    return text.length;
  }
  int lineBreak = text.length;
  while (true) {
    final int lineStart = lineBreak == 0
        ? 0
        : text.lastIndexOf('\n', lineBreak - 1) + 1;
    final int lineEnd =
        lineBreak < text.length &&
            lineBreak > lineStart &&
            text.codeUnitAt(lineBreak - 1) == _carriageReturn
        ? lineBreak - 1
        : lineBreak;
    if (_holdsText(text, tree, lineStart, lineEnd)) {
      return lineEnd;
    }
    if (lineStart == 0) {
      return 0;
    }
    lineBreak = lineStart - 1;
  }
}

bool _holdsText(String text, MdTree tree, int lineStart, int lineEnd) {
  for (int i = lineStart; i < lineEnd; i++) {
    final int unit = text.codeUnitAt(i);
    if (unit != _space && unit != _tab) {
      return tree.blockAt(i)?.kind != MdBlockKind.photoLine;
    }
  }
  return false;
}
