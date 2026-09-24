import 'dart:async';
import 'dart:math' as math;

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart'
    show IconStickerGlyph;
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/capabilities.dart';
import 'package:field_notes/features/note_engine/commands/list_commands.dart';
import 'package:field_notes/features/note_engine/commands/note_commands.dart';
import 'package:field_notes/features/note_engine/commands/table_commands.dart';
import 'package:field_notes/features/note_engine/commands/task_commands.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/editor/composer_media_scope.dart';
import 'package:field_notes/features/note_engine/editor/editor_keys.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_controller.dart';
import 'package:field_notes/features/note_engine/gestures/clipboard_actions.dart';
import 'package:field_notes/features/note_engine/gestures/mouse_selection.dart';
import 'package:field_notes/features/note_engine/gestures/selection_overlay_controller.dart';
import 'package:field_notes/features/note_engine/gestures/touch_selection.dart';
import 'package:field_notes/features/note_engine/input/command_registry.dart';
import 'package:field_notes/features/note_engine/input/composition.dart';
import 'package:field_notes/features/note_engine/input/composition.dart'
    as composition
    show commitComposition;
import 'package:field_notes/features/note_engine/input/delta_mapping.dart';
import 'package:field_notes/features/note_engine/input/delta_mirror.dart';
import 'package:field_notes/features/note_engine/input/note_actions.dart';
import 'package:field_notes/features/note_engine/input/note_input_client.dart';
import 'package:field_notes/features/note_engine/input/note_shortcuts.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_layout_engine.dart';
import 'package:field_notes/features/note_engine/photos/photo_commands.dart';
import 'package:field_notes/features/note_engine/photos/photo_drag.dart';
import 'package:field_notes/features/note_engine/photos/photo_import_flow.dart';
import 'package:field_notes/features/note_engine/photos/photo_paste_drop.dart';
import 'package:field_notes/features/note_engine/photos/photo_relocation.dart';
import 'package:field_notes/features/note_engine/platform/file_drop.dart';
import 'package:field_notes/features/note_engine/platform/spell_check_service.dart';
import 'package:field_notes/features/note_engine/projection/active_line.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:field_notes/features/note_engine/render/note_view.dart';
import 'package:field_notes/features/note_engine/render/photo_figure.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';
import 'package:field_notes/features/note_engine/render/reveal.dart';
import 'package:field_notes/features/note_engine/spell/spell_checker.dart';
import 'package:field_notes/features/note_engine/toolbars/table_toolbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

const double _emBase = 16;
const double _columnEms = 45;
const double _desktopColumnEms = 30;
const int _lineFeed = 0x0A;
const int _carriageReturn = 0x0D;

typedef NotePhotoToolbarBuilder =
    Widget Function(BuildContext context, NotePhotoToolbarRequest request);

@immutable
class NotePhotoToolbarRequest {
  const NotePhotoToolbarRequest({
    required this.controller,
    required this.photoLineStart,
    required this.ordinal,
    required this.photoRect,
    required this.captionRect,
    required this.surface,
    required this.bottomInset,
    required this.columnWidth,
    required this.em,
    required this.phoneColumn,
    required this.captionOpen,
    required this.importer,
    required this.firstControlFocusNode,
    required this.onOpenCaption,
    required this.onCloseCaption,
    required this.onReturnToEditor,
    required this.onRemovalToastShown,
  });

  final NoteEditorController controller;
  final int photoLineStart;
  final int ordinal;
  final Rect photoRect;
  final Rect captionRect;
  final Rect surface;
  final double bottomInset;
  final double columnWidth;
  final double em;
  final bool phoneColumn;
  final bool captionOpen;
  final Future<List<String>> Function()? importer;
  final FocusNode firstControlFocusNode;
  final VoidCallback onOpenCaption;
  final VoidCallback onCloseCaption;
  final VoidCallback onReturnToEditor;
  final VoidCallback onRemovalToastShown;
}

class NoteEditorView extends StatefulWidget {
  NoteEditorView({
    super.key,
    required TextEditingController controller,
    required this.focusNode,
    required this.undoController,
    required this.scrollController,
    this.hintText = '',
    this.hintStyle = TypographyTokens.noteBodyPlaceholder,
    this.cursorColor = Palette.coral,
    this.photoImporter,
    this.photoMediaImporter,
    this.bottomInset = 0,
    this.spellCheckEnabled = false,
    this.photoToolbarBuilder,
  }) : controller = _noteEditorControllerOf(controller);

  final NoteEditorController controller;
  final FocusNode focusNode;
  final UndoHistoryController undoController;
  final ScrollController scrollController;
  final String hintText;
  final TextStyle hintStyle;
  final Color cursorColor;
  final Future<List<String>> Function()? photoImporter;
  final PhotoMediaImporter? photoMediaImporter;
  final double bottomInset;
  final bool spellCheckEnabled;
  final NotePhotoToolbarBuilder? photoToolbarBuilder;

  static NoteEditorController _noteEditorControllerOf(
    TextEditingController controller,
  ) => controller is NoteEditorController
      ? controller
      : throw ArgumentError.value(
          controller,
          'controller',
          'NoteEditorView needs a NoteEditorController',
        );

  @override
  NoteEditorViewState createState() => NoteEditorViewState();
}

@immutable
final class _Projection {
  _Projection(EditorState state, this.activeLine, this.visible)
    : source = state.source,
      tree = state.tree,
      settled = state.composing == null;

  final String source;
  final MdTree tree;
  final ActiveLine? activeLine;
  final VisibleText visible;
  final bool settled;

  bool matches(EditorState state, ActiveLine? line) =>
      identical(source, state.source) &&
      identical(tree, state.tree) &&
      activeLine == line;

  bool sharesContent(EditorState state, ActiveLine? line) =>
      settled &&
      state.composing == null &&
      activeLine == line &&
      source == state.source;
}

final class _EditorCommands implements CommandRegistry {
  const _EditorCommands(this._inner);

  final CommandRegistry _inner;

  @override
  NoteCommand? commandFor(String id) => switch (id) {
    NoteCommandId.deleteBackward => _photoFirst(
      photoBackspace,
      _inner.commandFor(id),
    ),
    NoteCommandId.deleteForward => _photoFirst(
      photoDelete,
      _inner.commandFor(id),
    ),
    _ => _inner.commandFor(id),
  };

  static NoteCommand _photoFirst(
    PhotoKeyResult? Function(EditorState state) photoKey,
    NoteCommand? inner,
  ) => (EditorState state) => switch (photoKey(state)) {
    PhotoKeySelect(:final NoteSelection selection) => Transaction(
      changes: ChangeSet.empty(state.source.length),
      selection: selection,
      event: TransactionEvent.inputDelete,
      addToHistory: false,
    ),
    PhotoKeyEdit(:final Transaction transaction) => transaction,
    null => inner?.call(state),
  };
}

