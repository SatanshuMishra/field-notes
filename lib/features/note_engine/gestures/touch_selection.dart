import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/gestures/mouse_selection.dart';
import 'package:field_notes/features/note_engine/gestures/selection_overlay_controller.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';

const double _touchTarget = 48;
const Set<PointerDeviceKind> _touchOnly = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
};

enum _LongPress { none, photo, text }

class NoteTouchSelection extends StatefulWidget {
  const NoteTouchSelection({
    super.key,
    required this.renderKey,
    required this.overlay,
    required this.focusNode,
    required this.onSelectionChanged,
    required this.onDragActiveChanged,
    required this.onToggleCheckbox,
    this.onRequestKeyboard,
    required this.child,
  });

  final GlobalKey renderKey;
  final NoteSelectionOverlayController overlay;
  final FocusNode focusNode;
  final void Function(NoteSelection selection, SelectionChangedCause cause)
  onSelectionChanged;
  final ValueChanged<bool> onDragActiveChanged;
  final ValueChanged<int> onToggleCheckbox;
  final VoidCallback? onRequestKeyboard;
  final Widget child;

  @override
  State<NoteTouchSelection> createState() => _NoteTouchSelectionState();
}

class _NoteTouchSelectionState extends State<NoteTouchSelection> {
  int? _tapOffset;
  double? _tableDragY;
  _LongPress _longPress = _LongPress.none;
  MdRange? _pressWord;
  Offset? _pressPoint;
  NoteSelection? _lastSent;

  RenderNoteView? get _view {
    final RenderObject? object = widget.renderKey.currentContext
        ?.findRenderObject();
    return object is RenderNoteView && object.attached ? object : null;
  }

  void _requestFocus() {
    if (!widget.focusNode.hasFocus) {
      widget.focusNode.requestFocus();
    }
  }

  void _afterFrame(VoidCallback action) {
    SchedulerBinding.instance
      ..addPostFrameCallback((Duration _) {
        if (!mounted) {
          return;
        }
        widget.overlay.update();
        action();
      })
      ..ensureVisualUpdate();
  }

  void _select(
    NoteSelection selection,
    SelectionChangedCause cause, [
    VoidCallback? then,
  ]) {
    _lastSent = selection;
    widget.onSelectionChanged(selection, cause);
    _afterFrame(then ?? () {});
  }

  void _handleTapDown(TapDragDownDetails details) {
    final RenderNoteView? view = _view;
    if (view == null || details.consecutiveTapCount != 2) {
      return;
    }
    final int? origin = _tapOffset;
    if (origin == null ||
        noteCheckboxAt(
              view,
              view.globalToContent(details.globalPosition),
              minTarget: _touchTarget,
            ) !=
            null) {
      return;
    }
    final MdRange word = view.noteLayout.wordBoundary(origin);
    _requestFocus();
    _select(
      NoteSelection(anchor: word.start, head: word.end),
      SelectionChangedCause.doubleTap,
      () {
        widget.overlay
          ..showHandles()
          ..showToolbar();
      },
    );
  }

  void _handleTapUp(TapDragUpDetails details) {
    final RenderNoteView? view = _view;
    if (view == null) {
      return;
    }
    final Offset point = view.globalToContent(details.globalPosition);
    final int? box = noteCheckboxAt(view, point, minTarget: _touchTarget);
    if (box != null) {
      _tapOffset = null;
      widget.onToggleCheckbox(box);
      return;
    }
    if (details.consecutiveTapCount > 1) {
      return;
    }
    _placeTap(view, point);
    widget.onRequestKeyboard?.call();
  }

  void _placeTap(RenderNoteView view, Offset point) {
    final TextRange? photo = view.photoLineAt(point);
    if (photo != null) {
      _tapOffset = null;
      _requestFocus();
      widget.overlay.hideToolbar();
      _select(
        NoteSelection(anchor: photo.start, head: photo.end),
        SelectionChangedCause.tap,
      );
      return;
    }
    final TextPosition hit = view.noteLayout.positionAt(point);
    _tapOffset = hit.offset;
    final NoteSelection? current = view.selection;
    final bool onSelection =
        current != null &&
        (current.isCollapsed
            ? hit.offset == current.head
            : current.start <= hit.offset && hit.offset <= current.end);
    if (widget.focusNode.hasFocus && onSelection) {
      widget.overlay.toggleToolbar();
      return;
    }
    widget.overlay.hideToolbar(false);
    _select(
      NoteSelection.collapsed(hit.offset, affinity: hit.affinity),
      SelectionChangedCause.tap,
      widget.overlay.showHandles,
    );
    _requestFocus();
  }

