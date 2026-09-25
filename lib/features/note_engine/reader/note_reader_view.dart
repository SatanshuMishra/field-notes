import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:field_notes/design/widgets/note_column.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/capabilities.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/gestures/mouse_selection.dart'
    show noteCheckboxAt;
import 'package:field_notes/features/note_engine/layout/note_layout_engine.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:field_notes/features/note_engine/render/note_view.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';
import 'package:field_notes/features/notes/render/note_photo_block.dart'
    show NoteMediaScope;

const double _columnEms = 45;
const String _objectReplacement = '\uFFFC';
const double _touchCheckboxTarget = 48;
const double _mouseCheckboxTarget = 24;

class NoteReaderView extends StatefulWidget {
  const NoteReaderView({
    super.key,
    required this.source,
    this.selectable = true,
    this.onToggleTask,
  });

  final String source;
  final bool selectable;
  final ValueChanged<int>? onToggleTask;

  @override
  State<NoteReaderView> createState() => _NoteReaderViewState();
}

class _NoteReaderViewState extends State<NoteReaderView> {
  final NoteLayoutEngine _engine = NoteLayoutEngine();
  final GlobalKey _renderKey = GlobalKey();
  final ContextMenuController _menu = ContextMenuController();
  final Object _tapGroup = Object();
  late MdTree _tree;
  late VisibleText _visible;
  FocusNode? _focusNode;
  NoteSelection? _selection;
  int _pressOffset = 0;

  @override
  void initState() {
    super.initState();
    _project();
    _focusNode = widget.selectable
        ? FocusNode(debugLabel: 'NoteReaderView')
        : null;
  }

