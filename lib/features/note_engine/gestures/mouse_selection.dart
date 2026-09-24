import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';

const double _mouseTarget = 24;
const Set<PointerDeviceKind> _mouseOnly = <PointerDeviceKind>{
  PointerDeviceKind.mouse,
};

int? noteCheckboxAt(
  RenderNoteView view,
  Offset contentPoint, {
  required double minTarget,
}) {
  int? best;
  double bestDistance = double.infinity;
  for (final AtomicObject atomic in view.visibleText.atomics) {
    if (atomic.kind != AtomicKind.checkbox) {
      continue;
    }
    final Rect glyph = view.noteLayout.rangeBounds(atomic.sourceRange);
    final Rect target = Rect.fromCenter(
      center: glyph.center,
      width: math.max(glyph.width, minTarget),
      height: math.max(glyph.height, minTarget),
    );
    if (!target.contains(contentPoint)) {
      continue;
    }
    final double distance = (glyph.center - contentPoint).distance;
    if (distance < bestDistance) {
      bestDistance = distance;
      best = atomic.sourceRange.start;
    }
  }
  return best;
}

MdRange _sourceLineAt(String source, int offset) {
  final int at = offset.clamp(0, source.length);
  final int start = at == 0 ? 0 : source.lastIndexOf('\n', at - 1) + 1;
  final int feed = source.indexOf('\n', at);
  final int breakAt = feed < 0 ? source.length : feed;
  final int end =
      feed >= 0 && breakAt > start && source.codeUnitAt(breakAt - 1) == 0x0D
      ? breakAt - 1
      : breakAt;
  return MdRange(start, math.max(start, end));
}

TextPosition _textPositionAt(RenderNoteView view, Offset contentPoint) {
  if (contentPoint.dy < 0) {
    return const TextPosition(offset: 0);
  }
  if (contentPoint.dy >= view.noteLayout.size.height) {
    return TextPosition(offset: view.source.length);
  }
  return view.noteLayout.positionAt(contentPoint);
}

enum _PressKind { none, checkbox, photo, text }

class NoteMouseSelection extends StatefulWidget {
  const NoteMouseSelection({
    super.key,
    required this.renderKey,
    required this.focusNode,
    required this.onSelectionChanged,
    required this.onDragActiveChanged,
    required this.onToggleCheckbox,
    this.onContextMenu,
    required this.child,
  });

  final GlobalKey renderKey;
  final FocusNode focusNode;
  final void Function(NoteSelection selection, SelectionChangedCause cause)
  onSelectionChanged;
  final ValueChanged<bool> onDragActiveChanged;
  final ValueChanged<int> onToggleCheckbox;
  final ValueChanged<Offset>? onContextMenu;
  final Widget child;

  @override
  State<NoteMouseSelection> createState() => _NoteMouseSelectionState();
}

class _NoteMouseSelectionState extends State<NoteMouseSelection> {
  _PressKind _press = _PressKind.none;
  int _count = 1;
  int? _boxStart;
  int? _pressOffset;
  int _anchor = 0;
  bool _dragSignalled = false;
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

  void _select(NoteSelection selection, SelectionChangedCause cause) {
    _lastSent = selection;
    widget.onSelectionChanged(selection, cause);
  }

  void _startDrag() {
    if (!_dragSignalled) {
      _dragSignalled = true;
      widget.onDragActiveChanged(true);
    }
  }

  void _endDrag() {
    if (_dragSignalled) {
      _dragSignalled = false;
      widget.onDragActiveChanged(false);
    }
  }

  void _reset() {
    _press = _PressKind.none;
    _boxStart = null;
    _lastSent = null;
  }

  void _handleTapDown(TapDragDownDetails details) {
    final RenderNoteView? view = _view;
    if (view == null) {
      _reset();
      return;
    }
    _endDrag();
    _lastSent = null;
    final Offset point = view.globalToContent(details.globalPosition);
    final int? box = noteCheckboxAt(view, point, minTarget: _mouseTarget);
    if (box != null) {
      _press = _PressKind.checkbox;
      _boxStart = box;
      return;
    }
    _boxStart = null;
    final TextRange? photo = view.photoLineAt(point);
    if (photo != null) {
      _press = _PressKind.photo;
      _requestFocus();
      _select(
        NoteSelection(anchor: photo.start, head: photo.end),
        SelectionChangedCause.tap,
      );
      return;
    }
    final int count = math.min(details.consecutiveTapCount, 3);
    final int? origin = _press == _PressKind.text ? _pressOffset : null;
    _press = _PressKind.text;
    if (count > 1 && origin != null) {
      _count = count;
      _startDrag();
      final MdRange unit = _unitAt(view, origin);
      _anchor = unit.start;
      _select(
        NoteSelection(anchor: unit.start, head: unit.end),
        count == 2
            ? SelectionChangedCause.doubleTap
            : SelectionChangedCause.tap,
      );
      _requestFocus();
      return;
    }
    _count = 1;
    final TextPosition hit = _textPositionAt(view, point);
    _pressOffset = hit.offset;
    final NoteSelection? current = view.selection;
    final bool extend =
        HardwareKeyboard.instance.isShiftPressed && current != null;
    _anchor = extend ? current.anchor : hit.offset;
    _startDrag();
    _select(
      NoteSelection(anchor: _anchor, head: hit.offset, affinity: hit.affinity),
      SelectionChangedCause.tap,
    );
    _requestFocus();
  }

