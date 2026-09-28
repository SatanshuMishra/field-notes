import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';

enum TransactionEvent {
  inputType('input.type'),
  inputDelete('input.delete'),
  inputIme('input.ime'),
  inputPaste('input.paste'),
  inputDrop('input.drop'),
  format('format'),
  list('list'),
  table('table'),
  photo('photo'),
  spell('spell'),
  external('external'),
  restore('restore');

  const TransactionEvent(this.label);

  final String label;
}

final class Transaction {
  Transaction({
    required this.changes,
    required this.selection,
    required this.event,
    this.addToHistory = true,
    this.composing,
    this.time = Duration.zero,
  }) {
    final int newLength = changes.newLength;
    if (selection.end > newLength) {
      throw ArgumentError.value(
        selection,
        'selection',
        'must end within the new length $newLength',
      );
    }
    final MdRange? range = composing;
    if (range != null && range.end > newLength) {
      throw ArgumentError.value(
        range,
        'composing',
        'must end within the new length $newLength',
      );
    }
    if (range != null && event != TransactionEvent.inputIme) {
      throw ArgumentError.value(
        event,
        'event',
        'only input.ime carries a composing range',
      );
    }
    if (event == TransactionEvent.restore && (addToHistory || range != null)) {
      throw ArgumentError.value(
        event,
        'event',
        'a restore never enters the history and never composes',
      );
    }
  }

  final ChangeSet changes;
  final NoteSelection selection;
  final TransactionEvent event;
  final bool addToHistory;
  final MdRange? composing;
  final Duration time;

  @override
  String toString() =>
      'Transaction(${event.label}, $changes, $selection'
      '${addToHistory ? '' : ', outside history'}'
      '${composing == null ? '' : ', composing: $composing'}, $time)';
}