  @override
  void didUpdateWidget(NoteReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _project();
      _selection = null;
      _menu.remove();
    }
    if (oldWidget.selectable != widget.selectable) {
      _focusNode?.dispose();
      _focusNode = widget.selectable
          ? FocusNode(debugLabel: 'NoteReaderView')
          : null;
      _selection = null;
      _menu.remove();
    }
  }

  @override
  void dispose() {
    _menu.remove();
    _focusNode?.dispose();
    super.dispose();
  }

  void _project() {
    _tree = parseNoteTree(widget.source, tables: tablesEnabled);
    _visible = const NoteVisibleProjector().project(widget.source, _tree, null);
  }

  RenderNoteView? get _render {
    final RenderObject? object = _renderKey.currentContext?.findRenderObject();
    return object is RenderNoteView && object.attached ? object : null;
  }

  int? _offsetAt(Offset global) {
    final RenderNoteView? render = _render;
    if (render == null) {
      return null;
    }
    return render.noteLayout.positionAt(render.globalToContent(global)).offset;
  }

  void _select(NoteSelection? selection) {
    if (selection == _selection) {
      return;
    }
    setState(() {
      _selection = selection;
    });
  }

  int? _checkboxAt(Offset global, PointerDeviceKind kind) {
    final RenderNoteView? render = _render;
    if (render == null) {
      return null;
    }
    return noteCheckboxAt(
      render,
      render.globalToContent(global),
      minTarget: kind == PointerDeviceKind.touch
          ? _touchCheckboxTarget
          : _mouseCheckboxTarget,
    );
  }

  NoteSelection _wordAt(int offset) {
    final RenderNoteView? render = _render;
    if (render == null) {
      return NoteSelection.collapsed(offset);
    }
    final MdRange word = render.noteLayout.wordBoundary(offset);
    return NoteSelection(anchor: word.start, head: word.end);
  }

  NoteSelection _sourceLineAt(int offset) {
    final String source = widget.source;
    final int start = offset == 0
        ? 0
        : source.lastIndexOf('\n', offset - 1) + 1;
    final int breakAt = source.indexOf('\n', offset);
    final int lineEnd = breakAt < 0 ? source.length : breakAt;
    final int end = lineEnd > start && source.codeUnitAt(lineEnd - 1) == 0x0D
        ? lineEnd - 1
        : lineEnd;
    return NoteSelection(anchor: start, head: end);
  }

  void _handleTapDown(TapDragDownDetails details) {
    if (widget.onToggleTask != null &&
        _checkboxAt(details.globalPosition, PointerDeviceKind.mouse) != null) {
      return;
    }
    final int? offset = _offsetAt(details.globalPosition);
    _focusNode?.requestFocus();
    _menu.remove();
    if (offset == null) {
      return;
    }
    final NoteSelection? current = _selection;
    switch (details.consecutiveTapCount) {
      case 1:
        _pressOffset = offset;
        _select(
          HardwareKeyboard.instance.isShiftPressed && current != null
              ? NoteSelection(anchor: current.anchor, head: offset)
              : NoteSelection.collapsed(offset),
        );
      case 2:
        _select(_wordAt(_pressOffset));
      default:
        _select(_sourceLineAt(_pressOffset));
    }
  }

  void _handleDragUpdate(TapDragUpdateDetails details) {
    final NoteSelection? current = _selection;
    final int? offset = _offsetAt(details.globalPosition);
    if (current == null || offset == null) {
      return;
    }
    _select(NoteSelection(anchor: current.anchor, head: offset));
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    final int? offset = _offsetAt(details.globalPosition);
    _focusNode?.requestFocus();
    if (offset == null) {
      return;
    }
    _pressOffset = offset;
    _select(_wordAt(offset));
    WidgetsBinding.instance
      ..addPostFrameCallback((Duration _) {
        if (mounted) {
          _showMenu();
        }
      })
      ..ensureVisualUpdate();
  }

  void _handleTapOutside(PointerDownEvent event) {
    _menu.remove();
    _select(null);
  }

  void _showMenu() {
    final RenderNoteView? render = _render;
    final NoteSelection? selection = _selection;
    if (render == null || selection == null) {
      return;
    }
    final Rect? local = render.contentRectToLocal(
      render.noteLayout.rangeBounds(MdRange(selection.start, selection.end)),
    );
    if (local == null) {
      return;
    }
    final TextSelectionToolbarAnchors anchors = TextSelectionToolbarAnchors(
      primaryAnchor: render.localToGlobal(local.topCenter),
      secondaryAnchor: render.localToGlobal(local.bottomCenter),
    );
    _menu.show(
      context: context,
      contextMenuBuilder: (BuildContext context) => TapRegion(
        groupId: _tapGroup,
        child: AdaptiveTextSelectionToolbar.buttonItems(
          anchors: anchors,
          buttonItems: <ContextMenuButtonItem>[
            ContextMenuButtonItem(
              type: ContextMenuButtonType.copy,
              onPressed: () {
                _copy();
                _menu.remove();
              },
            ),
            ContextMenuButtonItem(
              type: ContextMenuButtonType.selectAll,
              onPressed: () {
                _selectAll();
                _menu.remove();
              },
            ),
          ],
        ),
      ),
    );
  }

  String? get _selectedText {
    final NoteSelection? selection = _selection;
    if (selection == null || selection.isCollapsed) {
      return null;
    }
    final OffsetMap map = _visible.map;
    final int length = _visible.text.length;
    final int start = map.sourceToVisible(selection.start).clamp(0, length);
    final int end = map.sourceToVisible(selection.end).clamp(start, length);
    return _visible.text
        .substring(start, end)
        .replaceAll(_objectReplacement, '');
  }

  void _copy() {
    final String? text = _selectedText;
    if (text == null) {
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
  }

  void _selectAll() {
    _select(NoteSelection(anchor: 0, head: widget.source.length));
  }

  Map<ShortcutActivator, Intent> get _shortcuts {
    final bool apple =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.keyC, meta: apple, control: !apple):
          CopySelectionTextIntent.copy,
      SingleActivator(LogicalKeyboardKey.keyA, meta: apple, control: !apple):
          const SelectAllTextIntent(SelectionChangedCause.keyboard),
    };
  }

  Widget _view(BuildContext context) {
    final ValueChanged<int>? onToggleTask = widget.onToggleTask;
    final Widget view = _noteView(context);
    if (onToggleTask == null) {
      return view;
    }
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        _CheckboxTapRecognizer:
            GestureRecognizerFactoryWithHandlers<_CheckboxTapRecognizer>(
              () => _CheckboxTapRecognizer(
                checkboxAt: _checkboxAt,
                debugOwner: this,
              ),
              (_CheckboxTapRecognizer recognizer) {
                recognizer
                  ..checkboxAt = _checkboxAt
                  ..onToggle = onToggleTask;
              },
            ),
      },
      child: view,
    );
  }

  Widget _noteView(BuildContext context) => NoteView(
    renderKey: _renderKey,
    source: widget.source,
    tree: _tree,
    visibleText: _visible,
    runLayout: _engine.layout,
    onFontsChanged: _engine.clearCache,
    mediaResolver: NoteMediaScope.maybeResolverOf(context),
    readOnly: true,
    selection: widget.selectable ? _selection : null,
    onToggleTask: widget.onToggleTask,
  );

  Widget _selectableView(BuildContext context) {
    final FocusNode? focusNode = _focusNode;
    if (focusNode == null) {
      return _view(context);
    }
    return TapRegion(
      groupId: _tapGroup,
      onTapOutside: _handleTapOutside,
      child: Shortcuts(
        shortcuts: _shortcuts,
        child: Actions(
          actions: <Type, Action<Intent>>{
            CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
              onInvoke: (CopySelectionTextIntent intent) {
                _copy();
                return null;
              },
            ),
            SelectAllTextIntent: CallbackAction<SelectAllTextIntent>(
              onInvoke: (SelectAllTextIntent intent) {
                _selectAll();
                return null;
              },
            ),
          },
          child: Focus(
            focusNode: focusNode,
            includeSemantics: false,
            child: RawGestureDetector(
              gestures: <Type, GestureRecognizerFactory>{
                TapAndPanGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      TapAndPanGestureRecognizer
                    >(
                      () => TapAndPanGestureRecognizer(
                        debugOwner: this,
                        supportedDevices: const <PointerDeviceKind>{
                          PointerDeviceKind.mouse,
                        },
                      ),
                      (TapAndPanGestureRecognizer recognizer) {
                        recognizer
                          ..onTapDown = _handleTapDown
                          ..onDragUpdate = _handleDragUpdate;
                      },
                    ),
                LongPressGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      LongPressGestureRecognizer
                    >(
                      () => LongPressGestureRecognizer(
                        debugOwner: this,
                        supportedDevices: const <PointerDeviceKind>{
                          PointerDeviceKind.touch,
                        },
                      ),
                      (LongPressGestureRecognizer recognizer) {
                        recognizer.onLongPressStart = _handleLongPressStart;
                      },
                    ),
              },
              child: _view(context),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool fillsWidth = NoteMeasureScope.fillsWidthOf(context);
    final double em = MediaQuery.textScalerOf(context).scale(16);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double available = constraints.maxWidth;
        final double column = fillsWidth && constraints.hasBoundedWidth
            ? available
            : math.min(available, _columnEms * em);
        return Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: SizedBox(
            width: column,
            child: widget.selectable
                ? _selectableView(context)
                : _view(context),
          ),
        );
      },
    );
  }
}

class _CheckboxTapRecognizer extends TapGestureRecognizer {
  _CheckboxTapRecognizer({required this.checkboxAt, super.debugOwner}) {
    onTapDown = _handleDown;
    onTapCancel = _handleCancel;
    onTap = _handleTap;
  }

  int? Function(Offset global, PointerDeviceKind kind) checkboxAt;
  ValueChanged<int>? onToggle;
  int? _pressed;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      super.isPointerAllowed(event) &&
      checkboxAt(event.position, event.kind) != null;

  void _handleDown(TapDownDetails details) {
    _pressed = checkboxAt(
      details.globalPosition,
      details.kind ?? PointerDeviceKind.touch,
    );
  }

  void _handleCancel() {
    _pressed = null;
  }

  void _handleTap() {
    final int? box = _pressed;
    _pressed = null;
    if (box != null) {
      onToggle?.call(box);
    }
  }
}
