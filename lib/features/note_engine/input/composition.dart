import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/input/command_registry.dart';
import 'package:field_notes/features/note_engine/input/input_window.dart';
import 'package:field_notes/features/note_engine/projection/active_line.dart';
import 'package:flutter/foundation.dart';

@immutable
final class NoteComposition {
  const NoteComposition.idle()
    : range = null,
      selectionBefore = null,
      sourceBefore = null,
      net = null,
      activeLine = null,
      window = null;

  const NoteComposition._({
    required MdRange this.range,
    required NoteSelection this.selectionBefore,
    required String this.sourceBefore,
    required ChangeSet this.net,
    required this.activeLine,
    required this.window,
  });

  final MdRange? range;
  final NoteSelection? selectionBefore;
  final String? sourceBefore;
  final ChangeSet? net;
  final ActiveLine? activeLine;
  final InputWindow? window;

  bool get isActive => range != null;

  NoteComposition _extended(Transaction transaction, MdRange range) =>
      NoteComposition._(
        range: range,
        selectionBefore: selectionBefore!,
        sourceBefore: sourceBefore!,
        net: net!.compose(transaction.changes),
        activeLine: activeLine,
        window: window?.mapThrough(transaction.changes),
      );

  CompositionCommit? _commitWith(
    ChangeSet changes,
    NoteSelection selectionAfter,
  ) {
    final ChangeSet total = net!.compose(changes);
    return total.isEmpty
        ? null
        : CompositionCommit(
            net: total,
            sourceBefore: sourceBefore!,
            selectionBefore: selectionBefore!,
            selectionAfter: selectionAfter,
          );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteComposition &&
          range == other.range &&
          selectionBefore == other.selectionBefore &&
          sourceBefore == other.sourceBefore &&
          net == other.net &&
          activeLine == other.activeLine &&
          window == other.window;

  @override
  int get hashCode => Object.hash(
    range,
    selectionBefore,
    sourceBefore,
    net,
    activeLine,
    window,
  );

  @override
  String toString() => isActive
      ? 'NoteComposition($range, from $selectionBefore, $net, '
            '$activeLine, $window)'
      : 'NoteComposition.idle()';
}

@immutable
final class CompositionCommit {
  const CompositionCommit({
    required this.net,
    required this.sourceBefore,
    required this.selectionBefore,
    required this.selectionAfter,
  });

  final ChangeSet net;
  final String sourceBefore;
  final NoteSelection selectionBefore;
  final NoteSelection selectionAfter;

  @override
  String toString() =>
      'CompositionCommit($net, $selectionBefore -> $selectionAfter)';
}

@immutable
final class CompositionStep {
  const CompositionStep({
    required this.composition,
    required this.transaction,
    this.commit,
  });

  final NoteComposition composition;
  final Transaction transaction;
  final CompositionCommit? commit;
}

CompositionStep admitTransaction(
  NoteComposition current, {
  required EditorState before,
  required Transaction transaction,
  required ActiveLine? activeLine,
  required InputWindow? window,
}) {
  final MdRange? composing = transaction.composing;
  if (!current.isActive) {
    if (composing == null) {
      return CompositionStep(composition: current, transaction: transaction);
    }
    return CompositionStep(
      composition: NoteComposition._(
        range: composing,
        selectionBefore: before.selection,
        sourceBefore: before.source,
        net: transaction.changes,
        activeLine: activeLine,
        window: window?.mapThrough(transaction.changes),
      ),
      transaction: _outsideHistory(transaction),
    );
  }
  if (composing == null) {
    return CompositionStep(
      composition: const NoteComposition.idle(),
      transaction: _outsideHistory(transaction),
      commit: current._commitWith(transaction.changes, transaction.selection),
    );
  }
  return CompositionStep(
    composition: current._extended(transaction, composing),
    transaction: _outsideHistory(transaction),
  );
}

({NoteComposition composition, Transaction? commit, CompositionCommit? record})
commitComposition(NoteComposition current, {required EditorState state}) {
  if (!current.isActive) {
    return (composition: current, commit: null, record: null);
  }
  final ChangeSet unchanged = ChangeSet.empty(state.source.length);
  return (
    composition: const NoteComposition.idle(),
    commit: Transaction(
      changes: unchanged,
      selection: state.selection,
      event: TransactionEvent.inputIme,
      addToHistory: false,
    ),
    record: current._commitWith(unchanged, state.selection),
  );
}

({Transaction? commit, CompositionCommit? record, Transaction? edit})
frameworkEdit(
  NoteComposition current, {
  required EditorState state,
  required NoteCommand command,
}) {
  final ({
    NoteComposition composition,
    Transaction? commit,
    CompositionCommit? record,
  })
  committed = commitComposition(current, state: state);
  final Transaction? commit = committed.commit;
  return (
    commit: commit,
    record: committed.record,
    edit: command(commit == null ? state : state.apply(commit)),
  );
}

bool selectionLeavesComposition(
  NoteComposition current,
  NoteSelection selection,
) {
  final MdRange? range = current.range;
  return range != null &&
      (selection.start < range.start ||
          selection.start > range.end ||
          selection.end < range.start ||
          selection.end > range.end);
}

Transaction _outsideHistory(Transaction transaction) =>
    transaction.event == TransactionEvent.inputIme && !transaction.addToHistory
    ? transaction
    : Transaction(
        changes: transaction.changes,
        selection: transaction.selection,
        event: TransactionEvent.inputIme,
        addToHistory: false,
        composing: transaction.composing,
        time: transaction.time,
      );
