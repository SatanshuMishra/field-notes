import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/capabilities.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/history.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:flutter/widgets.dart';

abstract interface class NoteEditorSurface {
  void commitComposition();

  Future<void> addPhotos(Future<List<String>> Function() importer);
}

MdEdit mdEditFromChangeSet(
  ChangeSet changes,
  String newSource, {
  required int emptyAt,
}) {
  if (changes.isEmpty) {
    return MdEdit(start: emptyAt, end: emptyAt, inserted: '');
  }
  final int start = changes.replacements.first.from;
  final int end = changes.replacements.last.to;
  return MdEdit(
    start: start,
    end: end,
    inserted: newSource.substring(
      start,
      end + changes.newLength - changes.length,
    ),
  );
}

class NoteEditorController extends TextEditingController {
  NoteEditorController({String? text, Duration Function()? clock})
    : this._create(text, null, clock ?? _stopwatchClock());

  NoteEditorController.attachedTo(
    TextEditingController source, {
    Duration Function()? clock,
  }) : this._create(null, source, clock ?? _stopwatchClock());

  NoteEditorController._create(
    String? text,
    TextEditingController? source,
    Duration Function() clock,
  ) : _source = source,
      _clock = clock,
      _state = _initialState(text, source, clock()),
      super() {
    source?.addListener(_onSourceChanged);
  }

  final TextEditingController? _source;
  final Duration Function() _clock;
  EditorState _state;
  EditorState? _valueState;
  TextEditingValue _stateValue = TextEditingValue.empty;
  NoteEditorSurface? _surface;
  List<ValueChanged<Transaction>> _transactionListeners =
      const <ValueChanged<Transaction>>[];
  bool _writingSource = false;
  bool _followingSource = false;

  EditorState get state => _state;

  bool get canUndo => _state.history.canUndo;

  bool get canRedo => _state.history.canRedo;

  @override
  TextEditingValue get value {
    final EditorState current = _state;
    if (!identical(_valueState, current)) {
      _stateValue = _valueOf(current);
      _valueState = current;
    }
    return _stateValue;
  }

  @override
  set value(TextEditingValue newValue) {
    if (newValue == value) {
      return;
    }
    _write(newValue);
  }

  void dispatch(Transaction transaction) {
    final Transaction stamped = _stamped(transaction);
    _state = _state.apply(stamped);
    _settle(stamped);
  }

  void applyCommand(Transaction? Function(EditorState state) command) {
    _commitComposition();
    final Transaction? transaction = command(_state);
    if (transaction != null) {
      dispatch(transaction);
    }
  }

  void undo() {
    _commitComposition();
    final HistoryStep? step = _state.history.undo(_state);
    if (step == null) {
      return;
    }
    _state = _state.undo();
    _settle(step.transaction);
  }

  void redo() {
    _commitComposition();
    final HistoryStep? step = _state.history.redo(_state);
    if (step == null) {
      return;
    }
    _state = _state.redo();
    _settle(step.transaction);
  }

  void addTransactionListener(ValueChanged<Transaction> listener) {
    _transactionListeners = <ValueChanged<Transaction>>[
      ..._transactionListeners,
      listener,
    ];
  }

  void removeTransactionListener(ValueChanged<Transaction> listener) {
    final int index = _transactionListeners.indexOf(listener);
    if (index < 0) {
      return;
    }
    _transactionListeners = <ValueChanged<Transaction>>[
      ..._transactionListeners.sublist(0, index),
      ..._transactionListeners.sublist(index + 1),
    ];
  }

  void attachSurface(NoteEditorSurface surface) {
    _surface = surface;
  }

  void detachSurface(NoteEditorSurface surface) {
    if (identical(_surface, surface)) {
      _surface = null;
    }
  }

  Future<void> addPhotos(Future<List<String>> Function() importer) {
    final NoteEditorSurface? surface = _surface;
    if (surface == null) {
      throw StateError('No editor is showing this note');
    }
    return surface.addPhotos(importer);
  }

  @override
  void dispose() {
    _source?.removeListener(_onSourceChanged);
    _surface = null;
    _transactionListeners = const <ValueChanged<Transaction>>[];
    super.dispose();
  }

