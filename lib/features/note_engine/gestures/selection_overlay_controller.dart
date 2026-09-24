import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';

final class _Geometry {
  const _Geometry({
    required this.startType,
    required this.endType,
    required this.startLineHeight,
    required this.endLineHeight,
    required this.endpoints,
  });

  final TextSelectionHandleType startType;
  final TextSelectionHandleType endType;
  final double startLineHeight;
  final double endLineHeight;
  final List<TextSelectionPoint> endpoints;
}

TextSelectionControls _platformHandleControls() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
      return materialTextSelectionHandleControls;
    case TargetPlatform.iOS:
      return cupertinoTextSelectionHandleControls;
    case TargetPlatform.macOS:
      return cupertinoDesktopTextSelectionHandleControls;
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return desktopTextSelectionHandleControls;
  }
}

class NoteSelectionOverlayController with TextSelectionDelegate {
  NoteSelectionOverlayController({
    required this._context,
    required this._renderKey,
    required this._onSelectionChanged,
    required this._onDragActiveChanged,
    required this._onCut,
    required this._onCopy,
    required this._onPaste,
    required this._onSelectAll,
    required this._onBringIntoView,
  });

  final BuildContext _context;
  final GlobalKey _renderKey;
  final void Function(NoteSelection selection, SelectionChangedCause cause)
  _onSelectionChanged;
  final ValueChanged<bool> _onDragActiveChanged;
  final void Function(SelectionChangedCause cause) _onCut;
  final void Function(SelectionChangedCause cause) _onCopy;
  final Future<void> Function(SelectionChangedCause cause) _onPaste;
  final void Function(SelectionChangedCause cause) _onSelectAll;
  final void Function(int sourceOffset) _onBringIntoView;

  final LayerLink startHandleLayerLink = LayerLink();
  final LayerLink endHandleLayerLink = LayerLink();
  final LayerLink toolbarLayerLink = LayerLink();

  final ValueNotifier<bool> _hidden = ValueNotifier<bool>(false);
  SelectionOverlay? _overlay;
  bool _handlesShown = false;
  bool _disposed = false;
  int? _dragFixed;
  double _dragTarget = 0;

  RenderNoteView? get _view {
    final RenderObject? object = _renderKey.currentContext?.findRenderObject();
    return object is RenderNoteView && object.attached ? object : null;
  }

  bool get handlesShown => _handlesShown;

  bool get toolbarShown => _overlay?.toolbarIsVisible ?? false;

  ValueListenable<bool> get startHandleVisible =>
      _view?.selectionStartInViewport ?? _hidden;

  ValueListenable<bool> get endHandleVisible =>
      _view?.selectionEndInViewport ?? _hidden;

  _Geometry? _geometryOf(RenderNoteView view) {
    final NoteSelection? selection = view.selection;
    if (selection == null) {
      return null;
    }
    final SelectionEndpoints endpoints = view.noteLayout.selectionEndpoints(
      selection,
    );
    final TextSelectionPoint start = _localPoint(view, endpoints.start);
    final TextSelectionPoint end = _localPoint(view, endpoints.end);
    final bool collapsed = selection.isCollapsed;
    final TextDirection startDirection = start.direction ?? view.textDirection;
    final TextDirection endDirection = end.direction ?? view.textDirection;
    return _Geometry(
      startType: collapsed
          ? TextSelectionHandleType.collapsed
          : startDirection == TextDirection.rtl
          ? TextSelectionHandleType.right
          : TextSelectionHandleType.left,
      endType: collapsed
          ? TextSelectionHandleType.collapsed
          : endDirection == TextDirection.rtl
          ? TextSelectionHandleType.left
          : TextSelectionHandleType.right,
      startLineHeight: endpoints.startLineHeight,
      endLineHeight: endpoints.endLineHeight,
      endpoints: List<TextSelectionPoint>.unmodifiable(
        collapsed
            ? <TextSelectionPoint>[start]
            : <TextSelectionPoint>[start, end],
      ),
    );
  }

  TextSelectionPoint _localPoint(
    RenderNoteView view,
    TextSelectionPoint point,
  ) => TextSelectionPoint(view.contentToLocal(point.point), point.direction);

