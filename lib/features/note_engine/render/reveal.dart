import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show kMinInteractiveDimension;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';

const Duration noteRevealDuration = Duration(milliseconds: 100);

const Curve noteRevealCurve = Curves.fastOutSlowIn;

const EdgeInsets noteRevealPadding = EdgeInsets.all(20);

double noteRevealHandleSpacing(
  TextSelectionControls controls,
  double lineHeight,
) {
  final double handleHeight = controls.getHandleSize(lineHeight).height;
  final Offset anchor = controls.getHandleAnchor(
    TextSelectionHandleType.collapsed,
    lineHeight,
  );
  return math.max(
    handleHeight / 2 -
        anchor.dy +
        math.max(handleHeight, kMinInteractiveDimension) / 2,
    noteRevealPadding.bottom,
  );
}

int? _lineAfter(String source, int lineEnd) {
  if (source.startsWith('\r\n', lineEnd)) {
    return lineEnd + 2;
  }
  if (source.startsWith('\n', lineEnd)) {
    return lineEnd + 1;
  }
  return null;
}

Rect? _selectedPhotoTarget(RenderNoteView view, TextRange photoRange) {
  RenderBox? child = view.firstChild;
  while (child != null) {
    final NotePhotoParentData data = child.parentData! as NotePhotoParentData;
    if (data.lineRange == photoRange) {
      final int? next = _lineAfter(view.source, photoRange.end);
      return next == null
          ? data.figureRect
          : data.figureRect.expandToInclude(
              view.noteLayout.lineBoxAt(next, TextAffinity.downstream).rect,
            );
    }
    child = view.childAfter(child);
  }
  return null;
}

Rect? noteRevealTarget(RenderNoteView view) {
  final NoteSelection? selection = view.selection;
  if (selection == null) {
    return null;
  }
  final TextRange? photoRange = view.selectedPhotoRange;
  if (photoRange != null) {
    return _selectedPhotoTarget(view, photoRange);
  }
  final NoteLayout layout = view.noteLayout;
  return layout
      .caretRect(selection.head, selection.affinity)
      .expandToInclude(
        layout.lineBoxAt(selection.head, selection.affinity).rect,
      );
}

double? noteRevealOffset({
  required Rect target,
  required double pixels,
  required double viewportExtent,
  required double minScrollExtent,
  required double maxScrollExtent,
  EdgeInsets padding = noteRevealPadding,
  double obscuredBottom = 0,
}) {
  final double bandTop = pixels + padding.top;
  final double bandBottom =
      pixels + viewportExtent - obscuredBottom - padding.bottom;
  final double wanted;
  if (target.height > bandBottom - bandTop || target.top < bandTop) {
    wanted = target.top - padding.top;
  } else if (target.bottom > bandBottom) {
    wanted = target.bottom + padding.bottom + obscuredBottom - viewportExtent;
  } else {
    return null;
  }
  final double clamped = wanted.clamp(minScrollExtent, maxScrollExtent);
  return clamped == pixels ? null : clamped;
}

class NoteCaretReveal with WidgetsBindingObserver {
  NoteCaretReveal({
    required this._scrollController,
    required this._renderView,
    required this._isFocused,
    required this._flutterView,
    this._handlesShown,
    this._handleControls,
  });

  final ScrollController _scrollController;
  final RenderNoteView? Function() _renderView;
  final bool Function() _isFocused;
  final ui.FlutterView _flutterView;
  final bool Function()? _handlesShown;
  final TextSelectionControls? _handleControls;

  bool _disposed = false;
  bool? _pendingAnimate;
  double _lastBottomInset = 0;

  void attach() {
    WidgetsBinding.instance.addObserver(this);
    _lastBottomInset = _flutterView.viewInsets.bottom;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    _pendingAnimate = null;
  }

  void scheduleReveal({required bool animate}) {
    if (_disposed) {
      return;
    }
    final bool? pending = _pendingAnimate;
    if (pending != null) {
      _pendingAnimate = pending && animate;
      return;
    }
    _pendingAnimate = animate;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      final bool? requested = _pendingAnimate;
      _pendingAnimate = null;
      if (requested != null) {
        _reveal(animate: requested);
      }
    }, debugLabel: 'NoteCaretReveal.reveal');
  }

  void _reveal({required bool animate}) {
    if (_disposed || !_scrollController.hasClients) {
      return;
    }
    final RenderNoteView? view = _renderView();
    if (view == null) {
      return;
    }
    final Rect? target = noteRevealTarget(view);
    final NoteSelection? selection = view.selection;
    if (target == null || selection == null) {
      return;
    }
    view.revealTableRect(target);
    final TextSelectionControls? controls = _handleControls;
    final EdgeInsets padding =
        controls != null && (_handlesShown?.call() ?? false)
        ? noteRevealPadding.copyWith(
            bottom: noteRevealHandleSpacing(
              controls,
              view.noteLayout
                  .lineBoxAt(selection.head, selection.affinity)
                  .rect
                  .height,
            ),
          )
        : noteRevealPadding;
    final ScrollPosition position = _scrollController.position;
    final double? offset = noteRevealOffset(
      target: target,
      pixels: position.pixels,
      viewportExtent: position.viewportDimension,
      minScrollExtent: position.minScrollExtent,
      maxScrollExtent: position.maxScrollExtent,
      padding: padding,
      obscuredBottom: view.bottomInset,
    );
    if (offset == null) {
      return;
    }
    if (animate) {
      position.animateTo(
        offset,
        duration: noteRevealDuration,
        curve: noteRevealCurve,
      );
    } else {
      position.jumpTo(offset);
    }
  }

  @override
  void didChangeMetrics() {
    final double bottom = _flutterView.viewInsets.bottom;
    final bool grew = bottom > _lastBottomInset;
    _lastBottomInset = bottom;
    if (grew && _isFocused()) {
      scheduleReveal(animate: false);
    }
  }
}