  void _write(TextEditingValue newValue) {
    _commitComposition();
    final TextSelection selection = newValue.selection;
    dispatch(
      _state.externalWrite(
        newValue.text,
        selectionBase: selection.baseOffset,
        selectionExtent: selection.extentOffset,
        affinity: selection.affinity,
        time: _clock(),
      ),
    );
  }

  void _commitComposition() {
    if (_state.composing == null) {
      return;
    }
    final NoteEditorSurface? surface = _surface;
    if (surface != null) {
      surface.commitComposition();
      return;
    }
    dispatch(
      Transaction(
        changes: ChangeSet.empty(_state.source.length),
        selection: _state.selection,
        event: TransactionEvent.inputIme,
        addToHistory: false,
      ),
    );
  }

  Transaction _stamped(Transaction transaction) =>
      transaction.time != Duration.zero
      ? transaction
      : Transaction(
          changes: transaction.changes,
          selection: transaction.selection,
          event: transaction.event,
          addToHistory: transaction.addToHistory,
          composing: transaction.composing,
          time: _clock(),
        );

  void _settle(Transaction transaction) {
    if (!_followingSource) {
      _writeThrough();
    }
    for (final ValueChanged<Transaction> listener in _transactionListeners) {
      listener(transaction);
    }
    notifyListeners();
  }

  void _writeThrough() {
    final TextEditingController? source = _source;
    if (source == null) {
      return;
    }
    final TextEditingValue current = value;
    if (source.text == current.text && source.selection == current.selection) {
      return;
    }
    _writingSource = true;
    try {
      source.value = TextEditingValue(
        text: current.text,
        selection: current.selection,
      );
    } finally {
      _writingSource = false;
    }
  }

  void _onSourceChanged() {
    final TextEditingController? source = _source;
    if (_writingSource || source == null) {
      return;
    }
    final TextEditingValue incoming = source.value;
    final TextEditingValue current = value;
    if (incoming.text == current.text &&
        incoming.selection == current.selection) {
      return;
    }
    _followingSource = true;
    try {
      _write(incoming);
    } finally {
      _followingSource = false;
    }
  }
}

Duration Function() _stopwatchClock() {
  final Stopwatch stopwatch = Stopwatch()..start();
  return () => stopwatch.elapsed;
}

MdTree _parseTree(String source) =>
    parseNoteTree(source, tables: tablesEnabled);

MdTree _updateTree(
  EditorState previous,
  Transaction transaction,
  String source,
) => const MdIncrementalParser(tables: tablesEnabled)
    .reparse(
      previous.tree,
      previous.source,
      source,
      mdEditFromChangeSet(
        transaction.changes,
        source,
        emptyAt: previous.composing?.start ?? transaction.composing?.start ?? 0,
      ),
      composing: transaction.composing,
      previousComposing: previous.composing,
    )
    .tree;

EditorState _initialState(
  String? text,
  TextEditingController? source,
  Duration time,
) {
  final EditorState empty = EditorState.create(
    '',
    parse: _parseTree,
    update: _updateTree,
    history: const NoteHistory(),
  );
  final String? initial = source?.text ?? text;
  if (initial == null) {
    return empty;
  }
  final EditorState restored = empty.apply(
    empty.externalWrite(
      initial,
      selectionBase: -1,
      selectionExtent: -1,
      time: time,
    ),
  );
  if (source == null) {
    return restored;
  }
  final TextSelection selection = source.value.selection;
  final int length = source.text.length;
  final bool isValid =
      selection.baseOffset >= 0 &&
      selection.baseOffset <= length &&
      selection.extentOffset >= 0 &&
      selection.extentOffset <= length;
  return isValid
      ? restored.withSelection(
          NoteSelection(
            anchor: selection.baseOffset,
            head: selection.extentOffset,
            affinity: selection.affinity,
          ),
        )
      : restored;
}

TextEditingValue _valueOf(EditorState state) {
  final MdRange? composing = state.composing;
  return TextEditingValue(
    text: state.source,
    selection: TextSelection(
      baseOffset: state.selection.anchor,
      extentOffset: state.selection.head,
      affinity: state.selection.affinity,
    ),
    composing: composing == null
        ? TextRange.empty
        : TextRange(start: composing.start, end: composing.end),
  );
}