  SelectionOverlay? _ensureOverlay() {
    final SelectionOverlay? existing = _overlay;
    if (existing != null || _disposed) {
      return existing;
    }
    final RenderNoteView? view = _view;
    if (view == null) {
      return null;
    }
    final _Geometry? geometry = _geometryOf(view);
    if (geometry == null) {
      return null;
    }
    final SelectionOverlay created = SelectionOverlay(
      context: _context,
      startHandleType: geometry.startType,
      endHandleType: geometry.endType,
      lineHeightAtStart: geometry.startLineHeight,
      lineHeightAtEnd: geometry.endLineHeight,
      selectionEndpoints: geometry.endpoints,
      startHandlesVisible: view.selectionStartInViewport,
      endHandlesVisible: view.selectionEndInViewport,
      selectionControls: _platformHandleControls(),
      // ignore: deprecated_member_use
      selectionDelegate: this,
      clipboardStatus: null,
      startHandleLayerLink: startHandleLayerLink,
      endHandleLayerLink: endHandleLayerLink,
      toolbarLayerLink: toolbarLayerLink,
      magnifierConfiguration: TextMagnifier.adaptiveMagnifierConfiguration,
      onSelectionHandleTapped: toggleToolbar,
      onStartHandleDragStart: (DragStartDetails details) =>
          _handleDragStart(details, start: true),
      onStartHandleDragUpdate: _handleDragUpdate,
      onStartHandleDragEnd: _handleDragEnd,
      onEndHandleDragStart: (DragStartDetails details) =>
          _handleDragStart(details, start: false),
      onEndHandleDragUpdate: _handleDragUpdate,
      onEndHandleDragEnd: _handleDragEnd,
    );
    _overlay = created;
    return created;
  }

  void showHandles() {
    final SelectionOverlay? overlay = _ensureOverlay();
    if (overlay == null) {
      return;
    }
    overlay.showHandles();
    _handlesShown = true;
  }

  void hideHandles() {
    _overlay?.hideHandles();
    _handlesShown = false;
  }

  List<ContextMenuButtonItem> _buttonItems(
    NoteSelection? selection,
    List<ContextMenuButtonItem> leadingItems,
  ) => <ContextMenuButtonItem>[
    ...leadingItems,
    if (selection != null && !selection.isCollapsed) ...<ContextMenuButtonItem>[
      ContextMenuButtonItem(
        type: ContextMenuButtonType.cut,
        onPressed: () => cutSelection(SelectionChangedCause.toolbar),
      ),
      ContextMenuButtonItem(
        type: ContextMenuButtonType.copy,
        onPressed: () => copySelection(SelectionChangedCause.toolbar),
      ),
    ],
    ContextMenuButtonItem(
      type: ContextMenuButtonType.paste,
      onPressed: () => pasteText(SelectionChangedCause.toolbar),
    ),
    ContextMenuButtonItem(
      type: ContextMenuButtonType.selectAll,
      onPressed: () => selectAll(SelectionChangedCause.toolbar),
    ),
  ];

  void showToolbar({
    Offset? anchor,
    List<ContextMenuButtonItem> leadingItems = const <ContextMenuButtonItem>[],
  }) {
    final SelectionOverlay? overlay = _ensureOverlay();
    final RenderNoteView? view = _view;
    final BuildContext? renderContext = _renderKey.currentContext;
    if (overlay == null || view == null || renderContext == null) {
      return;
    }
    final _Geometry? geometry = _geometryOf(view);
    if (geometry == null) {
      return;
    }
    final TextSelectionToolbarAnchors anchors = anchor != null
        ? TextSelectionToolbarAnchors(primaryAnchor: anchor)
        : TextSelectionToolbarAnchors.fromSelection(
            renderBox: view,
            startGlyphHeight: geometry.startLineHeight,
            endGlyphHeight: geometry.endLineHeight,
            selectionEndpoints: geometry.endpoints,
          );
    final List<ContextMenuButtonItem> items =
        List<ContextMenuButtonItem>.unmodifiable(
          _buttonItems(view.selection, leadingItems),
        );
    overlay.showToolbar(
      context: renderContext,
      contextMenuBuilder: (BuildContext context) =>
          AdaptiveTextSelectionToolbar.buttonItems(
            anchors: anchors,
            buttonItems: items,
          ),
    );
  }