  MdRange _unitAt(RenderNoteView view, int offset) => _count == 2
      ? view.noteLayout.wordBoundary(offset)
      : _sourceLineAt(view.source, offset);

  void _handleTapUp(TapDragUpDetails details) {
    final _PressKind press = _press;
    final int? box = _boxStart;
    _boxStart = null;
    if (press == _PressKind.checkbox && box != null) {
      widget.onToggleCheckbox(box);
      _press = _PressKind.none;
      return;
    }
    _endDrag();
  }

  void _handleDragStart(TapDragStartDetails details) {
    if (_press == _PressKind.checkbox) {
      _boxStart = null;
    }
  }

  void _handleDragUpdate(TapDragUpdateDetails details) {
    if (_press != _PressKind.text) {
      return;
    }
    final RenderNoteView? view = _view;
    final int? origin = _pressOffset;
    if (view == null || origin == null) {
      return;
    }
    final Offset point = view.globalToContent(details.globalPosition);
    final TextPosition hit = _textPositionAt(view, point);
    final NoteSelection next;
    if (_count == 1) {
      next = NoteSelection(
        anchor: _anchor,
        head: hit.offset,
        affinity: hit.affinity,
      );
    } else {
      final MdRange first = _unitAt(view, origin);
      final MdRange under = _unitAt(view, hit.offset);
      next = under.start >= first.start
          ? NoteSelection(anchor: first.start, head: under.end)
          : NoteSelection(anchor: first.end, head: under.start);
    }
    if (next == _lastSent) {
      return;
    }
    _select(next, SelectionChangedCause.drag);
  }

  void _handleDragEnd(TapDragEndDetails details) {
    _boxStart = null;
    _endDrag();
  }

  void _handleCancel() {
    _boxStart = null;
    _endDrag();
  }

  void _handleSecondaryTapDown(TapDownDetails details) {
    final RenderNoteView? view = _view;
    if (view == null) {
      return;
    }
    final Offset point = view.globalToContent(details.globalPosition);
    final TextRange? photo = view.photoLineAt(point);
    final NoteSelection? current = view.selection;
    final NoteSelection? next;
    if (photo != null) {
      next = NoteSelection(anchor: photo.start, head: photo.end);
    } else {
      final int offset = _textPositionAt(view, point).offset;
      if (current != null &&
          !current.isCollapsed &&
          current.start <= offset &&
          offset <= current.end) {
        next = null;
      } else {
        final MdRange word = view.noteLayout.wordBoundary(offset);
        next = NoteSelection(anchor: word.start, head: word.end);
      }
    }
    if (next != null && next != current) {
      _select(next, SelectionChangedCause.tap);
    }
    _requestFocus();
    widget.onContextMenu?.call(details.globalPosition);
  }

  void _handleTapOutside(PointerDownEvent event) {
    final FocusNode node = widget.focusNode;
    if (!node.hasFocus) {
      return;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        switch (event.kind) {
          case PointerDeviceKind.touch:
            if (kIsWeb) {
              node.unfocus();
            }
          case PointerDeviceKind.mouse:
          case PointerDeviceKind.stylus:
          case PointerDeviceKind.invertedStylus:
          case PointerDeviceKind.unknown:
            node.unfocus();
          case PointerDeviceKind.trackpad:
            break;
        }
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        node.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFieldTapRegion(
      onTapOutside: _handleTapOutside,
      child: MouseRegion(
        cursor: SystemMouseCursors.text,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            TapAndPanGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  TapAndPanGestureRecognizer
                >(
                  () => TapAndPanGestureRecognizer(
                    debugOwner: this,
                    supportedDevices: _mouseOnly,
                  ),
                  (TapAndPanGestureRecognizer instance) {
                    instance
                      ..dragStartBehavior = DragStartBehavior.down
                      ..onTapDown = _handleTapDown
                      ..onTapUp = _handleTapUp
                      ..onDragStart = _handleDragStart
                      ..onDragUpdate = _handleDragUpdate
                      ..onDragEnd = _handleDragEnd
                      ..onCancel = _handleCancel;
                  },
                ),
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(
                    debugOwner: this,
                    supportedDevices: _mouseOnly,
                  ),
                  (TapGestureRecognizer instance) {
                    instance.onSecondaryTapDown = _handleSecondaryTapDown;
                  },
                ),
          },
          child: widget.child,
        ),
      ),
    );
  }
}
