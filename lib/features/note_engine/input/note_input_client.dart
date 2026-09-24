import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/input/delta_mapping.dart';
import 'package:field_notes/features/note_engine/input/delta_mirror.dart';
import 'package:field_notes/features/note_engine/input/input_window.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const List<String> noteContentMimeTypes = <String>['image/*'];

abstract interface class NoteInputHost {
  EditorState get state;

  VisibleText get visible;

  VisibleText visibleFor(EditorState state);

  int get plainVisibleLength;

  NoteLayout? get layout;

  RenderBox? get renderBox;

  Offset contentToLocal(Offset contentPoint);

  int get viewId;

  void applyInput(Transaction transaction);

  void runClassified(ClassifiedEdit edit);

  void insertContent(KeyboardInsertedContent content);

  void performSelector(String selectorName);
}

class NoteInputClient with DeltaTextInputClient {
  NoteInputClient({required this.host});

  final NoteInputHost host;
  TextInputConnection? _connection;
  DeltaMirror _mirror = const DeltaMirror.empty();
  InputWindow? _window;
  FocusNode? _focusNode;
  bool _inBatch = false;
  bool _openDeferred = false;
  bool _disposed = false;
  int _reportGeneration = 0;
  Rect? _sentCaretRect;
  Rect? _sentComposingRect;

  bool get hasConnection => _connection?.attached ?? false;

  DeltaMirror get mirror => _mirror;

  List<DeltaDrop> get drops => _mirror.drops;

  InputWindow get window => _window ?? const InputWindow.whole();

  int get windowBase {
    final List<KnownValue> known = _mirror.knownValues;
    return known.isEmpty ? 0 : known.first.windowBase;
  }

  TextInputConfiguration get configuration => TextInputConfiguration(
    viewId: host.viewId,
    inputType: TextInputType.multiline,
    inputAction: TextInputAction.newline,
    textCapitalization: TextCapitalization.sentences,
    enableDeltaModel: true,
    allowedMimeTypes: defaultTargetPlatform == TargetPlatform.android
        ? noteContentMimeTypes
        : const <String>[],
  );

  void focusChanged(FocusNode node) {
    _focusNode = node;
    if (node.hasFocus) {
      if (node.consumeKeyboardToken()) {
        openConnection();
      }
      return;
    }
    closeConnection();
  }

  void openConnection() => _open(mayDefer: true);

  void closeConnection() {
    _clearComposing();
    final TextInputConnection? connection = _connection;
    _connection = null;
    _stopReports();
    if (connection != null && connection.attached) {
      connection.close();
    }
  }

  void showKeyboard(FocusNode node) {
    _focusNode = node;
    final TextInputConnection? connection = _connection;
    if (connection != null && connection.attached) {
      connection.show();
      return;
    }
    if (node.hasFocus) {
      openConnection();
      return;
    }
    node.requestFocus();
  }

  void editorChanged(ChangeSet changes) {
    _mirror = _mirror.recordSourceChange(changes);
    _window = _window?.mapThrough(changes);
    if (!_inBatch) {
      sendStateIfChanged();
    }
  }

  void sendStateIfChanged() => _sendState(force: false);

  void updateSizeAndTransform() {
    final TextInputConnection? connection = _connection;
    final RenderBox? box = host.renderBox;
    if (connection == null ||
        !connection.attached ||
        box == null ||
        !box.attached ||
        !box.hasSize) {
      return;
    }
    connection.setEditableSizeAndTransform(box.size, box.getTransformTo(null));
  }

  void dispose() {
    _disposed = true;
    final TextInputConnection? connection = _connection;
    _connection = null;
    _stopReports();
    if (connection != null && connection.attached) {
      connection.close();
    }
  }

  @override
  TextEditingValue get currentTextEditingValue {
    final _Planned planned = _plan(sending: true);
    _window = planned.window;
    _mirror = _mirror.recordSent(_known(planned));
    return planned.value;
  }

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValue(TextEditingValue value) {
    _processBatch(<TextEditingDelta>[_mirror.reduceFullValue(value)]);
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    _processBatch(textEditingDeltas);
  }

  @override
  void performAction(TextInputAction action) {}

  @override
  void insertContent(KeyboardInsertedContent content) {
    host.insertContent(content);
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void performSelector(String selectorName) {
    host.performSelector(selectorName);
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  bool onFocusReceived() => false;

  @override
  void connectionClosed() {
    final TextInputConnection? connection = _connection;
    if (connection == null) {
      return;
    }
    connection.connectionClosedReceived();
    _connection = null;
    _stopReports();
    _clearComposing();
  }

  @override
  void didChangeInputControl(
    TextInputControl? oldControl,
    TextInputControl? newControl,
  ) {}

  @override
  void showToolbar() {}

  @override
  void insertTextPlaceholder(Size size) {}

  @override
  void removeTextPlaceholder() {}

  void _open({required bool mayDefer}) {
    if (_disposed || hasConnection) {
      return;
    }
    final RenderBox? box = host.renderBox;
    if (box == null || !box.hasSize) {
      if (mayDefer && !_openDeferred) {
        _openDeferred = true;
        SchedulerBinding.instance.addPostFrameCallback((Duration _) {
          _openDeferred = false;
          if (_focusNode?.hasFocus ?? true) {
            _open(mayDefer: false);
          }
        });
      }
      return;
    }
    final TextInputConnection connection = TextInput.attach(
      this,
      configuration,
    );
    _connection = connection;
    connection.setEditableSizeAndTransform(box.size, box.getTransformTo(null));
    final _Planned planned = _plan(sending: true);
    _window = planned.window;
    connection.setEditingState(planned.value);
    _mirror = _mirror.recordSent(_known(planned));
    connection.show();
    _startReports();
  }

  void _clearComposing() {
    final EditorState state = host.state;
    if (state.composing == null) {
      return;
    }
    host.applyInput(
      Transaction(
        changes: ChangeSet.empty(state.source.length),
        selection: state.selection,
        event: TransactionEvent.inputIme,
        addToHistory: false,
      ),
    );
  }

  _Planned _plan({required bool sending}) {
    final EditorState state = host.state;
    final VisibleText visible = host.visible;
    final MdRange? composing = state.composing;
    final InputWindow window = planInputWindow(
      visible: visible,
      plainLength: host.plainVisibleLength,
      selection: state.selection,
      previous: _window,
      composing: composing != null,
      sending: sending,
    );
    final WindowedValue windowed = windowedValue(
      visible: visible,
      window: window,
      selection: visibleSelectionFor(
        visible: visible,
        selection: state.selection,
        windowBase: 0,
      ),
      composing: composing == null
          ? TextRange.empty
          : TextRange(
              start: visible.map.sourceToVisible(composing.start),
              end: visible.map.sourceToVisible(composing.end),
            ),
    );
    return _Planned(
      value: windowed.value,
      base: windowed.base,
      window: window,
      state: state,
      visible: visible,
    );
  }

  KnownValue _known(_Planned planned) => KnownValue(
    value: planned.value,
    state: planned.state,
    visible: planned.visible,
    windowBase: planned.base,
    version: _mirror.version,
  );

  void _sendState({required bool force}) {
    final TextInputConnection? connection = _connection;
    if (_inBatch || connection == null || !connection.attached) {
      return;
    }
    final _Planned held = _plan(sending: false);
    if (!force && !_mirror.differsFrom(held.value)) {
      _window = held.window;
      _mirror = _mirror.recordHeld(_known(held));
      return;
    }
    final _Planned sent = _plan(sending: true);
    _window = sent.window;
    connection.setEditingState(sent.value);
    _mirror = _mirror.recordSent(_known(sent));
  }

  void _processBatch(List<TextEditingDelta> deltas) {
    _inBatch = true;
    EditorState working = host.state;
    _PendingInput? pending;
    bool resync = false;

    void flush() {
      final _PendingInput? joined = pending;
      pending = null;
      if (joined == null) {
        return;
      }
      final EditorState current = host.state;
      final Transaction transaction = joined.transaction;
      if (transaction.changes.isEmpty &&
          transaction.selection == current.selection &&
          transaction.composing == current.composing) {
        return;
      }
      host.applyInput(transaction);
    }

    try {
      for (final TextEditingDelta delta in deltas) {
        if (delta.oldText != _mirror.value.text) {
          flush();
          working = host.state;
        }
        final ({DeltaMirror mirror, MirrorStep step}) stepped = _mirror.step(
          delta,
          current: host.state,
          localSelection: host.state.selection,
        );
        _mirror = stepped.mirror;
        switch (stepped.step) {
          case CurrentDelta(:final KnownValue against):
            final DeltaOutcome outcome = mapDelta(
              state: working,
              visible: host.visibleFor(working),
              windowBase: against.windowBase,
              platformBefore: against.value,
              delta: delta,
            );
            switch (outcome) {
              case MappedEdit(:final Transaction transaction):
                final _PendingInput joined =
                    (pending ?? _PendingInput.start(working.source.length))
                        .withEdit(transaction);
                pending = joined;
                working = working.apply(transaction);
                if (_sendableText(working, joined.changes) !=
                    _mirror.value.text) {
                  flush();
                  working = host.state;
                }
              case SelectionEdit(
                :final NoteSelection selection,
                :final MdRange? composing,
              ):
                pending =
                    (pending ?? _PendingInput.start(working.source.length))
                        .withSelection(selection, composing);
                working = working.apply(
                  Transaction(
                    changes: ChangeSet.empty(working.source.length),
                    selection: selection,
                    event: composing == null
                        ? TransactionEvent.inputType
                        : TransactionEvent.inputIme,
                    addToHistory: false,
                    composing: composing,
                  ),
                );
              case final ClassifiedEdit edit:
                flush();
                host.runClassified(edit);
                working = host.state;
            }
          case RebasedDelta(:final Transaction transaction):
            flush();
            host.applyInput(transaction);
            working = host.state;
          case KeptAffinity():
            break;
          case DroppedDelta():
            resync = true;
        }
      }
      flush();
    } finally {
      _inBatch = false;
    }
    _sendState(force: resync);
  }

  String _sendableText(EditorState working, ChangeSet pendingChanges) {
    final VisibleText visible = host.visibleFor(working);
    return windowedValue(
      visible: visible,
      window: window.mapThrough(pendingChanges),
      selection: const TextSelection.collapsed(offset: -1),
    ).value.text;
  }

  void _startReports() {
    _reportGeneration += 1;
    _sentCaretRect = null;
    _sentComposingRect = null;
    final int generation = _reportGeneration;
    SchedulerBinding.instance.addPostFrameCallback(
      (Duration _) => _report(generation),
    );
  }

  void _stopReports() {
    _reportGeneration += 1;
  }

  void _report(int generation) {
    if (generation != _reportGeneration || !hasConnection) {
      return;
    }
    _sendGeometry();
    SchedulerBinding.instance.addPostFrameCallback(
      (Duration _) => _report(generation),
    );
  }

  void _sendGeometry() {
    final TextInputConnection? connection = _connection;
    final NoteLayout? layout = host.layout;
    if (connection == null || layout == null) {
      return;
    }
    final EditorState state = host.state;
    final NoteSelection selection = state.selection;
    final Rect caret = _toLocal(
      layout.caretRect(selection.start, selection.affinity),
    );
    final MdRange? composing = state.composing;
    final Rect composingRect = composing == null
        ? caret
        : _toLocal(layout.rangeBounds(composing));
    if (caret != _sentCaretRect) {
      _sentCaretRect = caret;
      connection.setCaretRect(caret);
    }
    if (composingRect != _sentComposingRect) {
      _sentComposingRect = composingRect;
      connection.setComposingRect(composingRect);
    }
  }

  Rect _toLocal(Rect content) => Rect.fromPoints(
    host.contentToLocal(content.topLeft),
    host.contentToLocal(content.bottomRight),
  );
}

@immutable
final class _Planned {
  const _Planned({
    required this.value,
    required this.base,
    required this.window,
    required this.state,
    required this.visible,
  });

  final TextEditingValue value;
  final int base;
  final InputWindow window;
  final EditorState state;
  final VisibleText visible;
}

@immutable
final class _PendingInput {
  const _PendingInput({
    required this.changes,
    required this.selection,
    required this.composing,
    required this.events,
  });

  _PendingInput.start(int length)
    : changes = ChangeSet.empty(length),
      selection = null,
      composing = null,
      events = const <TransactionEvent>{};

  final ChangeSet changes;
  final NoteSelection? selection;
  final MdRange? composing;
  final Set<TransactionEvent> events;

  _PendingInput withEdit(Transaction transaction) => _PendingInput(
    changes: changes.compose(transaction.changes),
    selection: transaction.selection,
    composing: transaction.composing,
    events: <TransactionEvent>{...events, transaction.event},
  );

  _PendingInput withSelection(NoteSelection selection, MdRange? composing) =>
      _PendingInput(
        changes: changes,
        selection: selection,
        composing: composing,
        events: events,
      );

  Transaction get transaction {
    final NoteSelection finalSelection =
        selection ?? NoteSelection.collapsed(changes.newLength);
    if (events.isEmpty) {
      return Transaction(
        changes: changes,
        selection: finalSelection,
        event: composing == null
            ? TransactionEvent.inputType
            : TransactionEvent.inputIme,
        addToHistory: false,
        composing: composing,
      );
    }
    if (events.contains(TransactionEvent.inputIme) || composing != null) {
      return Transaction(
        changes: changes,
        selection: finalSelection,
        event: TransactionEvent.inputIme,
        addToHistory: false,
        composing: composing,
      );
    }
    return Transaction(
      changes: changes,
      selection: finalSelection,
      event: events.length > 1 ? TransactionEvent.inputType : events.single,
      addToHistory: !changes.isEmpty,
    );
  }
}

class NoteInputCompositionCallback extends SingleChildRenderObjectWidget {
  const NoteInputCompositionCallback({
    super.key,
    required this.client,
    super.child,
  });

  final NoteInputClient client;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderNoteInputCompositionCallback(client);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderNoteInputCompositionCallback).client = client;
  }
}

class _RenderNoteInputCompositionCallback extends RenderProxyBox {
  _RenderNoteInputCompositionCallback(this.client);

  NoteInputClient client;
  VoidCallback? _cancel;

  @override
  void paint(PaintingContext context, Offset offset) {
    _cancel ??= context.addCompositionCallback(
      (Layer _) => client.updateSizeAndTransform(),
    );
    super.paint(context, offset);
  }

  @override
  void detach() {
    _cancel?.call();
    _cancel = null;
    super.detach();
  }
}