  void _handleDragStart(TapDragStartDetails details) {
    final RenderNoteView? view = _view;
    _tableDragY = view?.globalToContent(details.globalPosition).dy;
  }

  void _handleDragUpdate(TapDragUpdateDetails details) {
    final RenderNoteView? view = _view;
    final double? y = _tableDragY;
    if (view == null || y == null) {
      return;
    }
    view.scrollTableBy(y, -details.delta.dx);
  }

  void _handleDragEnd(TapDragEndDetails details) {
    _tableDragY = null;
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    final RenderNoteView? view = _view;
    if (view == null) {
      _longPress = _LongPress.none;
      return;
    }
    final Offset point = view.globalToContent(details.globalPosition);
    final TextRange? photo = view.photoLineAt(point);
    _requestFocus();
    if (photo != null) {
      _longPress = _LongPress.photo;
      _select(
        NoteSelection(anchor: photo.start, head: photo.end),
        SelectionChangedCause.longPress,
      );
      return;
    }
    _longPress = _LongPress.text;
    final MdRange word = view.noteLayout.wordBoundary(
      view.noteLayout.positionAt(point).offset,
    );
    _pressWord = word;
    _pressPoint = point;
    widget.onDragActiveChanged(true);
    _select(
      NoteSelection(anchor: word.start, head: word.end),
      SelectionChangedCause.longPress,
    );
    widget.overlay.showMagnifier(details.globalPosition);
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    final RenderNoteView? view = _view;
    final MdRange? first = _pressWord;
    final Offset? origin = _pressPoint;
    if (_longPress != _LongPress.text ||
        view == null ||
        first == null ||
        origin == null) {
      return;
    }
    final Offset point = origin + details.offsetFromOrigin;
    final MdRange under = view.noteLayout.wordBoundary(
      view.noteLayout.positionAt(point).offset,
    );
    final NoteSelection next = under.start >= first.start
        ? NoteSelection(anchor: first.start, head: under.end)
        : NoteSelection(anchor: first.end, head: under.start);
    if (next != _lastSent) {
      _select(next, SelectionChangedCause.longPress);
    }
    widget.overlay.updateMagnifier(details.globalPosition);
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    final _LongPress press = _longPress;
    _longPress = _LongPress.none;
    _pressWord = null;
    _pressPoint = null;
    if (press != _LongPress.text) {
      return;
    }
    widget.overlay.hideMagnifier();
    widget.onDragActiveChanged(false);
    _afterFrame(() {
      widget.overlay
        ..showHandles()
        ..showToolbar();
    });
  }

  void _handleLongPressCancel() {
    final _LongPress press = _longPress;
    _longPress = _LongPress.none;
    _pressWord = null;
    _pressPoint = null;
    if (press != _LongPress.text) {
      return;
    }
    widget.overlay.hideMagnifier();
    widget.onDragActiveChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        TapAndHorizontalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              TapAndHorizontalDragGestureRecognizer
            >(
              () => TapAndHorizontalDragGestureRecognizer(
                debugOwner: this,
                supportedDevices: _touchOnly,
              ),
              (TapAndHorizontalDragGestureRecognizer instance) {
                instance
                  ..dragStartBehavior = DragStartBehavior.down
                  ..onTapDown = _handleTapDown
                  ..onTapUp = _handleTapUp
                  ..onDragStart = _handleDragStart
                  ..onDragUpdate = _handleDragUpdate
                  ..onDragEnd = _handleDragEnd;
              },
            ),
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                debugOwner: this,
                supportedDevices: _touchOnly,
              ),
              (LongPressGestureRecognizer instance) {
                instance
                  ..onLongPressStart = _handleLongPressStart
                  ..onLongPressMoveUpdate = _handleLongPressMoveUpdate
                  ..onLongPressEnd = _handleLongPressEnd
                  ..onLongPressCancel = _handleLongPressCancel;
              },
            ),
      },
      child: widget.child,
    );
  }
}
