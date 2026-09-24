import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';

const int noteHistoryDepth = 1000;

const Duration typingPause = Duration(milliseconds: 500);

final class NoteHistory implements HistoryPort {
  const NoteHistory()
    : _undo = const <_Entry>[],
      _redo = const <_Entry>[],
      _pending = null;

  NoteHistory._(List<_Entry> undo, List<_Entry> redo, this._pending)
    : _undo = List<_Entry>.unmodifiable(undo),
      _redo = List<_Entry>.unmodifiable(redo);

  final List<_Entry> _undo;
  final List<_Entry> _redo;
  final _Composition? _pending;

  int get undoDepth => _undo.length;

  int get redoDepth => _redo.length;

  bool get _composesText {
    final _Composition? pending = _pending;
    return pending != null && !pending.net.isEmpty;
  }

  @override
  bool get canUndo => _undo.isNotEmpty || _composesText;

  @override
  bool get canRedo => _redo.isNotEmpty && !_composesText;

  @override
  NoteHistory record(EditorState before, Transaction transaction) {
    if (transaction.event == TransactionEvent.restore) {
      return NoteHistory._(const <_Entry>[], const <_Entry>[], null);
    }
    final _Composition? pending = _pending;
    if (transaction.composing != null) {
      final _Composition next = pending == null
          ? _Composition(
              sourceBefore: before.source,
              selectionBefore: before.selection,
              startTime: transaction.time,
              net: transaction.changes,
            )
          : pending.extended(transaction.changes);
      return NoteHistory._(_undo, _redo, next);
    }
    if (pending != null) {
      final NoteHistory settled = NoteHistory._(_undo, _redo, null);
      if (transaction.event == TransactionEvent.inputIme) {
        return settled._recordComposition(
          pending.extended(transaction.changes),
          transaction.selection,
          transaction.time,
        );
      }
      return settled
          ._recordComposition(pending, before.selection, transaction.time)
          ._recordEdit(before, transaction);
    }
    if (transaction.event == TransactionEvent.inputIme &&
        !transaction.changes.isEmpty) {
      return _recordComposition(
        _Composition(
          sourceBefore: before.source,
          selectionBefore: before.selection,
          startTime: transaction.time,
          net: transaction.changes,
        ),
        transaction.selection,
        transaction.time,
      );
    }
    return _recordEdit(before, transaction);
  }

  @override
  NoteHistory closeGroup() => NoteHistory._(_closedTop(_undo), _redo, _pending);

  @override
  HistoryStep? undo(EditorState state) {
    final NoteHistory settled = _settled(state);
    if (settled._undo.isEmpty) {
      return null;
    }
    final _Entry entry = settled._undo.last;
    _requireLength(entry, state);
    final List<_Entry> undo = settled._undo.sublist(
      0,
      settled._undo.length - 1,
    );
    return HistoryStep(
      transaction: Transaction(
        changes: entry.changes,
        selection: entry.selectionBefore,
        event: entry.event,
        addToHistory: false,
        time: entry.time,
      ),
      history: NoteHistory._(_closedTop(undo), <_Entry>[
        ...settled._redo,
        entry.withChanges(entry.changes.invert(state.source)),
      ], null),
    );
  }

  @override
  HistoryStep? redo(EditorState state) {
    final NoteHistory settled = _settled(state);
    if (settled._redo.isEmpty) {
      return null;
    }
    final _Entry entry = settled._redo.last;
    _requireLength(entry, state);
    final List<_Entry> redo = settled._redo.sublist(
      0,
      settled._redo.length - 1,
    );
    return HistoryStep(
      transaction: Transaction(
        changes: entry.changes,
        selection: entry.selectionAfter,
        event: entry.event,
        addToHistory: false,
        time: entry.time,
      ),
      history: NoteHistory._(
        _newest(<_Entry>[
          ...settled._undo,
          entry.withChanges(entry.changes.invert(state.source)).closedEntry(),
        ]),
        redo,
        null,
      ),
    );
  }

  NoteHistory _settled(EditorState state) {
    final _Composition? pending = _pending;
    return pending == null
        ? this
        : NoteHistory._(
            _undo,
            _redo,
            null,
          )._recordComposition(pending, state.selection, pending.startTime);
  }

  NoteHistory _recordEdit(EditorState before, Transaction transaction) {
    if (transaction.changes.isEmpty) {
      return transaction.selection != before.selection
          ? closeGroup()
          : NoteHistory._(_undo, _redo, _pending);
    }
    if (!transaction.addToHistory) {
      return _mapped(transaction.changes);
    }
    return _push(
      _Edit(
        event: transaction.event,
        changes: transaction.changes,
        sourceBefore: before.source,
        selectionBefore: before.selection,
        selectionAfter: transaction.selection,
        startTime: transaction.time,
        time: transaction.time,
      ),
    );
  }