  void toggleToolbar({Offset? anchor}) {
    if (toolbarShown) {
      _overlay?.hideToolbar();
      return;
    }
    showToolbar(anchor: anchor);
  }

  Rect _globalRect(RenderNoteView view, Rect contentRect) {
    final Rect? placed = view.contentRectToLocal(contentRect);
    if (placed != null) {
      return MatrixUtils.transformRect(view.getTransformTo(null), placed);
    }
    final Rect shifted = contentRect.shift(
      Offset(
        -view.tableScrollOffsetAt(contentRect.center.dy),
        -view.scrollOffset,
      ),
    );
    final double edge = shifted.center.dx < view.size.width / 2
        ? 0
        : view.size.width;
    return MatrixUtils.transformRect(
      view.getTransformTo(null),
      Rect.fromLTRB(edge, shifted.top, edge, shifted.bottom),
    );
  }

  MagnifierInfo _magnifierInfo(
    RenderNoteView view,
    Offset pointer,
    Offset target,
  ) {
    final TextPosition head = view.noteLayout.positionAt(
      view.globalToContent(target),
    );
    return MagnifierInfo(
      globalGesturePosition: pointer,
      caretRect: _globalRect(
        view,
        view.noteLayout.caretRect(head.offset, head.affinity),
      ),
      fieldBounds: view.localToGlobal(Offset.zero) & view.size,
      currentLineBoundaries: _globalRect(
        view,
        view.noteLayout.lineBoxAt(head.offset, head.affinity).rect,
      ),
    );
  }

  void _showMagnifierAt(Offset pointer, Offset target) {
    final SelectionOverlay? overlay = _ensureOverlay();
    final RenderNoteView? view = _view;
    if (overlay == null || view == null) {
      return;
    }
    overlay.showMagnifier(_magnifierInfo(view, pointer, target));
  }

  void _updateMagnifierAt(Offset pointer, Offset target) {
    final SelectionOverlay? overlay = _overlay;
    final RenderNoteView? view = _view;
    if (overlay == null || view == null) {
      return;
    }
    overlay.updateMagnifier(_magnifierInfo(view, pointer, target));
  }

  void showMagnifier(Offset globalPosition) =>
      _showMagnifierAt(globalPosition, globalPosition);

  void updateMagnifier(Offset globalPosition) =>
      _updateMagnifierAt(globalPosition, globalPosition);

  void hideMagnifier() => _overlay?.hideMagnifier();

  void update() {
    final SelectionOverlay? overlay = _overlay;
    final RenderNoteView? view = _view;
    if (overlay == null || view == null) {
      return;
    }
    final _Geometry? geometry = _geometryOf(view);
    if (geometry == null) {
      return;
    }
    overlay
      ..startHandleType = geometry.startType
      ..endHandleType = geometry.endType
      ..lineHeightAtStart = geometry.startLineHeight
      ..lineHeightAtEnd = geometry.endLineHeight
      ..selectionEndpoints = geometry.endpoints;
  }