class NoteEditorViewState extends State<NoteEditorView>
    with TickerProviderStateMixin
    implements NoteEditorSurface {
  final GlobalKey _renderKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _keyScopeKey = GlobalKey();
  final NoteLayoutEngine _engine = NoteLayoutEngine();
  final FocusNode _toolbarFocusNode = FocusNode(
    debugLabel: 'NotePhotoToolbar',
  );
  final ValueNotifier<int> _geometryRevision = ValueNotifier<int>(0);
  final CommandRegistry _commands = const _EditorCommands(
    NoteCommandRegistry(tablesEnabled: tablesEnabled),
  );

  late final NoteInputClient _client;
  late final NoteActions _actions;
  late final _EditorViewDelegate _delegate;
  late final PhotoImportFlow _imports;
  late final PhotoDragController _drag;
  late final NoteSelectionOverlayController _overlay;
  late final NoteClipboardActions _clipboard;
  late Listenable _geometryListenable;

  PhotoPasteDrop? _pasteDrop;
  PhotoMediaImporter? _pasteDropImporter;
  StreamSubscription<FileDropEvent>? _fileDrops;
  SpellChecker? _spellChecker;
  bool _spellCheckerResolved = false;
  NoteCaretReveal? _reveal;
  bool _firstFrameDone = false;

  NoteComposition _composition = const NoteComposition.idle();
  ActiveLine? _activeLine;
  bool _gestureDragActive = false;
  bool _photoDragActive = false;
  bool _ignoreGestureSelection = false;
  _Projection? _current;
  _Projection? _scratch;
  String? _plainSource;
  MdTree? _plainTree;
  int _plainLength = 0;
  int _projections = 0;
  LaidOutNote? _layout;
  LaidOutNote? _geometryLayout;
  bool _geometryCheckScheduled = false;
  late NoteSelection _lastSelection;
  int? _captionLine;
  bool _removalToastArmed = false;
  bool _photoToolbarShown = false;
  bool _shownDragSession = false;
  PhotoDropTarget? _shownDragTarget;
  double _viewHeight = 0;
  double? _lastColumn;
  TextScaler? _lastScaler;

  @visibleForTesting
  List<DeltaDrop> get debugInputDrops => _client.drops;

  @visibleForTesting
  List<PhotoImportPlaceholder> get debugImportPlaceholders =>
      _imports.placeholders;

  @visibleForTesting
  int? get debugDropBoundary =>
      _drag.session?.target?.boundary ?? _pasteDrop?.hoverTarget?.boundary;

  @visibleForTesting
  NoteLayout? get debugLayout => _layout;

  @visibleForTesting
  int get debugProjectionCount => _projections;

  NoteEditorController get _controller => widget.controller;

  EditorState get _state => widget.controller.state;

  RenderNoteView? get _renderView {
    final RenderObject? object = _renderKey.currentContext
        ?.findRenderObject();
    return object is RenderNoteView && object.attached ? object : null;
  }

  RenderBox? get _stackBox {
    final RenderObject? object = _stackKey.currentContext?.findRenderObject();
    return object is RenderBox && object.attached ? object : null;
  }

  LaidOutNote? get _currentLayout {
    final LaidOutNote? layout = _layout;
    return layout != null && identical(layout.inputs.tree, _state.tree)
        ? layout
        : null;
  }

  bool get _dragging => _gestureDragActive || _photoDragActive;

  TextRange? get _selectedPhoto {
    final EditorState state = _state;
    return noteSelectedPhotoRange(state.tree, state.source, state.selection);
  }

  bool get _captionOpen {
    final int? line = _captionLine;
    return line != null && _selectedPhoto?.start == line;
  }

  @override
  void initState() {
    super.initState();
    _client = NoteInputClient(host: _EditorInputHost(this));
    _actions = NoteActions(host: _EditorActionHost(this));
    _delegate = _EditorViewDelegate(this);
    _imports = PhotoImportFlow(
      readState: () => widget.controller.state,
      onOutcome: _handleImportOutcome,
    )..addListener(_markNeedsBuild);
    _drag = PhotoDragController(
      vsync: this,
      readState: () => widget.controller.state,
      targets: _dropTargets,
      scrollPosition: () => widget.scrollController.position,
      viewport: _renderViewGlobalRect,
      toContent: (Offset global) =>
          _renderView?.globalToContent(global) ?? global,
    )..addListener(_handleDragChanged);
    _overlay = NoteSelectionOverlayController(
      context: context,
      renderKey: _renderKey,
      onSelectionChanged: _handleGestureSelection,
      onDragActiveChanged: _handleGestureDrag,
      onCut: (SelectionChangedCause cause) =>
          unawaited(_clipboard.cutSelection(cause)),
      onCopy: (SelectionChangedCause cause) =>
          unawaited(_clipboard.copySelection(cause)),
      onPaste: _paste,
      onSelectAll: (SelectionChangedCause cause) =>
          _clipboard.selectAll(cause),
      onBringIntoView: (int _) => _scheduleReveal(),
    );
    _clipboard = NoteClipboardActions(
      state: () => widget.controller.state,
      dispatch: _dispatchAfterCommit,
      select: _changeSelection,
      hideToolbar: _overlay.hideToolbar,
      bringIntoView: (int _) => _scheduleReveal(),
      isActive: () => mounted,
      cutPhoto: (EditorState state) => cutSelectedPhoto(state)?.transaction,
    );
    _geometryListenable = _mergedGeometry(widget.scrollController);
    _attachController(widget.controller);
    _attachUndo(widget.undoController);
    _syncPasteDrop();
    _refreshActiveLine();
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }
      _firstFrameDone = true;
      _reveal?.attach();
      _syncUndoValue();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Locale locale =
        Localizations.maybeLocaleOf(context) ?? const Locale('en');
    final SpellChecker? checker = _spellChecker;
    if (checker != null) {
      checker.locale = locale;
    } else if (!_spellCheckerResolved) {
      _spellCheckerResolved = true;
      _spellChecker = _createSpellChecker(locale);
    }
    _reveal ??= _createReveal();
  }

  @override
  void didUpdateWidget(NoteEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _detachController(oldWidget.controller);
      _composition = const NoteComposition.idle();
      _activeLine = null;
      _attachController(widget.controller);
      _refreshActiveLine();
      final SpellChecker? checker = _spellChecker;
      if (checker != null) {
        checker
          ..removeListener(_markNeedsBuild)
          ..dispose();
        _spellChecker = _createSpellChecker(
          Localizations.maybeLocaleOf(context) ?? const Locale('en'),
        );
      }
      _client.closeConnection();
      if (widget.focusNode.hasFocus) {
        _client.openConnection();
      }
      _syncUndoValueAfterFrame();
    }
    if (!identical(oldWidget.undoController, widget.undoController)) {
      _detachUndo(oldWidget.undoController);
      _attachUndo(widget.undoController);
      _syncUndoValueAfterFrame();
    }
    if (!identical(oldWidget.scrollController, widget.scrollController)) {
      _geometryListenable = _mergedGeometry(widget.scrollController);
      _reveal?.dispose();
      _reveal = _createReveal();
      if (_firstFrameDone) {
        _reveal?.attach();
      }
    }
    if (oldWidget.photoMediaImporter != widget.photoMediaImporter) {
      _syncPasteDrop();
    }
    if (oldWidget.spellCheckEnabled != widget.spellCheckEnabled) {
      _spellChecker?.enabled = widget.spellCheckEnabled;
    }
  }

  @override
  void dispose() {
    _detachController(widget.controller);
    _detachUndo(widget.undoController);
    _client.dispose();
    _imports
      ..removeListener(_markNeedsBuild)
      ..dispose();
    _drag
      ..removeListener(_handleDragChanged)
      ..dispose();
    _overlay.dispose();
    _disposePasteDrop();
    _spellChecker
      ?..removeListener(_markNeedsBuild)
      ..dispose();
    _reveal?.dispose();
    _toolbarFocusNode.dispose();
    _geometryRevision.dispose();
    if (_removalToastArmed) {
      _removalToastArmed = false;
      dismissTransientToast();
    }
    super.dispose();
  }

  @override
  void commitComposition() {
    final ({
      NoteComposition composition,
      Transaction? commit,
      CompositionCommit? record,
    })
    committed = composition.commitComposition(
      _composition,
      state: _controller.state,
    );
    _composition = committed.composition;
    final Transaction? commit = committed.commit;
    if (commit != null) {
      _controller.dispatch(commit);
    }
  }

  @override
  Future<void> addPhotos(Future<List<String>> Function() importer) async {
    final PhotoImportOutcome? outcome = await _imports.importAtCaret(
      importer,
      reportFailure: false,
    );
    if (outcome case PhotoImportFailed(
      :final Object error,
      :final StackTrace? stackTrace,
    )) {
      Error.throwWithStackTrace(error, stackTrace ?? StackTrace.current);
    }
  }

  Listenable _mergedGeometry(ScrollController scrollController) =>
      Listenable.merge(<Listenable>[scrollController, _geometryRevision]);

  SpellChecker? _createSpellChecker(Locale locale) {
    if (!spellCheckAvailable) {
      return null;
    }
    final SpellCheckService? service = noteSpellCheckService(
      defaultTargetPlatform,
    );
    if (service == null) {
      return null;
    }
    return SpellChecker(
      service: service,
      state: _controller.state,
      locale: locale,
      enabled: widget.spellCheckEnabled,
    )..addListener(_markNeedsBuild);
  }

  NoteCaretReveal _createReveal() => NoteCaretReveal(
    scrollController: widget.scrollController,
    renderView: () => _renderView,
    isFocused: () => widget.focusNode.hasFocus,
    flutterView: View.of(context),
    handlesShown: () => _overlay.handlesShown,
    handleControls: defaultTargetPlatform == TargetPlatform.android
        ? materialTextSelectionHandleControls
        : null,
  );

  void _attachController(NoteEditorController controller) {
    controller
      ..attachSurface(this)
      ..addTransactionListener(_handleTransaction);
    _lastSelection = controller.state.selection;
  }

  void _detachController(NoteEditorController controller) {
    controller
      ..removeTransactionListener(_handleTransaction)
      ..detachSurface(this);
  }

  void _attachUndo(UndoHistoryController undoController) {
    undoController.onUndo.addListener(_undo);
    undoController.onRedo.addListener(_redo);
  }

  void _detachUndo(UndoHistoryController undoController) {
    undoController.onUndo.removeListener(_undo);
    undoController.onRedo.removeListener(_redo);
  }

  void _undo() => _controller.undo();

  void _redo() => _controller.redo();

  void _syncUndoValue() {
    final UndoHistoryValue next = UndoHistoryValue(
      canUndo: _controller.canUndo,
      canRedo: _controller.canRedo,
    );
    if (widget.undoController.value != next) {
      widget.undoController.value = next;
    }
  }

  void _syncUndoValueAfterFrame() {
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        _syncUndoValue();
      }
    });
  }

  void _syncPasteDrop() {
    final PhotoMediaImporter? importer = widget.photoMediaImporter;
    if (importer == null) {
      _disposePasteDrop();
      return;
    }
    if (_pasteDrop != null && _pasteDropImporter == importer) {
      return;
    }
    _disposePasteDrop();
    _pasteDropImporter = importer;
    _pasteDrop = PhotoPasteDrop(
      platform: defaultTargetPlatform,
      imports: _imports,
      importPhoto: importer,
      dropTargets: _dropTargets,
      onSkipped: (String message) => _showToast(message),
    )..addListener(_markNeedsBuild);
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      _fileDrops = FileDropChannel.instance.events.listen(_handleFileDrop);
    }
  }

  void _disposePasteDrop() {
    unawaited(_fileDrops?.cancel());
    _fileDrops = null;
    _pasteDrop
      ?..removeListener(_markNeedsBuild)
      ..dispose();
    _pasteDrop = null;
    _pasteDropImporter = null;
  }

  void _markNeedsBuild() {
    if (!mounted) {
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted) {
          setState(() {});
        }
      });
      return;
    }
    setState(() {});
  }

  void _refreshActiveLine() {
    _activeLine = _activeLineFor(_state);
  }

  ActiveLine? _activeLineFor(EditorState state) {
    final bool composing = _composition.isActive || state.composing != null;
    final bool frozen = composing || _dragging;
    final ActiveLine? line = nextActiveLine(
      previous: _activeLine,
      source: state.source,
      tree: state.tree,
      selection: state.selection,
      focused: widget.focusNode.hasFocus,
      composing: composing,
      dragging: _dragging,
    );
    if (line == null || !frozen || _hasLine(state.source, line.line)) {
      return line;
    }
    return activeLineAt(state.source, state.tree, state.selection);
  }

  static bool _hasLine(String source, int line) {
    int breaks = 0;
    for (int at = 0; at < source.length && breaks < line; at++) {
      if (source.codeUnitAt(at) == _lineFeed) {
        breaks += 1;
      }
    }
    return breaks >= line;
  }

  void _refreshActiveLineAndSend() {
    final ActiveLine? before = _activeLine;
    _refreshActiveLine();
    if (_activeLine != before) {
      _client.sendStateIfChanged();
    }
  }

  VisibleText get _visible {
    final EditorState state = _state;
    final ActiveLine? line = _activeLine;
    final _Projection? cached = _current;
    if (cached != null && cached.matches(state, line)) {
      return cached.visible;
    }
    final _Projection? scratch = _scratch;
    final _Projection projection =
        scratch != null && scratch.sharesContent(state, line)
        ? _Projection(state, line, scratch.visible)
        : _Projection(state, line, _projectNote(state, line));
    _current = projection;
    return projection.visible;
  }

  VisibleText _visibleFor(EditorState state) {
    final EditorState current = _state;
    if (identical(state.source, current.source) &&
        identical(state.tree, current.tree)) {
      return _visible;
    }
    final ActiveLine? line = _activeLineFor(state);
    final _Projection? cached = _scratch;
    if (cached != null && cached.matches(state, line)) {
      return cached.visible;
    }
    final _Projection projection = _Projection(
      state,
      line,
      _projectNote(state, line),
    );
    _scratch = projection;
    return projection.visible;
  }

  VisibleText _projectNote(EditorState state, ActiveLine? line) {
    _projections += 1;
    return const NoteVisibleProjector().project(
      state.source,
      state.tree,
      line?.line,
      activeCell: line?.cell,
    );
  }

  int get _plainVisibleLength {
    final EditorState state = _state;
    if (identical(_plainSource, state.source) &&
        identical(_plainTree, state.tree)) {
      return _plainLength;
    }
    final VisibleText visible = _visible;
    final int? line = visible.activeLine;
    final int length = line == null || !_showsMarkers(visible, line)
        ? visible.text.length
        : _projectNote(state, null).text.length;
    _plainSource = state.source;
    _plainTree = state.tree;
    _plainLength = length;
    return length;
  }

  static bool _showsMarkers(VisibleText visible, int sourceLine) {
    final List<VisibleLine> lines = visible.lines;
    int low = 0;
    int high = lines.length - 1;
    while (low <= high) {
      final int middle = (low + high) >> 1;
      final VisibleLine candidate = lines[middle];
      if (candidate.sourceLine == sourceLine) {
        return candidate.spans.any(
          (VisibleSpan span) => span.kind == VisibleSpanKind.marker,
        );
      }
      if (candidate.sourceLine < sourceLine) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return false;
  }

  LaidOutNote _runLayout(LayoutInputs inputs) {
    final LaidOutNote? previous = _layout;
    final LaidOutNote laidOut = _engine.layout(inputs);
    _layout = laidOut;
    if (previous != null &&
        (!mapEquals(
              previous.inputs.mediaDimensions,
              inputs.mediaDimensions,
            ) ||
            !setEquals(
              previous.inputs.unavailableMedia,
              inputs.unavailableMedia,
            ))) {
      _actions.resetVerticalRun();
    }
    _scheduleGeometryCheck();
    return laidOut;
  }

  LaidOutNote get _freshLayout {
    final LaidOutNote? layout = _layout;
    if (layout == null) {
      throw StateError('NoteEditorView has not laid out its note yet');
    }
    final EditorState state = _state;
    final VisibleText visible = _visible;
    final LayoutInputs inputs = layout.inputs;
    if (identical(inputs.source, state.source) &&
        identical(inputs.tree, state.tree) &&
        identical(inputs.visibleText, visible)) {
      return layout;
    }
    return _runLayout(
      LayoutInputs(
        source: state.source,
        tree: state.tree,
        visibleText: visible,
        activeLine: visible.activeLine,
        columnWidth: inputs.columnWidth,
        textScaler: inputs.textScaler,
        boldText: inputs.boldText,
        locale: inputs.locale,
        readerMode: inputs.readerMode,
        mediaDimensions: inputs.mediaDimensions,
        unavailableMedia: inputs.unavailableMedia,
      ),
    );
  }

  void _scheduleGeometryCheck() {
    if (_geometryCheckScheduled) {
      return;
    }
    _geometryCheckScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _geometryCheckScheduled = false;
      if (mounted && !identical(_geometryLayout, _layout)) {
        _geometryRevision.value += 1;
      }
    });
  }

  void _handleTransaction(Transaction transaction) {
    final EditorState state = _state;
    _refreshActiveLine();
    _client.editorChanged(transaction.changes);
    _imports.mapThrough(transaction.changes);
    _spellChecker?.didChange(state, transaction.changes);
    _syncUndoValue();
    if (_removalToastArmed) {
      _removalToastArmed = false;
      dismissTransientToast();
    }
    if (state.selection != _lastSelection) {
      _lastSelection = state.selection;
      _captionLine = null;
    }
    if (!transaction.changes.isEmpty) {
      _scheduleReveal();
    }
    _markNeedsBuild();
  }

  void _handleFocusChange(bool focused) {
    _refreshActiveLine();
    _client.focusChanged(widget.focusNode);
    _client.sendStateIfChanged();
    _markNeedsBuild();
  }

  void _scheduleReveal() => _reveal?.scheduleReveal(animate: true);

  void _applyInput(Transaction transaction) {
    final CompositionStep step = admitTransaction(
      _composition,
      before: _controller.state,
      transaction: transaction,
      activeLine: _activeLine,
      window: _client.window,
    );
    _composition = step.composition;
    _controller.dispatch(step.transaction);
  }

  void _dispatchAfterCommit(Transaction transaction) {
    commitComposition();
    _controller.dispatch(transaction);
  }

  Transaction _selectionOnly(
    EditorState state,
    NoteSelection selection, {
    TransactionEvent event = TransactionEvent.external,
  }) => Transaction(
    changes: ChangeSet.empty(state.source.length),
    selection: selection,
    event: event,
    addToHistory: false,
  );

  void _changeSelection(
    NoteSelection selection,
    SelectionChangedCause? cause, {
    bool recallKeyboard = false,
  }) {
    if (!mounted) {
      return;
    }
    if (selectionLeavesComposition(_composition, selection)) {
      commitComposition();
    }
    final EditorState state = _controller.state;
    final int length = state.source.length;
    final NoteSelection next = NoteSelection(
      anchor: selection.anchor.clamp(0, length),
      head: selection.head.clamp(0, length),
      affinity: selection.affinity,
    );
    if (next != state.selection) {
      _controller.dispatch(_selectionOnly(state, next));
    }
    if (recallKeyboard || _recallsKeyboard(cause)) {
      _client.showKeyboard(widget.focusNode);
    }
    if (cause == SelectionChangedCause.keyboard) {
      _scheduleReveal();
    }
    if (cause == SelectionChangedCause.tap &&
        defaultTargetPlatform == TargetPlatform.android &&
        next.isCollapsed &&
        _spellChecker?.markAt(next.head) != null) {
      _showToolbarAfterFrame(anchor: null, sourceOffset: next.head);
    }
  }

  static bool _recallsKeyboard(SelectionChangedCause? cause) =>
      switch (cause) {
        SelectionChangedCause.tap ||
        SelectionChangedCause.doubleTap ||
        SelectionChangedCause.longPress ||
        SelectionChangedCause.forcePress ||
        SelectionChangedCause.drag => true,
        _ => false,
      };

  void _handleGestureSelection(
    NoteSelection selection,
    SelectionChangedCause cause,
  ) {
    if (_photoDragActive || _ignoreGestureSelection) {
      return;
    }
    _changeSelection(selection, cause);
  }

  void _handleGestureDrag(bool active) {
    if (_gestureDragActive == active) {
      return;
    }
    _gestureDragActive = active;
    _refreshActiveLineAndSend();
    _markNeedsBuild();
  }

  void _toggleCheckbox(int boxStart) => _controller.applyCommand(
    (EditorState state) => toggleTaskAt(state, boxStart),
  );

  void _selectPhotoLine(int lineStart, {bool recallKeyboard = false}) {
    final EditorState state = _state;
    final MdBlock? block = _photoBlockAt(state, lineStart);
    if (block == null) {
      return;
    }
    _changeSelection(
      photoSelection(state.source, block),
      null,
      recallKeyboard: recallKeyboard,
    );
  }

  static MdBlock? _photoBlockAt(EditorState state, int lineStart) {
    if (lineStart < 0 || lineStart > state.source.length) {
      return null;
    }
    final MdBlock? block = state.tree.blockAt(lineStart);
    return block != null &&
            block.kind == MdBlockKind.photoLine &&
            block.sourceRange.start == lineStart
        ? block
        : null;
  }

  void _showContextMenu(Offset globalPosition) {
    final RenderNoteView? view = _renderView;
    if (view == null) {
      return;
    }
    final int offset = view.noteLayout
        .positionAt(view.globalToContent(globalPosition))
        .offset;
    _showToolbarAfterFrame(anchor: globalPosition, sourceOffset: offset);
  }

  void _showToolbarAfterFrame({
    required Offset? anchor,
    required int sourceOffset,
  }) {
    SchedulerBinding.instance
      ..addPostFrameCallback((Duration _) {
        if (!mounted) {
          return;
        }
        _overlay.showToolbar(
          anchor: anchor,
          leadingItems: _spellItems(sourceOffset),
        );
      })
      ..ensureVisualUpdate();
  }

  List<ContextMenuButtonItem> _spellItems(int sourceOffset) =>
      _spellChecker?.suggestionItems(
        state: _controller.state,
        sourceOffset: sourceOffset,
        onCommand: (Transaction? Function(EditorState state) command) {
          _controller.applyCommand(command);
          _overlay.hideToolbar();
        },
      ) ??
      const <ContextMenuButtonItem>[];

  Future<void> _paste(SelectionChangedCause cause) async {
    final PhotoPasteDrop? pasteDrop = _pasteDrop;
    if (pasteDrop != null && await pasteDrop.paste()) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (tableAtCaret(_controller.state) != null) {
      final ClipboardData? data = await Clipboard.getData(
        Clipboard.kTextPlain,
      );
      final String? text = data?.text;
      if (!mounted || text == null || text.isEmpty) {
        return;
      }
      _controller.applyCommand(
        (EditorState state) => replaceInCell(state, text, paste: true),
      );
      return;
    }
    await _clipboard.pasteText(cause);
  }

  void _handleImportOutcome(PhotoImportOutcome outcome) {
    if (!mounted) {
      return;
    }
    switch (outcome) {
      case PhotoImportInserted(:final PhotoCommandResult result):
        commitComposition();
        _controller.dispatch(result.transaction);
        _scheduleReveal();
        _showToast(photoAddedToastMessage, lifetime: photoAddedToastLifetime);
      case PhotoImportFailed(:final String message):
        _showToast(message, glyph: IconStickerGlyph.close);
    }
  }

  void _showToast(
    String message, {
    IconStickerGlyph glyph = IconStickerGlyph.check,
    Duration? lifetime,
  }) {
    if (!mounted) {
      return;
    }
    _removalToastArmed = false;
    showTransientToast(context, message, glyph: glyph, lifetime: lifetime);
  }

  void _handleFileDrop(FileDropEvent event) {
    final PhotoPasteDrop? pasteDrop = _pasteDrop;
    final RenderNoteView? view = _renderView;
    if (!mounted || pasteDrop == null || view == null) {
      return;
    }
    final Rect bounds = _viewGlobalRect();
    switch (event) {
      case FileDropHover(:final Offset position):
        if (bounds.contains(position)) {
          pasteDrop.hover(view.globalToContent(position));
        } else {
          pasteDrop.leave();
        }
      case FileDropLeave():
        pasteDrop.leave();
      case FileDropped(:final Offset position, :final List<String> paths):
        if (bounds.contains(position)) {
          unawaited(pasteDrop.drop(view.globalToContent(position), paths));
        } else {
          pasteDrop.leave();
        }
    }
  }

  Rect _viewGlobalRect() {
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize) {
      return Rect.zero;
    }
    return MatrixUtils.transformRect(
      object.getTransformTo(null),
      Offset.zero & object.size,
    );
  }

  Rect _renderViewGlobalRect() {
    final RenderNoteView? view = _renderView;
    if (view == null || !view.hasSize) {
      return Rect.zero;
    }
    return MatrixUtils.transformRect(
      view.getTransformTo(null),
      Offset.zero & view.size,
    );
  }

  List<PhotoDropTarget> _dropTargets() {
    final LaidOutNote? layout = _currentLayout;
    if (layout == null) {
      return const <PhotoDropTarget>[];
    }
    final EditorState state = _state;
    return photoDropTargets(state.source, state.tree, layout);
  }

  static PhotoRect? _photoRectFor(NoteLayout layout, int start, int end) {
    for (final PhotoRect rect in layout.photoRects) {
      if (rect.sourceRange.start == start && rect.sourceRange.end == end) {
        return rect;
      }
    }
    return null;
  }

  void _handlePointerDown(PointerDownEvent event) {
    final RenderNoteView? view = _renderView;
    final LaidOutNote? layout = _currentLayout;
    if (view == null || layout == null) {
      return;
    }
    final TextRange? line = view.photoLineAt(
      view.globalToContent(event.position),
    );
    if (line == null) {
      return;
    }
    final MdBlock? block = _photoBlockAt(_state, line.start);
    final PhotoRect? rect = _photoRectFor(layout, line.start, line.end);
    if (block == null || rect == null) {
      return;
    }
    _drag.pointerDown(event, block, rect.rect);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_drag.pointerMove(event) && !_photoDragActive) {
      _photoDragActive = true;
      _refreshActiveLineAndSend();
      _markNeedsBuild();
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    final Transaction? transaction = _drag.pointerUp(event);
    _endPhotoDrag();
    if (transaction != null) {
      _controller.applyCommand((EditorState _) => transaction);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _drag.pointerCancel();
    _endPhotoDrag();
  }

  void _endPhotoDrag() {
    if (!_photoDragActive) {
      return;
    }
    _photoDragActive = false;
    _ignoreGestureSelection = true;
    scheduleMicrotask(() => _ignoreGestureSelection = false);
    _refreshActiveLineAndSend();
    _markNeedsBuild();
  }

  void _handleDragChanged() {
    final PhotoDragSession? session = _drag.session;
    final bool active = session != null;
    final PhotoDropTarget? target = session?.target;
    if (active == _shownDragSession && target == _shownDragTarget) {
      return;
    }
    _shownDragSession = active;
    _shownDragTarget = target;
    _markNeedsBuild();
  }

  bool get _canDismiss {
    if (_drag.isDragging || _captionOpen) {
      return true;
    }
    final EditorState state = _state;
    return _selectedPhoto != null && state.tree.blocks.length > 1;
  }

  void _dismiss() {
    if (_drag.escape()) {
      return;
    }
    if (_captionOpen) {
      setState(() {
        _captionLine = null;
      });
      return;
    }
    final TextRange? photo = _selectedPhoto;
    if (photo == null) {
      return;
    }
    final String source = _state.source;
    final int after = _lineBreakLengthAt(source, photo.end);
    final int caret = after > 0
        ? photo.end + after
        : _lineEndBefore(source, photo.start);
    _changeSelection(
      NoteSelection.collapsed(caret),
      SelectionChangedCause.keyboard,
    );
  }

  static int _lineBreakLengthAt(String source, int offset) {
    if (offset < source.length && source.codeUnitAt(offset) == _lineFeed) {
      return 1;
    }
    if (offset + 1 < source.length &&
        source.codeUnitAt(offset) == _carriageReturn &&
        source.codeUnitAt(offset + 1) == _lineFeed) {
      return 2;
    }
    return 0;
  }

  static int _lineEndBefore(String source, int lineStart) {
    if (lineStart <= 0 || source.codeUnitAt(lineStart - 1) != _lineFeed) {
      return lineStart;
    }
    final int lineEnd = lineStart - 1;
    return lineEnd > 0 && source.codeUnitAt(lineEnd - 1) == _carriageReturn
        ? lineEnd - 1
        : lineEnd;
  }

  bool _focusPhotoToolbar() {
    if (!_photoToolbarShown || _toolbarFocusNode.context == null) {
      return false;
    }
    _toolbarFocusNode.requestFocus();
    return true;
  }

  void _scrollBy(double pixels) {
    final ScrollController controller = widget.scrollController;
    if (!controller.hasClients) {
      return;
    }
    final ScrollPosition position = controller.position;
    final double target = (position.pixels + pixels).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target != position.pixels) {
      position.jumpTo(target);
    }
  }

  void _scrollToEdge({required bool end}) {
    final ScrollController controller = widget.scrollController;
    if (!controller.hasClients) {
      return;
    }
    final ScrollPosition position = controller.position;
    final double target = end
        ? position.maxScrollExtent
        : position.minScrollExtent;
    if (target != position.pixels) {
      position.jumpTo(target);
    }
  }

  void _runClassified(ClassifiedEdit edit) {
    final EditorState state = _controller.state;
    switch (edit) {
      case BackspaceEdit():
        _dispatchIfAny(_deletion(state, forward: false));
      case ForwardDeleteEdit():
        _dispatchIfAny(_deletion(state, forward: true));
      case SelectPhotoEdit(:final MdRange photoLine):
        final MdBlock? block = _photoBlockAt(state, photoLine.start);
        if (block != null) {
          _controller.dispatch(
            _selectionOnly(state, photoSelection(state.source, block)),
          );
        }
      case RemovePhotoEdit(:final MdRange photoLine):
        final MdBlock? block = _photoBlockAt(state, photoLine.start);
        if (block != null) {
          final PhotoEdit removal = photoRemoval(
            state.source,
            state.tree,
            block,
          );
          _controller.dispatch(
            Transaction(
              changes: removal.changes,
              selection: removal.selection,
              event: TransactionEvent.photo,
            ),
          );
        }
      case ListMarkerEdit(:final int contentStart):
        _dispatchIfAny(
          backspaceAtItemStart(
            state.withSelection(NoteSelection.collapsed(contentStart)),
          ),
        );
      case EnterEdit():
        _dispatchIfAny(
          _commands.commandFor(NoteCommandId.enter)?.call(state) ??
              _insertion(state, '\n'),
        );
      case TableCellTextEdit(:final MdRange replaced, :final String text):
        _dispatchIfAny(
          replaceInCell(
            state.withSelection(
              NoteSelection(anchor: replaced.start, head: replaced.end),
            ),
            text,
          ),
        );
      case RejectedEdit():
        break;
      case TypeAfterPhotoEdit(:final String text, :final bool composing):
        final bool isBreak = text == '\n' || text == '\r\n';
        final Transaction? typed = typeOverSelectedPhoto(
          state,
          isBreak ? '' : text,
          composing: composing && !isBreak && text.isNotEmpty,
        );
        if (typed == null) {
          return;
        }
        if (typed.composing != null) {
          _applyInput(typed);
        } else {
          _controller.dispatch(typed);
        }
    }
  }

  void _dispatchIfAny(Transaction? transaction) {
    if (transaction != null) {
      _controller.dispatch(transaction);
    }
  }

  Transaction? _deletion(EditorState state, {required bool forward}) =>
      _commands
          .commandFor(
            forward ? NoteCommandId.deleteForward : NoteCommandId.deleteBackward,
          )
          ?.call(state) ??
      _graphemeDeletion(state, forward: forward);

  Transaction? _graphemeDeletion(EditorState state, {required bool forward}) {
    final NoteSelection selection = state.selection;
    if (!selection.isCollapsed) {
      return _removal(state, MdRange(selection.start, selection.end));
    }
    final VisibleText visible = _visibleFor(state);
    final String text = visible.text;
    final int caret = visible.map.sourceToVisible(selection.head);
    final int target = forward
        ? _graphemeAfter(text, caret)
        : _graphemeBefore(text, caret);
    if (target == caret) {
      return null;
    }
    return _removal(
      state,
      sourceRangeForVisible(
        state: state,
        visible: visible,
        visibleRange: TextRange(
          start: math.min(caret, target),
          end: math.max(caret, target),
        ),
      ),
    );
  }

  static Transaction? _removal(EditorState state, MdRange range) =>
      range.isEmpty
      ? null
      : Transaction(
          changes: ChangeSet.single(
            state.source.length,
            range.start,
            range.end,
            '',
          ),
          selection: NoteSelection.collapsed(range.start),
          event: TransactionEvent.inputDelete,
        );

  static Transaction _insertion(EditorState state, String text) {
    final NoteSelection selection = state.selection;
    return Transaction(
      changes: ChangeSet.single(
        state.source.length,
        selection.start,
        selection.end,
        text,
      ),
      selection: NoteSelection.collapsed(selection.start + text.length),
      event: TransactionEvent.inputType,
    );
  }

  static int _graphemeAfter(String text, int offset) {
    if (offset >= text.length) {
      return text.length;
    }
    final CharacterRange range = CharacterRange.at(text, offset)
      ..expandNext();
    return range.stringBeforeLength + range.current.length;
  }

  static int _graphemeBefore(String text, int offset) {
    if (offset <= 0) {
      return 0;
    }
    final CharacterRange range = CharacterRange.at(text, offset)
      ..expandBack();
    return range.stringBeforeLength;
  }

  void _noteColumn(double column, TextScaler scaler) {
    final double? lastColumn = _lastColumn;
    final TextScaler? lastScaler = _lastScaler;
    _lastColumn = column;
    _lastScaler = scaler;
    if ((lastColumn != null && lastColumn != column) ||
        (lastScaler != null && lastScaler != scaler)) {
      _actions.resetVerticalRun();
    }
  }

  List<NoteViewDecoration> _decorations() {
    final List<SpellMark> marks =
        _spellChecker?.marks ?? const <SpellMark>[];
    final PhotoDropTarget? dragTarget = _drag.session?.target;
    final PhotoDropTarget? hoverTarget = _pasteDrop?.hoverTarget;
    return List<NoteViewDecoration>.unmodifiable(<NoteViewDecoration>[
      if (marks.isNotEmpty)
        SpellUnderlineDecoration(
          marks: marks,
          platform: defaultTargetPlatform,
        ),
      if (dragTarget != null)
        PhotoInsertionLineDecoration(dragTarget.y)
      else if (hoverTarget != null)
        PhotoInsertionLineDecoration(hoverTarget.y),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final double em = scaler.scale(_emBase);
    return TextFieldTapRegion(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final double height = constraints.maxHeight;
          final double column = math.min(width, _columnEms * em);
          final double left = (width - column) / 2;
          _viewHeight = height;
          _noteColumn(column, scaler);
          return Stack(
            key: _stackKey,
            fit: StackFit.expand,
            children: <Widget>[
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: column,
                  height: height,
                  child: _buildEditor(context),
                ),
              ),
              _geometry(
                (BuildContext context, BoxConstraints layer) =>
                    _buildSurface(layer, left: left, column: column),
              ),
              _geometry(
                (BuildContext context, BoxConstraints layer) =>
                    _buildOverlays(context, column: column, em: em),
              ),
              KeyedSubtree(
                key: notePhotoToolbarLayerKey,
                child: _geometry(
                  (BuildContext context, BoxConstraints layer) =>
                      _buildToolbarLayer(
                        context,
                        layer,
                        column: column,
                        em: em,
                      ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _geometry(
    Widget Function(BuildContext context, BoxConstraints constraints) builder,
  ) => ListenableBuilder(
    listenable: _geometryListenable,
    builder: (BuildContext context, Widget? _) =>
        LayoutBuilder(builder: builder),
  );

  Widget _buildEditor(BuildContext context) {
    final EditorState state = _state;
    final MdRange? composing = state.composing;
    return Shortcuts(
      shortcuts: noteShortcuts(defaultTargetPlatform),
      child: Actions(
        actions: _actions.actions,
        child: Focus(
          key: _keyScopeKey,
          focusNode: widget.focusNode,
          includeSemantics: false,
          onFocusChange: _handleFocusChange,
          child: Listener(
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerCancel,
            child: NoteMouseSelection(
              renderKey: _renderKey,
              focusNode: widget.focusNode,
              onSelectionChanged: _handleGestureSelection,
              onDragActiveChanged: _handleGestureDrag,
              onToggleCheckbox: _toggleCheckbox,
              onContextMenu: _showContextMenu,
              child: NoteTouchSelection(
                renderKey: _renderKey,
                overlay: _overlay,
                focusNode: widget.focusNode,
                onSelectionChanged: _handleGestureSelection,
                onDragActiveChanged: _handleGestureDrag,
                onToggleCheckbox: _toggleCheckbox,
                child: NoteInputCompositionCallback(
                  client: _client,
                  child: NoteView(
                    source: state.source,
                    tree: state.tree,
                    visibleText: _visible,
                    runLayout: _runLayout,
                    mediaResolver: ComposerMediaScope.maybeResolverOf(context),
                    activeLine: _activeLine?.line,
                    selection: state.selection,
                    composing: composing == null
                        ? TextRange.empty
                        : TextRange(start: composing.start, end: composing.end),
                    focused: widget.focusNode.hasFocus,
                    scrollController: widget.scrollController,
                    bottomInset: widget.bottomInset,
                    hintText: widget.hintText,
                    hintStyle: widget.hintStyle,
                    cursorColor: widget.cursorColor,
                    platformValue: _client.hasConnection
                        ? _client.mirror.value
                        : null,
                    platformValueStart: _client.hasConnection
                        ? _client.windowBase
                        : 0,
                    delegate: _delegate,
                    startHandleLayerLink: _overlay.startHandleLayerLink,
                    endHandleLayerLink: _overlay.endHandleLayerLink,
                    toolbarLayerLink: _overlay.toolbarLayerLink,
                    selectedCaptionHidden: _captionOpen,
                    decorations: _decorations(),
                    renderKey: _renderKey,
                    onFontsChanged: _engine.clearCache,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset? _contentToLayer(Offset content) {
    final RenderNoteView? view = _renderView;
    final RenderBox? stack = _stackBox;
    if (view == null || stack == null) {
      return null;
    }
    return MatrixUtils.transformPoint(
      view.getTransformTo(stack),
      view.contentToLocal(content),
    );
  }

  Rect? _contentRectToLayer(Rect content) {
    final Offset? topLeft = _contentToLayer(content.topLeft);
    final Offset? bottomRight = _contentToLayer(content.bottomRight);
    return topLeft == null || bottomRight == null
        ? null
        : Rect.fromPoints(topLeft, bottomRight);
  }

  Rect? _renderViewInLayer() {
    final RenderNoteView? view = _renderView;
    final RenderBox? stack = _stackBox;
    if (view == null || stack == null || !view.hasSize) {
      return null;
    }
    return MatrixUtils.transformRect(
      view.getTransformTo(stack),
      Offset.zero & view.size,
    );
  }

  void _updateSpellViewport(RenderNoteView view, LaidOutNote layout) {
    final SpellChecker? checker = _spellChecker;
    if (checker == null) {
      return;
    }
    final Rect visible = view.visibleContentRect;
    final double bottom = layout.size.height;
    final int start = layout
        .positionAt(Offset(0, visible.top.clamp(0, bottom)))
        .offset;
    final int end = layout
        .positionAt(Offset(visible.right, visible.bottom.clamp(0, bottom)))
        .offset;
    checker.viewport = MdRange(math.min(start, end), math.max(start, end));
  }

  Widget _buildSurface(
    BoxConstraints constraints, {
    required double left,
    required double column,
  }) {
    final LaidOutNote? layout = _layout;
    _geometryLayout = layout;
    final RenderNoteView? view = _renderView;
    if (view != null && layout != null && identical(view.noteLayout, layout)) {
      _updateSpellViewport(view, layout);
    }
    final double scroll = view?.scrollOffset ?? 0;
    final double contentHeight = layout?.size.height ?? 0;
    final double height = math.max(
      math.max(0, constraints.maxHeight - widget.bottomInset),
      contentHeight,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: left,
          top: -scroll,
          width: column,
          height: height,
          child: const IgnorePointer(
            child: SizedBox.expand(key: noteEditorKey),
          ),
        ),
      ],
    );
  }

  Widget _buildOverlays(
    BuildContext context, {
    required double column,
    required double em,
  }) {
    final LaidOutNote? layout = _currentLayout;
    if (layout == null || _renderView == null) {
      return const SizedBox.shrink();
    }
    final Size size = photoImportPlaceholderSize(columnWidth: column, em: em);
    final List<PhotoDropTarget> targets = _imports.placeholders.isEmpty
        ? const <PhotoDropTarget>[]
        : _dropTargets();
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: PhotoDragOverlay(
              controller: _drag,
              contentToLocal: (Offset content) =>
                  _contentToLayer(content) ?? content,
              ghost: _dragGhost(context, layout),
            ),
          ),
        ),
        for (final PhotoImportPlaceholder placeholder in _imports.placeholders)
          if (_contentToLayer(
                Offset(
                  column - size.width,
                  _placeholderTop(placeholder.target, layout, targets),
                ),
              )
              case final Offset topLeft)
            Positioned(
              left: topLeft.dx,
              top: topLeft.dy,
              width: size.width,
              height: size.height,
              child: IgnorePointer(
                child: PhotoImportPlaceholderBox(size: size),
              ),
            ),
      ],
    );
  }

  double _placeholderTop(
    PhotoTarget target,
    LaidOutNote layout,
    List<PhotoDropTarget> targets,
  ) {
    final int length = _state.source.length;
    switch (target) {
      case PhotoBoundaryTarget(:final int boundary):
        for (final PhotoDropTarget candidate in targets) {
          if (candidate.boundary == boundary) {
            return candidate.y;
          }
        }
        return layout
            .caretRect(boundary.clamp(0, length), TextAffinity.downstream)
            .bottom;
      case PhotoEmptyLineTarget(:final int start):
        return layout
            .lineBoxAt(start.clamp(0, length), TextAffinity.downstream)
            .rect
            .top;
    }
  }

  Widget _dragGhost(BuildContext context, LaidOutNote layout) {
    final PhotoDragSession? session = _drag.session;
    if (session == null) {
      return const SizedBox.shrink();
    }
    final MdRange range = session.photo.sourceRange;
    final PhotoRect? rect = _photoRectFor(layout, range.start, range.end);
    if (rect == null) {
      return const SizedBox.shrink();
    }
    final MdPhotoLine line = MdPhotoLine.ofBlock(session.photo, session.source);
    return PhotoFigure(
      line: line,
      rect: rect,
      media: ComposerMediaScope.maybeResolverOf(
        context,
      )?.resolved(line.reference),
      resolver: ComposerMediaScope.maybeResolverOf(context),
    );
  }

  Widget _buildToolbarLayer(
    BuildContext context,
    BoxConstraints constraints, {
    required double column,
    required double em,
  }) {
    final Widget? photoToolbar = _photoToolbar(
      context,
      constraints,
      column: column,
      em: em,
    );
    _photoToolbarShown = photoToolbar != null;
    final Widget? tableToolbar = _tableToolbar(constraints);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[?photoToolbar, ?tableToolbar],
    );
  }

  Widget? _photoToolbar(
    BuildContext context,
    BoxConstraints constraints, {
    required double column,
    required double em,
  }) {
    final NotePhotoToolbarBuilder? builder = widget.photoToolbarBuilder;
    final LaidOutNote? layout = _currentLayout;
    final RenderNoteView? view = _renderView;
    final TextRange? selected = _selectedPhoto;
    if (builder == null ||
        layout == null ||
        view == null ||
        selected == null) {
      return null;
    }
    final PhotoRect? rect = _photoRectFor(layout, selected.start, selected.end);
    if (rect == null || !rect.rect.overlaps(view.visibleContentRect)) {
      return null;
    }
    final Rect? photoRect = _contentRectToLayer(rect.imageRect);
    final double captionTop = rect.imageRect.bottom + photoFigureCaptionGap;
    final Rect? captionRect = _contentRectToLayer(
      Rect.fromLTWH(
        rect.rect.left,
        captionTop,
        rect.rect.width,
        math.max(0, rect.rect.bottom - captionTop),
      ),
    );
    if (photoRect == null || captionRect == null) {
      return null;
    }
    final EditorState state = _state;
    final int ordinal = state.tree.blocks
        .where(
          (MdBlock block) =>
              block.kind == MdBlockKind.photoLine &&
              block.sourceRange.start < selected.start,
        )
        .length;
    final int lineStart = selected.start;
    return builder(
      context,
      NotePhotoToolbarRequest(
        controller: _controller,
        photoLineStart: lineStart,
        ordinal: ordinal,
        photoRect: photoRect,
        captionRect: captionRect,
        surface: Rect.fromLTWH(
          0,
          0,
          constraints.maxWidth,
          math.max(0, constraints.maxHeight - widget.bottomInset),
        ),
        bottomInset: widget.bottomInset,
        columnWidth: column,
        em: em,
        phoneColumn: column < _desktopColumnEms * em,
        captionOpen: _captionOpen,
        importer: widget.photoImporter,
        firstControlFocusNode: _toolbarFocusNode,
        onOpenCaption: () => _setCaptionLine(lineStart),
        onCloseCaption: () => _setCaptionLine(null),
        onReturnToEditor: widget.focusNode.requestFocus,
        onRemovalToastShown: _armRemovalToast,
      ),
    );
  }

  void _setCaptionLine(int? line) {
    if (!mounted || _captionLine == line) {
      return;
    }
    _captionLine = line;
    _markNeedsBuild();
  }

  void _armRemovalToast() {
    _removalToastArmed = true;
  }

  Widget? _tableToolbar(BoxConstraints constraints) {
    if (!tablesEnabled) {
      return null;
    }
    final EditorState state = _state;
    final MdRange? table = tableAtCaret(state);
    final LaidOutNote? layout = _currentLayout;
    if (table == null || layout == null) {
      return null;
    }
    final Rect? tableRect = _contentRectToLayer(layout.rangeBounds(table));
    final Rect? viewRect = _renderViewInLayer();
    if (tableRect == null || viewRect == null) {
      return null;
    }
    final Rect visible = Rect.fromLTRB(
      viewRect.left,
      viewRect.top,
      viewRect.right,
      math.max(viewRect.top, viewRect.bottom - widget.bottomInset),
    );
    if (!tableRect.overlaps(visible)) {
      return null;
    }
    return CustomSingleChildLayout(
      delegate: _TableToolbarPlacement(
        table: tableRect,
        view: visible,
        surface: Offset.zero & constraints.biggest,
      ),
      child: TableToolbar(
        state: state,
        onTransaction: (Transaction transaction) =>
            _controller.applyCommand((EditorState _) => transaction),
        onDismiss: widget.focusNode.requestFocus,
        tapRegionGroupId: EditableText,
        enabled: tablesEnabled,
      ),
    );
  }
}

final class _TableToolbarPlacement extends SingleChildLayoutDelegate {
  const _TableToolbarPlacement({
    required this.table,
    required this.view,
    required this.surface,
  });

  final Rect table;
  final Rect view;
  final Rect surface;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(surface.size);

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      tableToolbarRect(
        table: table,
        bar: childSize,
        view: view,
        surface: surface,
      )?.topLeft ??
      table.topLeft;

  @override
  bool shouldRelayout(_TableToolbarPlacement oldDelegate) =>
      oldDelegate.table != table ||
      oldDelegate.view != view ||
      oldDelegate.surface != surface;
}

final class _EditorInputHost implements NoteInputHost {
  const _EditorInputHost(this._view);

  final NoteEditorViewState _view;

  @override
  EditorState get state => _view._state;

  @override
  VisibleText get visible => _view._visible;

  @override
  VisibleText visibleFor(EditorState state) => _view._visibleFor(state);

  @override
  int get plainVisibleLength => _view._plainVisibleLength;

  @override
  NoteLayout? get layout => _view._layout;

  @override
  RenderBox? get renderBox => _view._renderView;

  @override
  Offset contentToLocal(Offset contentPoint) =>
      _view._renderView?.contentToLocal(contentPoint) ?? contentPoint;

  @override
  int get viewId => View.of(_view.context).viewId;

  @override
  void applyInput(Transaction transaction) => _view._applyInput(transaction);

  @override
  void runClassified(ClassifiedEdit edit) => _view._runClassified(edit);

  @override
  void insertContent(KeyboardInsertedContent content) {
    final PhotoPasteDrop? pasteDrop = _view._pasteDrop;
    if (pasteDrop != null) {
      unawaited(pasteDrop.insertKeyboardContent(content));
    }
  }

  @override
  void performSelector(String selectorName) {
    final BuildContext? scope = _view._keyScopeKey.currentContext;
    if (scope != null) {
      invokeMacOSSelector(scope, selectorName);
    }
  }
}

final class _EditorActionHost implements NoteActionHost {
  const _EditorActionHost(this._view);

  final NoteEditorViewState _view;

  @override
  EditorState get state => _view._state;

  @override
  VisibleText get visible => _view._visible;

  @override
  NoteLayout get layout => _view._freshLayout;

  @override
  CommandRegistry get commands => _view._commands;

  @override
  double get viewportHeight =>
      math.max(0, _view._viewHeight - _view.widget.bottomInset);

  @override
  bool get canDismiss => _view._canDismiss;

  @override
  void apply(Transaction transaction) =>
      _view._dispatchAfterCommit(transaction);

  @override
  void select(NoteSelection selection, SelectionChangedCause cause) =>
      _view._changeSelection(selection, cause);

  @override
  void scrollBy(double pixels) => _view._scrollBy(pixels);

  @override
  void scrollToEdge({required bool end}) => _view._scrollToEdge(end: end);

  @override
  void copy({required bool cut}) => unawaited(
    cut
        ? _view._clipboard.cutSelection(SelectionChangedCause.keyboard)
        : _view._clipboard.copySelection(SelectionChangedCause.keyboard),
  );

  @override
  Future<void> paste() => _view._paste(SelectionChangedCause.keyboard);

  @override
  void undo() => _view._controller.undo();

  @override
  void redo() => _view._controller.redo();

  @override
  void dismiss() => _view._dismiss();

  @override
  bool focusPhotoToolbar() => _view._focusPhotoToolbar();
}

final class _EditorViewDelegate implements NoteViewDelegate {
  const _EditorViewDelegate(this._view);

  final NoteEditorViewState _view;

  @override
  void selectVisible(TextSelection selection) {
    final EditorState state = _view._state;
    final VisibleText visible = _view._visible;
    if (selection.isCollapsed) {
      _view._changeSelection(
        NoteSelection.collapsed(
          sourcePositionForVisible(
            state: state,
            visible: visible,
            visibleOffset: selection.baseOffset,
            affinity: selection.affinity,
          ),
          affinity: selection.affinity,
        ),
        null,
        recallKeyboard: true,
      );
      return;
    }
    final MdRange range = sourceRangeForVisible(
      state: state,
      visible: visible,
      visibleRange: TextRange(start: selection.start, end: selection.end),
    );
    final bool reversed = selection.baseOffset > selection.extentOffset;
    _view._changeSelection(
      NoteSelection(
        anchor: reversed ? range.end : range.start,
        head: reversed ? range.start : range.end,
        affinity: selection.affinity,
      ),
      null,
      recallKeyboard: true,
    );
  }

  @override
  void replaceVisibleText(String text) => _view._client.updateEditingValue(
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );

  @override
  void copySelection() => unawaited(
    _view._clipboard.copySelection(SelectionChangedCause.keyboard),
  );

  @override
  void cutSelection() =>
      unawaited(_view._clipboard.cutSelection(SelectionChangedCause.keyboard));

  @override
  void pasteClipboard() =>
      unawaited(_view._paste(SelectionChangedCause.keyboard));

  @override
  void selectPhoto(int lineStart) =>
      _view._selectPhotoLine(lineStart, recallKeyboard: true);

  @override
  void toggleCheckbox(int boxStart) => _view._toggleCheckbox(boxStart);
}