  NoteHistory _recordComposition(
    _Composition composition,
    NoteSelection selectionAfter,
    Duration time,
  ) {
    if (composition.net.isEmpty) {
      return NoteHistory._(_undo, _redo, null);
    }
    return _push(
      _Edit(
        event: TransactionEvent.inputIme,
        changes: composition.net,
        sourceBefore: composition.sourceBefore,
        selectionBefore: composition.selectionBefore,
        selectionAfter: selectionAfter,
        startTime: composition.startTime,
        time: time,
      ),
    );
  }

  NoteHistory _push(_Edit edit) {
    final ChangeSet inverse = edit.changes.invert(edit.sourceBefore);
    final bool lineBreak = edit.touchesLineBreak;
    final _Entry? open = _undo.isEmpty ? null : _undo.last;
    final List<_Entry> undo = open != null && !lineBreak && _joins(open, edit)
        ? <_Entry>[
            ..._undo.sublist(0, _undo.length - 1),
            _Entry(
              changes: inverse.compose(open.changes),
              selectionBefore: open.selectionBefore,
              selectionAfter: edit.selectionAfter,
              event: open.event,
              time: edit.time,
              closed: false,
            ),
          ]
        : <_Entry>[
            ..._undo,
            _Entry(
              changes: inverse,
              selectionBefore: edit.selectionBefore,
              selectionAfter: edit.selectionAfter,
              event: edit.event,
              time: edit.time,
              closed: lineBreak || !_groupedEvents.contains(edit.event),
            ),
          ];
    return NoteHistory._(_newest(undo), const <_Entry>[], null);
  }

  NoteHistory _mapped(ChangeSet changes) => NoteHistory._(
    _closedTop(_mapStack(_undo, changes, undoStack: true)),
    _mapStack(_redo, changes, undoStack: false),
    _pending,
  );
}

const Set<TransactionEvent> _groupedEvents = <TransactionEvent>{
  TransactionEvent.inputType,
  TransactionEvent.inputDelete,
  TransactionEvent.inputIme,
};

const Set<TransactionEvent> _typingEvents = <TransactionEvent>{
  TransactionEvent.inputType,
  TransactionEvent.inputIme,
};

bool _joins(_Entry open, _Edit edit) {
  if (open.closed ||
      edit.selectionBefore != open.selectionAfter ||
      edit.startTime - open.time > typingPause) {
    return false;
  }
  if (_typingEvents.contains(open.event)) {
    return _typingEvents.contains(edit.event) &&
        edit.isPureInsertion &&
        !edit.followsSpaceAfterWord;
  }
  return open.event == TransactionEvent.inputDelete &&
      edit.event == TransactionEvent.inputDelete &&
      edit.isPureDeletion;
}

void _requireLength(_Entry entry, EditorState state) {
  if (entry.changes.length != state.source.length) {
    throw StateError(
      'history entry applies to length ${entry.changes.length}, '
      'not ${state.source.length}',
    );
  }
}

List<_Entry> _newest(List<_Entry> entries) => entries.length > noteHistoryDepth
    ? entries.sublist(entries.length - noteHistoryDepth)
    : entries;

List<_Entry> _closedTop(List<_Entry> entries) =>
    entries.isEmpty || entries.last.closed
    ? entries
    : <_Entry>[
        ...entries.sublist(0, entries.length - 1),
        entries.last.closedEntry(),
      ];

List<_Entry> _mapStack(
  List<_Entry> stack,
  ChangeSet outside, {
  required bool undoStack,
}) {
  final List<_Entry> newestFirst = <_Entry>[];
  ChangeSet current = outside;
  for (final _Entry entry in stack.reversed) {
    final ChangeSet next = _rebase(current, entry.changes, tie: MapSide.after);
    final ChangeSet changes = _rebase(
      entry.changes,
      current,
      tie: MapSide.before,
    );
    if (!changes.isEmpty) {
      newestFirst.add(
        _Entry(
          changes: changes,
          selectionBefore: entry.selectionBefore.mapped(
            undoStack ? next : current,
            side: MapSide.before,
          ),
          selectionAfter: entry.selectionAfter.mapped(
            undoStack ? current : next,
            side: MapSide.before,
          ),
          event: entry.event,
          time: entry.time,
          closed: entry.closed,
        ),
      );
    }
    current = next;
  }
  return newestFirst.reversed.toList();
}