  void _handleDragStart(DragStartDetails details, {required bool start}) {
    final RenderNoteView? view = _view;
    final NoteSelection? selection = view?.selection;
    if (view == null || selection == null) {
      return;
    }
    final SelectionEndpoints endpoints = view.noteLayout.selectionEndpoints(
      selection,
    );
    final TextSelectionPoint point = start ? endpoints.start : endpoints.end;
    final double lineHeight = start
        ? endpoints.startLineHeight
        : endpoints.endLineHeight;
    final Offset local = view.contentToLocal(point.point);
    final double centre = view
        .localToGlobal(Offset(local.dx, local.dy - lineHeight / 2))
        .dy;
    _dragFixed = start ? selection.end : selection.start;
    _dragTarget = centre - details.globalPosition.dy;
    _onDragActiveChanged(true);
    _showMagnifierAt(
      details.globalPosition,
      Offset(details.globalPosition.dx, centre),
    );
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final RenderNoteView? view = _view;
    final int? fixed = _dragFixed;
    if (view == null || fixed == null) {
      return;
    }
    final Offset target = Offset(
      details.globalPosition.dx,
      details.globalPosition.dy + _dragTarget,
    );
    final TextPosition hit = view.noteLayout.positionAt(
      view.globalToContent(target),
    );
    final NoteSelection next = NoteSelection(
      anchor: fixed,
      head: hit.offset,
      affinity: hit.affinity,
    );
    if (next.isCollapsed || next == view.selection) {
      _updateMagnifierAt(details.globalPosition, target);
      return;
    }
    _onSelectionChanged(next, SelectionChangedCause.drag);
    _updateMagnifierAt(details.globalPosition, target);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragFixed == null) {
      return;
    }
    _dragFixed = null;
    hideMagnifier();
    _onDragActiveChanged(false);
  }

  @override
  TextEditingValue get textEditingValue {
    final RenderNoteView? view = _view;
    if (view == null) {
      return TextEditingValue.empty;
    }
    final NoteSelection? selection = view.selection;
    final OffsetMap map = view.visibleText.map;
    int visible(int offset) =>
        map.sourceToVisible(offset.clamp(0, map.sourceLength));
    return TextEditingValue(
      text: view.visibleText.text,
      selection: selection == null
          ? const TextSelection.collapsed(offset: -1)
          : TextSelection(
              baseOffset: visible(selection.anchor),
              extentOffset: visible(selection.head),
              affinity: selection.affinity,
            ),
    );
  }

  @override
  void userUpdateTextEditingValue(
    TextEditingValue value,
    SelectionChangedCause cause,
  ) {
    final RenderNoteView? view = _view;
    final TextSelection selection = value.selection;
    if (view == null || !selection.isValid) {
      return;
    }
    final OffsetMap map = view.visibleText.map;
    SourceOffsets source(int offset) =>
        map.visibleToSource(offset.clamp(0, map.visibleLength));
    final NoteSelection next;
    if (selection.isCollapsed) {
      final int at = source(selection.baseOffset).downstream;
      next = NoteSelection.collapsed(at, affinity: selection.affinity);
    } else if (selection.baseOffset < selection.extentOffset) {
      next = NoteSelection(
        anchor: source(selection.baseOffset).downstream,
        head: source(selection.extentOffset).upstream,
        affinity: selection.affinity,
      );
    } else {
      next = NoteSelection(
        anchor: source(selection.baseOffset).upstream,
        head: source(selection.extentOffset).downstream,
        affinity: selection.affinity,
      );
    }
    _onSelectionChanged(next, cause);
  }

  @override
  void hideToolbar([bool hideHandles = true]) {
    _overlay?.hideToolbar();
    if (hideHandles) {
      this.hideHandles();
    }
  }

  @override
  void bringIntoView(TextPosition position) {
    final RenderNoteView? view = _view;
    if (view == null) {
      return;
    }
    final OffsetMap map = view.visibleText.map;
    _onBringIntoView(
      map
          .visibleToSource(position.offset.clamp(0, map.visibleLength))
          .downstream,
    );
  }

  @override
  void cutSelection(SelectionChangedCause cause) => _onCut(cause);

  @override
  void copySelection(SelectionChangedCause cause) => _onCopy(cause);

  @override
  Future<void> pasteText(SelectionChangedCause cause) => _onPaste(cause);

  @override
  void selectAll(SelectionChangedCause cause) => _onSelectAll(cause);

  @override
  bool get cutEnabled => !(_view?.readOnly ?? true);

  @override
  bool get pasteEnabled => !(_view?.readOnly ?? true);

  @override
  bool get liveTextInputEnabled => false;

  @override
  bool get lookUpEnabled => false;

  @override
  bool get searchWebEnabled => false;

  @override
  bool get shareEnabled => false;

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _overlay?.dispose();
    _overlay = null;
    _handlesShown = false;
    _dragFixed = null;
    _hidden.dispose();
  }
}