int _insertionPoint(ChangeSet over, int position, MapSide tie) {
  int shift = 0;
  for (final TextReplacement r in over.replacements) {
    if (position < r.from || (position == r.from && tie == MapSide.before)) {
      return position + shift;
    }
    if (position <= r.to) {
      return r.from + shift + r.inserted.length;
    }
    shift += r.inserted.length - (r.to - r.from);
  }
  return position + shift;
}

ChangeSet _rebase(ChangeSet changes, ChangeSet over, {required MapSide tie}) {
  final List<(int, int)> kept = <(int, int)>[];
  int shift = 0;
  for (final TextReplacement r in over.replacements) {
    final int start = r.from + shift;
    if (r.inserted.isNotEmpty) {
      kept.add((start, start + r.inserted.length));
    }
    shift += r.inserted.length - (r.to - r.from);
  }
  final List<TextReplacement> rebased = <TextReplacement>[];
  for (final TextReplacement r in changes.replacements) {
    final int start = _insertionPoint(over, r.from, tie);
    final int mappedEnd = over.mapPosition(r.to, side: MapSide.before);
    final int end = mappedEnd > start ? mappedEnd : start;
    rebased.add(TextReplacement(start, start, r.inserted));
    int cursor = start;
    for (final (int, int) span in kept) {
      final int spanStart = span.$1 > cursor ? span.$1 : cursor;
      final int spanEnd = span.$2 < end ? span.$2 : end;
      if (spanStart >= spanEnd) {
        continue;
      }
      if (spanStart > cursor) {
        rebased.add(TextReplacement(cursor, spanStart, ''));
      }
      cursor = spanEnd;
    }
    if (end > cursor) {
      rebased.add(TextReplacement(cursor, end, ''));
    }
  }
  return ChangeSet(length: over.newLength, replacements: rebased);
}

bool _isLineBreak(int unit) => unit == 0x0A || unit == 0x0D;

bool _isWhitespace(int unit) =>
    unit == 0x20 || unit == 0x09 || _isLineBreak(unit);

final class _Entry {
  const _Entry({
    required this.changes,
    required this.selectionBefore,
    required this.selectionAfter,
    required this.event,
    required this.time,
    required this.closed,
  });

  final ChangeSet changes;
  final NoteSelection selectionBefore;
  final NoteSelection selectionAfter;
  final TransactionEvent event;
  final Duration time;
  final bool closed;

  _Entry withChanges(ChangeSet next) => _Entry(
    changes: next,
    selectionBefore: selectionBefore,
    selectionAfter: selectionAfter,
    event: event,
    time: time,
    closed: closed,
  );

  _Entry closedEntry() => _Entry(
    changes: changes,
    selectionBefore: selectionBefore,
    selectionAfter: selectionAfter,
    event: event,
    time: time,
    closed: true,
  );
}

final class _Composition {
  const _Composition({
    required this.sourceBefore,
    required this.selectionBefore,
    required this.startTime,
    required this.net,
  });

  final String sourceBefore;
  final NoteSelection selectionBefore;
  final Duration startTime;
  final ChangeSet net;

  _Composition extended(ChangeSet changes) => _Composition(
    sourceBefore: sourceBefore,
    selectionBefore: selectionBefore,
    startTime: startTime,
    net: net.compose(changes),
  );
}

final class _Edit {
  const _Edit({
    required this.event,
    required this.changes,
    required this.sourceBefore,
    required this.selectionBefore,
    required this.selectionAfter,
    required this.startTime,
    required this.time,
  });

  final TransactionEvent event;
  final ChangeSet changes;
  final String sourceBefore;
  final NoteSelection selectionBefore;
  final NoteSelection selectionAfter;
  final Duration startTime;
  final Duration time;

  bool get isPureInsertion =>
      changes.replacements.every((TextReplacement r) => r.from == r.to);

  bool get isPureDeletion =>
      changes.replacements.every((TextReplacement r) => r.inserted.isEmpty);

  bool get touchesLineBreak => changes.replacements.any(
    (TextReplacement r) =>
        r.inserted.codeUnits.any(_isLineBreak) ||
        sourceBefore.substring(r.from, r.to).codeUnits.any(_isLineBreak),
  );

  bool get followsSpaceAfterWord {
    final int from = changes.replacements.first.from;
    return from >= 2 &&
        sourceBefore.codeUnitAt(from - 1) == 0x20 &&
        !_isWhitespace(sourceBefore.codeUnitAt(from - 2));
  }
}
