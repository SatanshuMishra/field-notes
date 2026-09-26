import 'dart:math' as math;
import 'dart:ui' show SemanticsInputType;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_layout_engine.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:field_notes/features/note_engine/render/caret_painter.dart';
import 'package:field_notes/features/note_engine/render/note_semantics.dart';
import 'package:field_notes/features/note_engine/render/selection_painter.dart';

typedef NoteLayoutRunner = LaidOutNote Function(LayoutInputs inputs);

abstract interface class NoteViewDelegate {
  void selectVisible(TextSelection selection);

  void replaceVisibleText(String text);

  void copySelection();

  void cutSelection();

  void pasteClipboard();

  void selectPhoto(int lineStart);

  void toggleCheckbox(int boxStart);
}

abstract class NoteViewDecoration {
  const NoteViewDecoration();

  void paint(
    Canvas canvas,
    NoteLayout layout,
    Rect? Function(Rect contentRect) place,
  );

  bool shouldRepaint(covariant NoteViewDecoration oldDecoration);
}

const double _tableOverflowSlack = 0.01;
const double _viewportSlack = 0.5;
const double _androidTarget = 48;
const double _desktopTarget = 24;
const int _lineFeed = 0x0A;
final RegExp _wordGap = RegExp(r'[\s\p{P}\p{S}]', unicode: true);

bool _spansBand(double top, double bottom, Rect window) =>
    top < window.bottom && bottom > window.top;

TextRange? _sourceSpanWithin(
  LaidOutNote layout,
  List<LaidOutRow> rows,
  Rect window,
) {
  final List<TextRange> lines = <TextRange>[
    for (final LaidOutRow row in rows)
      for (final LineFragment fragment in row.fragments)
        if (_spansBand(fragment.rect.top, fragment.rect.bottom, window))
          for (final VisualLine line in fragment.lines)
            if (_spansBand(line.top, line.top + line.height, window))
              line.visibleRange,
  ];
  if (lines.isEmpty) {
    return null;
  }
  final VisibleText visible = layout.inputs.visibleText;
  final OffsetMap map = visible.map;
  final String text = visible.text;
  final int low = math.min(
    lines.map((TextRange line) => line.start).reduce(math.min),
    map.visibleLength,
  );
  final int high = math.min(
    lines.map((TextRange line) => line.end).reduce(math.max),
    map.visibleLength,
  );
  final int end = high < text.length && text.codeUnitAt(high) == _lineFeed
      ? high + 1
      : high;
  return TextRange(
    start: map.visibleToSource(low).upstream,
    end: map.visibleToSource(end).downstream,
  );
}

NoteSelection? _selectionWithin(NoteSelection selection, TextRange? span) {
  if (span == null) {
    return null;
  }
  final int start = math.max(selection.start, span.start);
  final int end = math.min(selection.end, span.end);
  return end > start
      ? NoteSelection(anchor: start, head: end, affinity: selection.affinity)
      : null;
}

TextRange? noteSelectedPhotoRange(
  MdTree tree,
  String source,
  NoteSelection? selection,
) {
  if (selection == null ||
      tree.sourceLength != source.length ||
      selection.start > tree.sourceLength) {
    return null;
  }
  final MdBlock? block = tree.blockAt(selection.start);
  if (block == null || block.kind != MdBlockKind.photoLine) {
    return null;
  }
  final int a = block.sourceRange.start;
  final int b = block.sourceRange.end;
  final TextRange line = TextRange(start: a, end: b);
  if (selection.isCollapsed) {
    return selection.start >= a && selection.start <= b ? line : null;
  }
  if (selection.start != a) {
    return null;
  }
  final int end = selection.end;
  if (end == b) {
    return line;
  }
  final int breakLength = source.startsWith('\r\n', b)
      ? 2
      : source.startsWith('\n', b)
      ? 1
      : 0;
  return breakLength > 0 && end == b + breakLength ? line : null;
}

class NotePhotoParentData extends ContainerBoxParentData<RenderBox> {
  Rect figureRect = Rect.zero;
  TextRange lineRange = TextRange.empty;
  bool selected = false;
}

class NotePhotoSlot extends ParentDataWidget<NotePhotoParentData> {
  const NotePhotoSlot({
    super.key,
    required this.figureRect,
    required this.lineRange,
    required this.selected,
    required super.child,
  });

  final Rect figureRect;
  final TextRange lineRange;
  final bool selected;

  @override
  void applyParentData(RenderObject renderObject) {
    final NotePhotoParentData data =
        renderObject.parentData! as NotePhotoParentData;
    final bool moved = data.figureRect != figureRect;
    data
      ..figureRect = figureRect
      ..lineRange = lineRange
      ..selected = selected;
    if (moved) {
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => NoteViewBody;
}

class NoteViewBody extends MultiChildRenderObjectWidget {
  const NoteViewBody({
    super.key,
    required this.source,
    required this.tree,
    required this.visibleText,
    required this.layout,
    required this.activeLine,
    required this.selection,
    required this.composing,
    required this.focused,
    required this.readOnly,
    required this.offset,
    required this.bottomInset,
    required this.hintText,
    required this.hintStyle,
    required this.semanticsLabel,
    required this.textScaler,
    required this.textDirection,
    required this.devicePixelRatio,
    required this.cursorColor,
    required this.selectionColor,
    required this.platformValue,
    required this.platformValueStart,
    required this.delegate,
    required this.onToggleTask,
    required this.startHandleLayerLink,
    required this.endHandleLayerLink,
    required this.decorations,
    super.children,
  });

  final String source;
  final MdTree tree;
  final VisibleText visibleText;
  final LaidOutNote layout;
  final int? activeLine;
  final NoteSelection? selection;
  final TextRange composing;
  final bool focused;
  final bool readOnly;
  final ViewportOffset? offset;
  final double bottomInset;
  final String hintText;
  final TextStyle hintStyle;
  final String semanticsLabel;
  final TextScaler textScaler;
  final TextDirection textDirection;
  final double devicePixelRatio;
  final Color cursorColor;
  final Color selectionColor;
  final TextEditingValue? platformValue;
  final int platformValueStart;
  final NoteViewDelegate? delegate;
  final ValueChanged<int>? onToggleTask;
  final LayerLink? startHandleLayerLink;
  final LayerLink? endHandleLayerLink;
  final List<NoteViewDecoration> decorations;

  @override
  RenderNoteView createRenderObject(BuildContext context) => RenderNoteView(
    source: source,
    tree: tree,
    visibleText: visibleText,
    layout: layout,
    activeLine: activeLine,
    selection: selection,
    composing: composing,
    focused: focused,
    readOnly: readOnly,
    offset: offset,
    bottomInset: bottomInset,
    hintText: hintText,
    hintStyle: hintStyle,
    semanticsLabel: semanticsLabel,
    textScaler: textScaler,
    textDirection: textDirection,
    devicePixelRatio: devicePixelRatio,
    cursorColor: cursorColor,
    selectionColor: selectionColor,
    platformValue: platformValue,
    platformValueStart: platformValueStart,
    delegate: delegate,
    onToggleTask: onToggleTask,
    startHandleLayerLink: startHandleLayerLink,
    endHandleLayerLink: endHandleLayerLink,
    decorations: decorations,
  );

  @override
  void updateRenderObject(BuildContext context, RenderNoteView renderObject) {
    renderObject
      ..source = source
      ..tree = tree
      ..visibleText = visibleText
      ..noteLayout = layout
      ..activeLine = activeLine
      ..selection = selection
      ..composing = composing
      ..focused = focused
      ..readOnly = readOnly
      ..offset = offset
      ..bottomInset = bottomInset
      ..hintText = hintText
      ..hintStyle = hintStyle
      ..semanticsLabel = semanticsLabel
      ..textScaler = textScaler
      ..textDirection = textDirection
      ..devicePixelRatio = devicePixelRatio
      ..cursorColor = cursorColor
      ..selectionColor = selectionColor
      ..platformValue = platformValue
      ..platformValueStart = platformValueStart
      ..delegate = delegate
      ..onToggleTask = onToggleTask
      ..startHandleLayerLink = startHandleLayerLink
      ..endHandleLayerLink = endHandleLayerLink
      ..decorations = decorations;
  }
}

final class _TableBand {
  const _TableBand({
    required this.key,
    required this.top,
    required this.bottom,
    required this.maxOffset,
  });

  final int key;
  final double top;
  final double bottom;
  final double maxOffset;

  bool holds(double contentY) => contentY >= top && contentY < bottom;
}

List<_TableBand> _tableBandsOf(LaidOutNote layout) {
  final double column = layout.inputs.columnWidth;
  final List<_TableBand> bands = <_TableBand>[];
  int ordinal = 0;
  for (final LaidOutRow row in layout.flow.rows) {
    if (row.row.kind != LayoutRowKind.table) {
      continue;
    }
    final int key = ordinal++;
    if (row.contentWidth - column > _tableOverflowSlack) {
      bands.add(
        _TableBand(
          key: key,
          top: row.top,
          bottom: row.bottom,
          maxOffset: row.contentWidth - column,
        ),
      );
    }
  }
  return List<_TableBand>.unmodifiable(bands);
}

class RenderNoteView extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, NotePhotoParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, NotePhotoParentData> {
  RenderNoteView({
    required this._source,
    required this._tree,
    required this._visibleText,
    required LaidOutNote layout,
    this._activeLine,
    this._selection,
    this._composing = TextRange.empty,
    this._focused = false,
    this._readOnly = false,
    this._offset,
    this._bottomInset = 0,
    this._hintText = '',
    this._hintStyle = const TextStyle(),
    this._semanticsLabel = '',
    this._textScaler = TextScaler.noScaling,
    this._textDirection = TextDirection.ltr,
    this._devicePixelRatio = 1,
    this._cursorColor = const Color(0xFF000000),
    this._selectionColor = const Color(0x66000000),
    this._platformValue,
    this._platformValueStart = 0,
    this._delegate,
    this._onToggleTask,
    this._startHandleLayerLink,
    this._endHandleLayerLink,
    this._decorations = const <NoteViewDecoration>[],
  }) : _noteLayout = layout,
       _tableBands = _tableBandsOf(layout);

  String _source;
  MdTree _tree;
  VisibleText _visibleText;
  LaidOutNote _noteLayout;
  List<_TableBand> _tableBands;
  Map<int, double> _tableOffsets = const <int, double>{};
  int? _activeLine;
  NoteSelection? _selection;
  TextRange _composing;
  bool _focused;
  bool _readOnly;
  ViewportOffset? _offset;
  double _bottomInset;
  String _hintText;
  TextStyle _hintStyle;
  String _semanticsLabel;
  TextScaler _textScaler;
  TextDirection _textDirection;
  double _devicePixelRatio;
  Color _cursorColor;
  Color _selectionColor;
  TextEditingValue? _platformValue;
  int _platformValueStart;
  NoteViewDelegate? _delegate;
  ValueChanged<int>? _onToggleTask;
  LayerLink? _startHandleLayerLink;
  LayerLink? _endHandleLayerLink;
  List<NoteViewDecoration> _decorations;

  NoteSemanticsNodes _semanticsNodes = NoteSemanticsNodes();
  late final NoteCaretBlink _blink = NoteCaretBlink(onChanged: markNeedsPaint);
  TextPainter? _hintPainter;
  List<Rect> _paintedFragmentRects = const <Rect>[];
  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();
  final ValueNotifier<bool> _selectionStartInViewport = ValueNotifier<bool>(
    true,
  );
  final ValueNotifier<bool> _selectionEndInViewport = ValueNotifier<bool>(true);

  String get source => _source;
  set source(String value) {
    if (value == _source) {
      return;
    }
    _source = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
    _updateBlink(restart: true);
  }

  MdTree get tree => _tree;
  set tree(MdTree value) {
    if (identical(value, _tree)) {
      return;
    }
    _tree = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
    _updateBlink();
  }

  VisibleText get visibleText => _visibleText;
  set visibleText(VisibleText value) {
    if (identical(value, _visibleText)) {
      return;
    }
    _visibleText = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  LaidOutNote get noteLayout => _noteLayout;
  set noteLayout(LaidOutNote value) {
    if (identical(value, _noteLayout)) {
      return;
    }
    _noteLayout = value;
    markNeedsSemanticsUpdate();
    final List<_TableBand> bands = _tableBandsOf(value);
    _tableBands = bands;
    _tableOffsets = Map<int, double>.unmodifiable(<int, double>{
      for (final _TableBand band in bands)
        if (_tableOffsets[band.key] case final double kept)
          band.key: kept.clamp(0.0, band.maxOffset),
    });
    markNeedsLayout();
  }

  int? get activeLine => _activeLine;
  set activeLine(int? value) {
    if (value == _activeLine) {
      return;
    }
    _activeLine = value;
    markNeedsPaint();
  }

  NoteSelection? get selection => _selection;
  set selection(NoteSelection? value) {
    if (value == _selection) {
      return;
    }
    _selection = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
    _updateBlink(restart: true);
  }

  TextRange get composing => _composing;
  set composing(TextRange value) {
    if (value == _composing) {
      return;
    }
    _composing = value;
    markNeedsPaint();
  }

  bool get focused => _focused;
  set focused(bool value) {
    if (value == _focused) {
      return;
    }
    _focused = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
    _updateBlink(restart: true);
  }

  bool get readOnly => _readOnly;
  set readOnly(bool value) {
    if (value == _readOnly) {
      return;
    }
    _readOnly = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
    _updateBlink();
  }

  ViewportOffset? get offset => _offset;
  set offset(ViewportOffset? value) {
    if (identical(value, _offset)) {
      return;
    }
    if (attached) {
      _offset?.removeListener(_handleScroll);
    }
    _offset = value;
    if (attached) {
      value?.addListener(_handleScroll);
    }
    markNeedsLayout();
  }

  double get bottomInset => _bottomInset;
  set bottomInset(double value) {
    if (value == _bottomInset) {
      return;
    }
    _bottomInset = value;
    markNeedsLayout();
  }

  String get hintText => _hintText;
  set hintText(String value) {
    if (value == _hintText) {
      return;
    }
    _hintText = value;
    _disposeHint();
    markNeedsPaint();
  }

  String get semanticsLabel => _semanticsLabel;
  set semanticsLabel(String value) {
    if (value == _semanticsLabel) {
      return;
    }
    _semanticsLabel = value;
    markNeedsSemanticsUpdate();
  }

  TextStyle get hintStyle => _hintStyle;
  set hintStyle(TextStyle value) {
    if (value == _hintStyle) {
      return;
    }
    _hintStyle = value;
    _disposeHint();
    markNeedsPaint();
  }

  TextScaler get textScaler => _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) {
      return;
    }
    _textScaler = value;
    _disposeHint();
    markNeedsPaint();
  }

  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) {
      return;
    }
    _textDirection = value;
    _disposeHint();
    markNeedsPaint();
  }

  double get devicePixelRatio => _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) {
      return;
    }
    _devicePixelRatio = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  Color get cursorColor => _cursorColor;
  set cursorColor(Color value) {
    if (value == _cursorColor) {
      return;
    }
    _cursorColor = value;
    markNeedsPaint();
  }

  Color get selectionColor => _selectionColor;
  set selectionColor(Color value) {
    if (value == _selectionColor) {
      return;
    }
    _selectionColor = value;
    markNeedsPaint();
  }

  TextEditingValue? get platformValue => _platformValue;
  set platformValue(TextEditingValue? value) {
    if (value == _platformValue) {
      return;
    }
    _platformValue = value;
    markNeedsSemanticsUpdate();
  }

  int get platformValueStart => _platformValueStart;
  set platformValueStart(int value) {
    if (value == _platformValueStart) {
      return;
    }
    _platformValueStart = value;
    markNeedsSemanticsUpdate();
  }

  NoteViewDelegate? get delegate => _delegate;
  set delegate(NoteViewDelegate? value) {
    if (identical(value, _delegate)) {
      return;
    }
    _delegate = value;
    markNeedsSemanticsUpdate();
  }

  ValueChanged<int>? get onToggleTask => _onToggleTask;
  set onToggleTask(ValueChanged<int>? value) {
    if (value == _onToggleTask) {
      return;
    }
    _onToggleTask = value;
    markNeedsSemanticsUpdate();
  }

  LayerLink? get startHandleLayerLink => _startHandleLayerLink;
  set startHandleLayerLink(LayerLink? value) {
    if (identical(value, _startHandleLayerLink)) {
      return;
    }
    _startHandleLayerLink = value;
    markNeedsPaint();
  }

  LayerLink? get endHandleLayerLink => _endHandleLayerLink;
  set endHandleLayerLink(LayerLink? value) {
    if (identical(value, _endHandleLayerLink)) {
      return;
    }
    _endHandleLayerLink = value;
    markNeedsPaint();
  }

  List<NoteViewDecoration> get decorations => _decorations;
  set decorations(List<NoteViewDecoration> value) {
    if (identical(value, _decorations)) {
      return;
    }
    final List<NoteViewDecoration> old = _decorations;
    _decorations = value;
    if (_decorationsChanged(old, value)) {
      markNeedsPaint();
    }
  }

  static bool _decorationsChanged(
    List<NoteViewDecoration> old,
    List<NoteViewDecoration> next,
  ) {
    if (old.length != next.length) {
      return true;
    }
    for (int i = 0; i < next.length; i++) {
      final NoteViewDecoration previous = old[i];
      final NoteViewDecoration current = next[i];
      if (previous.runtimeType != current.runtimeType ||
          current.shouldRepaint(previous)) {
        return true;
      }
    }
    return false;
  }

  double get scrollOffset => _offset?.pixels ?? 0;

  _TableBand? _bandAt(double contentY) {
    for (final _TableBand band in _tableBands) {
      if (band.holds(contentY)) {
        return band;
      }
    }
    return null;
  }

  double _offsetOf(_TableBand band) => _tableOffsets[band.key] ?? 0;

  double tableScrollOffsetAt(double contentY) {
    final _TableBand? band = _bandAt(contentY);
    return band == null ? 0 : _offsetOf(band);
  }

  Offset localToContent(Offset local) {
    final double y = local.dy + scrollOffset;
    return Offset(local.dx + tableScrollOffsetAt(y), y);
  }

  Offset contentToLocal(Offset content) => Offset(
    content.dx - tableScrollOffsetAt(content.dy),
    content.dy - scrollOffset,
  );

  Offset globalToContent(Offset global) =>
      localToContent(globalToLocal(global));

  Offset contentToGlobal(Offset content) =>
      localToGlobal(contentToLocal(content));

  Rect? placeContentRect(Rect contentRect) {
    final _TableBand? band = _bandAt(contentRect.center.dy);
    if (band == null) {
      return contentRect;
    }
    final Rect shifted = contentRect.shift(Offset(-_offsetOf(band), 0));
    final Rect clipped = shifted.intersect(
      Rect.fromLTRB(0, band.top, size.width, band.bottom),
    );
    if (clipped.width < 0 || clipped.height < 0) {
      return null;
    }
    return clipped;
  }

  Rect? contentRectToLocal(Rect contentRect) =>
      placeContentRect(contentRect)?.shift(Offset(0, -scrollOffset));

  Rect get visibleContentRect =>
      Rect.fromLTWH(0, scrollOffset, size.width, size.height);

  Rect get paintWindow {
    if (_offset == null) {
      return Rect.fromLTWH(
        0,
        0,
        size.width,
        math.max(size.height, _noteLayout.size.height),
      );
    }
    final Rect visible = visibleContentRect;
    return Rect.fromLTRB(
      visible.left,
      visible.top - visible.height,
      visible.right,
      visible.bottom + visible.height,
    );
  }

  TextRange? get selectedPhotoRange =>
      noteSelectedPhotoRange(_tree, _source, _selection);

  TextRange? photoLineAt(Offset contentPoint) {
    RenderBox? child = firstChild;
    while (child != null) {
      final NotePhotoParentData data = child.parentData! as NotePhotoParentData;
      if (data.figureRect.contains(contentPoint)) {
        return data.lineRange;
      }
      child = data.nextSibling;
    }
    return null;
  }

  ValueListenable<bool> get selectionStartInViewport =>
      _selectionStartInViewport;

  ValueListenable<bool> get selectionEndInViewport => _selectionEndInViewport;

  bool scrollTableBy(double contentY, double delta) {
    final _TableBand? band = _bandAt(contentY);
    if (band == null) {
      return false;
    }
    return _setTableOffset(band, _offsetOf(band) + delta);
  }

  void revealTableRect(Rect contentRect) {
    final _TableBand? band = _bandAt(contentRect.center.dy);
    if (band == null) {
      return;
    }
    final double column = _noteLayout.inputs.columnWidth;
    final double current = _offsetOf(band);
    final double target =
        contentRect.left - current < 0 || contentRect.width > column
        ? contentRect.left
        : contentRect.right - current > column
        ? contentRect.right - column
        : current;
    _setTableOffset(band, target);
  }

  bool _setTableOffset(_TableBand band, double target) {
    final double next = target.clamp(0.0, band.maxOffset);
    if (next == _offsetOf(band)) {
      return false;
    }
    _tableOffsets = Map<int, double>.unmodifiable(<int, double>{
      ..._tableOffsets,
      band.key: next,
    });
    markNeedsPaint();
    markNeedsSemanticsUpdate();
    return true;
  }

  @visibleForTesting
  List<Rect> get debugPaintedFragmentRects => _paintedFragmentRects;

  bool get _caretShown {
    final NoteSelection? selection = _selection;
    return attached &&
        _focused &&
        !_readOnly &&
        selection != null &&
        selection.isCollapsed &&
        selectedPhotoRange == null;
  }

  Rect? get caretRect {
    final NoteSelection? selection = _selection;
    if (selection == null || !_caretShown) {
      return null;
    }
    final int position = selection.head;
    final Rect? caret = contentRectToLocal(
      _noteLayout.caretRect(position, selection.affinity),
    );
    final Rect? lineBox = contentRectToLocal(
      _noteLayout.lineBoxAt(position, selection.affinity).rect,
    );
    if (caret == null || lineBox == null) {
      return null;
    }
    return noteCaretRect(
      caret: caret,
      lineBox: lineBox,
      devicePixelRatio: _devicePixelRatio,
    );
  }

  bool get caretBlinkVisible => _blink.visible;

  void _updateBlink({bool restart = false}) {
    if (_caretShown) {
      if (restart || !_blink.isRunning) {
        _blink.start();
      }
    } else if (_blink.isRunning || _blink.visible) {
      _blink.stop();
      markNeedsPaint();
    }
  }

  void _handleScroll() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void _disposeHint() {
    _hintPainter?.dispose();
    _hintPainter = null;
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..explicitChildNodes = true;
  }

  @override
  void assembleSemanticsNode(
    SemanticsNode node,
    SemanticsConfiguration config,
    Iterable<SemanticsNode> children,
  ) {
    if (_readOnly) {
      _semanticsNodes.dropTextField();
    }
    node.updateWith(
      config: config,
      childrenInInversePaintOrder: <SemanticsNode>[
        if (!_readOnly) _textFieldNode(),
        ..._tableNodes(),
        ..._readerNodes(),
        ...children,
        ..._checkboxNodes(),
      ],
    );
  }

  @override
  void clearSemantics() {
    super.clearSemantics();
    _semanticsNodes = NoteSemanticsNodes();
  }

  TextEditingValue get _semanticsValue {
    final TextEditingValue? window = _platformValue;
    if (window != null) {
      return window;
    }
    final NoteSelection? selection = _selection;
    final OffsetMap map = _visibleText.map;
    int visible(int offset) =>
        map.sourceToVisible(offset.clamp(0, map.sourceLength));
    return TextEditingValue(
      text: _visibleText.text,
      selection: selection == null
          ? const TextSelection.collapsed(offset: -1)
          : TextSelection(
              baseOffset: visible(selection.anchor),
              extentOffset: visible(selection.head),
              affinity: selection.affinity,
            ),
    );
  }

  SemanticsNode _textFieldNode() {
    final TextEditingValue value = _semanticsValue;
    final TextSelection selection = value.selection;
    final SemanticsConfiguration config = SemanticsConfiguration()
      ..sortKey = const OrdinalSortKey(-1)
      ..isTextField = true
      ..label = _semanticsLabel
      ..isMultiline = true
      ..isFocused = _focused
      ..isReadOnly = false
      ..inputType = SemanticsInputType.text
      ..textDirection = _textDirection
      ..value = value.text;
    if (selection.isValid) {
      config.textSelection = selection;
    }
    final NoteViewDelegate? delegate = _delegate;
    if (delegate != null) {
      _addTextFieldActions(config, delegate, value);
    }
    return _semanticsNodes.textField()
      ..updateWith(config: config)
      ..rect = Offset.zero & size;
  }

  void _addTextFieldActions(
    SemanticsConfiguration config,
    NoteViewDelegate delegate,
    TextEditingValue value,
  ) {
    final int start = _platformValueStart;
    final String text = value.text;
    final TextSelection selection = value.selection;
    void moveTo(int target, bool extendSelection) {
      delegate.selectVisible(
        TextSelection(
          baseOffset: (extendSelection ? selection.baseOffset : target) + start,
          extentOffset: target + start,
        ),
      );
    }

    if (_focused) {
      config.onSetSelection = (TextSelection next) {
        delegate.selectVisible(
          TextSelection(
            baseOffset: next.baseOffset + start,
            extentOffset: next.extentOffset + start,
            affinity: next.affinity,
          ),
        );
      };
      config.onSetText = delegate.replaceVisibleText;
      config.onPaste = delegate.pasteClipboard;
    }
    if (!selection.isValid) {
      return;
    }
    final int extent = selection.extentOffset.clamp(0, text.length);
    if (extent < text.length) {
      config.onMoveCursorForwardByCharacter = (bool extendSelection) {
        moveTo(noteNextCharacterOffset(text, extent), extendSelection);
      };
      config.onMoveCursorForwardByWord = (bool extendSelection) {
        moveTo(_nextWordEnd(text, extent), extendSelection);
      };
    }
    if (extent > 0) {
      config.onMoveCursorBackwardByCharacter = (bool extendSelection) {
        moveTo(notePreviousCharacterOffset(text, extent), extendSelection);
      };
      config.onMoveCursorBackwardByWord = (bool extendSelection) {
        moveTo(_previousWordStart(text, extent), extendSelection);
      };
    }
    if (!selection.isCollapsed) {
      config
        ..onCopy = delegate.copySelection
        ..onCut = delegate.cutSelection;
    }
  }

  bool _isWordGap(String text, int index) => _wordGap.hasMatch(text[index]);

  int _nextWordEnd(String text, int from) {
    int at = from;
    while (at < text.length && _isWordGap(text, at)) {
      at++;
    }
    if (at >= text.length) {
      return text.length;
    }
    final OffsetMap map = _visibleText.map;
    final int source = map.visibleToSource(at + _platformValueStart).downstream;
    final int end =
        map.sourceToVisible(_noteLayout.wordBoundary(source).end) -
        _platformValueStart;
    return end > at
        ? math.min(end, text.length)
        : noteNextCharacterOffset(text, at);
  }

  int _previousWordStart(String text, int from) {
    int at = from;
    while (at > 0 && _isWordGap(text, at - 1)) {
      at--;
    }
    if (at <= 0) {
      return 0;
    }
    final OffsetMap map = _visibleText.map;
    final int source = map.visibleToSource(at + _platformValueStart).upstream;
    final int begin =
        map.sourceToVisible(
          _noteLayout.wordBoundary(math.max(0, source - 1)).start,
        ) -
        _platformValueStart;
    return begin < at
        ? math.max(begin, 0)
        : notePreviousCharacterOffset(text, at);
  }

  Rect _withMinimumTarget(Rect rect) {
    final double minimum = defaultTargetPlatform == TargetPlatform.android
        ? _androidTarget
        : _desktopTarget;
    return Rect.fromCenter(
      center: rect.center,
      width: math.max(rect.width, minimum),
      height: math.max(rect.height, minimum),
    );
  }

  List<Rect> _checkboxAreas(List<Rect> boxes) {
    final List<(double, Rect)> targets = <(double, Rect)>[
      for (final Rect box in boxes) (box.center.dy, _withMinimumTarget(box)),
    ];
    return List<Rect>.unmodifiable(<Rect>[
      for (final (double centre, Rect target) in targets)
        _onView(_ownSide(centre, target, targets)),
    ]);
  }

  Rect _ownSide(double centre, Rect target, List<(double, Rect)> targets) =>
      targets.fold(target, (Rect area, (double, Rect) other) {
        final (double otherCentre, Rect otherTarget) = other;
        if (!otherTarget.overlaps(target)) {
          return area;
        }
        final double halfway = _onPixelGrid((centre + otherCentre) / 2);
        if (otherCentre > centre) {
          return Rect.fromLTRB(
            area.left,
            area.top,
            area.right,
            math.min(area.bottom, halfway),
          );
        }
        if (otherCentre < centre) {
          return Rect.fromLTRB(
            area.left,
            math.max(area.top, halfway),
            area.right,
            area.bottom,
          );
        }
        return area;
      });

  double _onPixelGrid(double value) =>
      (value * _devicePixelRatio).roundToDouble() / _devicePixelRatio;

  Rect _onView(Rect area) {
    final Rect bounds = Offset.zero & size;
    return area.overlaps(bounds) ? area.intersect(bounds) : area;
  }

  List<SemanticsNode> _checkboxNodes() {
    final List<(NoteCheckboxSemantics, Rect)> placed =
        <(NoteCheckboxSemantics, Rect)>[
          for (final NoteCheckboxSemantics box in noteCheckboxSemanticsOf(
            _tree,
            _visibleText,
          ))
            if (contentRectToLocal(_noteLayout.rangeBounds(box.boxRange))
                case final Rect rect)
              (box, rect),
        ];
    final List<Rect> areas = _checkboxAreas(<Rect>[
      for (final (NoteCheckboxSemantics _, Rect rect) in placed) rect,
    ]);
    final List<SemanticsNode> nodes = _semanticsNodes.checkboxes(<int>[
      for (final (NoteCheckboxSemantics box, Rect _) in placed) box.boxStart,
    ]);
    final NoteViewDelegate? delegate = _readOnly ? null : _delegate;
    final ValueChanged<int>? toggle = delegate == null
        ? _onToggleTask
        : delegate.toggleCheckbox;
    for (int i = 0; i < placed.length; i++) {
      final (NoteCheckboxSemantics box, Rect _) = placed[i];
      final int boxStart = box.boxStart;
      final SemanticsConfiguration config = SemanticsConfiguration()
        ..sortKey = OrdinalSortKey(boxStart.toDouble())
        ..isChecked = box.checked
        ..label = box.label
        ..textDirection = _textDirection;
      if (toggle != null) {
        config.onTap = () => toggle(boxStart);
      }
      nodes[i]
        ..updateWith(config: config)
        ..rect = areas[i];
    }
    return nodes;
  }

  Rect? _insideView(Rect? rect) {
    if (rect == null) {
      return null;
    }
    final Rect bounds = Offset.zero & size;
    return rect.overlaps(bounds)
        ? rect.intersect(bounds)
        : Rect.fromLTRB(
            math.max(rect.left, 0),
            rect.top,
            math.max(math.max(rect.left, 0), math.min(rect.right, size.width)),
            rect.bottom,
          );
  }

  List<SemanticsNode> _tableNodes() {
    final List<(NoteTableSemantics, Rect)> placed =
        <(NoteTableSemantics, Rect)>[
          for (final NoteTableSemantics table in noteTableSemanticsOf(
            _tree,
            _visibleText,
          ))
            if (_insideView(
                  contentRectToLocal(_noteLayout.rangeBounds(table.range)),
                )
                case final Rect rect)
              (table, rect),
        ];
    final List<SemanticsNode> nodes = _semanticsNodes.tables(<int>[
      for (final (NoteTableSemantics table, Rect _) in placed)
        table.range.start,
    ]);
    for (int i = 0; i < placed.length; i++) {
      final (NoteTableSemantics table, Rect rect) = placed[i];
      final SemanticsConfiguration config = SemanticsConfiguration()
        ..sortKey = OrdinalSortKey(table.range.start.toDouble())
        ..label = noteTableSemanticsLabel(
          rows: table.rows,
          columns: table.columns,
        )
        ..textDirection = _textDirection;
      if (_readOnly) {
        config.value = table.text;
      }
      nodes[i]
        ..updateWith(config: config)
        ..rect = rect;
    }
    return nodes;
  }

  List<SemanticsNode> _readerNodes() {
    final List<(NoteBlockSemantics, Rect)> placed = _readOnly
        ? <(NoteBlockSemantics, Rect)>[
            for (final NoteBlockSemantics block in noteReaderSemanticsOf(
              _tree,
              _visibleText,
            ))
              if (contentRectToLocal(_noteLayout.rangeBounds(block.range))
                  case final Rect rect)
                (block, rect),
          ]
        : const <(NoteBlockSemantics, Rect)>[];
    final List<SemanticsNode> nodes = _semanticsNodes.blocks(<int>[
      for (final (NoteBlockSemantics block, Rect _) in placed)
        block.range.start,
    ]);
    for (int i = 0; i < placed.length; i++) {
      final (NoteBlockSemantics block, Rect rect) = placed[i];
      final SemanticsConfiguration config = SemanticsConfiguration()
        ..sortKey = OrdinalSortKey(block.range.start.toDouble())
        ..label = block.text
        ..textDirection = _textDirection;
      final int? level = block.headingLevel;
      if (level != null) {
        config
          ..isHeader = true
          ..headingLevel = level;
      }
      nodes[i]
        ..updateWith(config: config)
        ..rect = rect;
    }
    return nodes;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! NotePhotoParentData) {
      child.parentData = NotePhotoParentData();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _offset?.addListener(_handleScroll);
    _updateBlink();
  }

  @override
  void detach() {
    _offset?.removeListener(_handleScroll);
    _blink.stop();
    _disposeHint();
    super.detach();
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    _disposeHint();
    _selectionStartInViewport.dispose();
    _selectionEndInViewport.dispose();
    super.dispose();
  }

  double get _contentHeight => _noteLayout.size.height + _bottomInset;

  Size _sizeFor(BoxConstraints constraints) {
    if (_offset != null) {
      assert(
        constraints.hasBoundedHeight,
        'A scrolling note view needs a bounded height.',
      );
      return constraints.biggest;
    }
    return constraints.constrain(Size(constraints.maxWidth, _contentHeight));
  }

  @override
  double computeMinIntrinsicWidth(double height) => _noteLayout.size.width;

  @override
  double computeMaxIntrinsicWidth(double height) => _noteLayout.size.width;

  @override
  double computeMinIntrinsicHeight(double width) => _contentHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _contentHeight;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _sizeFor(constraints);

  @override
  void performLayout() {
    size = _sizeFor(constraints);
    final ViewportOffset? viewport = _offset;
    if (viewport != null) {
      viewport.applyViewportDimension(size.height);
      viewport.applyContentDimensions(
        0,
        math.max(0, _contentHeight - size.height),
      );
    }
    RenderBox? child = firstChild;
    while (child != null) {
      final NotePhotoParentData data = child.parentData! as NotePhotoParentData;
      child.layout(BoxConstraints.tightFor(width: data.figureRect.width));
      data.offset = data.figureRect.topLeft;
      child = data.nextSibling;
    }
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    RenderBox? child = lastChild;
    while (child != null) {
      final NotePhotoParentData data = child.parentData! as NotePhotoParentData;
      final RenderBox current = child;
      final bool isHit = result.addWithPaintOffset(
        offset: data.offset - Offset(0, scrollOffset),
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) =>
            current.hitTest(result, position: transformed),
      );
      if (isHit) {
        return true;
      }
      child = data.previousSibling;
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final NotePhotoParentData data = child.parentData! as NotePhotoParentData;
    final Offset shift = data.offset - Offset(0, scrollOffset);
    transform.translateByDouble(shift.dx, shift.dy, 0, 1);
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerScrollEvent) {
      _handlePointerScroll(event);
    } else if (event is PointerPanZoomUpdateEvent) {
      final Offset pan = event.localPanDelta;
      final double contentY = localToContent(event.localPosition).dy;
      if (pan.dx.abs() > pan.dy.abs() && _bandAt(contentY) != null) {
        scrollTableBy(contentY, -pan.dx);
      }
    }
  }

  void _handlePointerScroll(PointerScrollEvent event) {
    final double contentY = localToContent(event.localPosition).dy;
    if (_bandAt(contentY) == null) {
      return;
    }
    final bool shift = HardwareKeyboard.instance.isShiftPressed;
    final double horizontal = shift
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    final double vertical = shift ? event.scrollDelta.dx : event.scrollDelta.dy;
    if (horizontal == 0 || horizontal.abs() < vertical.abs()) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      (PointerSignalEvent resolved) => scrollTableBy(contentY, horizontal),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_offset != null) {
      _clipLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        _paintContents,
        oldLayer: _clipLayer.layer,
      );
    } else {
      _clipLayer.layer = null;
      _paintContents(context, offset);
    }
    _paintHandleLayers(context, offset);
  }

  void _paintContents(PaintingContext context, Offset offset) {
    final Offset origin = offset + Offset(0, -scrollOffset);
    final Rect window = paintWindow;
    final List<LaidOutRow> rows = _noteLayout.flow.rowsIntersecting(
      window.top,
      window.bottom,
    );
    late final TextRange? span = _sourceSpanWithin(_noteLayout, rows, window);
    _paintBackgrounds(context, origin, rows);
    _paintFragments(context, origin, rows, window);
    _paintRules(context, origin, rows);
    _paintHint(context, origin);
    _paintSelection(context, origin, () => span);
    _paintPhotos(context, origin, window);
    _paintComposing(context, origin, () => span);
    _paintDecorations(context, origin);
    _paintCaret(context, origin);
  }

  void _inContentSpace(
    PaintingContext context,
    Offset origin,
    void Function(Canvas canvas) draw,
  ) {
    final Canvas canvas = context.canvas;
    canvas
      ..save()
      ..translate(origin.dx, origin.dy);
    draw(canvas);
    canvas.restore();
  }

  void _eachRow(
    Canvas canvas,
    List<LaidOutRow> rows,
    void Function(LaidOutRow row) draw,
  ) {
    for (final LaidOutRow row in rows) {
      final _TableBand? band = row.row.kind == LayoutRowKind.table
          ? _bandAt(row.top)
          : null;
      if (band == null) {
        draw(row);
        continue;
      }
      canvas
        ..save()
        ..clipRect(Rect.fromLTRB(0, band.top, size.width, band.bottom))
        ..translate(-_offsetOf(band), 0);
      draw(row);
      canvas.restore();
    }
  }

  void _paintBackgrounds(
    PaintingContext context,
    Offset origin,
    List<LaidOutRow> rows,
  ) {
    _inContentSpace(context, origin, (Canvas canvas) {
      _eachRow(canvas, rows, (LaidOutRow row) {
        for (final RowDecoration decoration in row.decorations) {
          if (decoration.paintsBehindText) {
            decoration.paint(canvas, Offset.zero);
          }
        }
      });
    });
  }

  void _paintFragments(
    PaintingContext context,
    Offset origin,
    List<LaidOutRow> rows,
    Rect window,
  ) {
    final List<Rect> painted = <Rect>[];
    _inContentSpace(context, origin, (Canvas canvas) {
      _eachRow(canvas, rows, (LaidOutRow row) {
        for (final LineFragment fragment in row.fragments) {
          final Rect rect = fragment.rect;
          if (!rect.overlaps(window)) {
            continue;
          }
          painted.add(rect);
          if (fragment.paragraph != null) {
            fragment.paint(canvas, Offset.zero);
          }
        }
      });
    });
    _paintedFragmentRects = List<Rect>.unmodifiable(painted);
  }

  void _paintRules(
    PaintingContext context,
    Offset origin,
    List<LaidOutRow> rows,
  ) {
    _inContentSpace(context, origin, (Canvas canvas) {
      _eachRow(canvas, rows, (LaidOutRow row) {
        for (final RowDecoration decoration in row.decorations) {
          if (!decoration.paintsBehindText) {
            decoration.paint(canvas, Offset.zero);
          }
        }
      });
    });
  }

  void _paintHint(PaintingContext context, Offset origin) {
    if (_source.isNotEmpty || _hintText.isEmpty) {
      return;
    }
    final TextPainter painter = _hintPainter ??= TextPainter(
      text: TextSpan(text: _hintText, style: _hintStyle),
      textScaler: _textScaler,
      textDirection: _textDirection,
    );
    painter.layout(maxWidth: size.width);
    _inContentSpace(
      context,
      origin,
      (Canvas canvas) => painter.paint(canvas, Offset.zero),
    );
  }

  void _paintSelection(
    PaintingContext context,
    Offset origin,
    TextRange? Function() span,
  ) {
    final NoteSelection? selection = _selection;
    if (selection == null || selection.isCollapsed) {
      return;
    }
    final NoteSelection? shown = _selectionWithin(selection, span());
    if (shown == null) {
      return;
    }
    final List<Rect> boxes = _placed(_noteLayout.selectionBoxes(shown));
    _inContentSpace(
      context,
      origin,
      (Canvas canvas) => paintNoteSelection(canvas, boxes, _selectionColor),
    );
  }

  List<Rect> _placed(List<Rect> contentRects) =>
      List<Rect>.unmodifiable(contentRects.map(placeContentRect).nonNulls);

  void _paintPhotos(PaintingContext context, Offset origin, Rect window) {
    RenderBox? child = firstChild;
    while (child != null) {
      final NotePhotoParentData data = child.parentData! as NotePhotoParentData;
      if (data.figureRect.overlaps(window)) {
        context.paintChild(child, origin + data.offset);
      }
      child = data.nextSibling;
    }
  }

  void _paintComposing(
    PaintingContext context,
    Offset origin,
    TextRange? Function() span,
  ) {
    final TextRange composing = _composing;
    if (!composing.isValid ||
        composing.isCollapsed ||
        composing.end > _source.length) {
      return;
    }
    final NoteSelection? shown = _selectionWithin(
      NoteSelection(anchor: composing.start, head: composing.end),
      span(),
    );
    if (shown == null) {
      return;
    }
    final List<Rect> underlines = _placed(
      noteComposingUnderlines(_noteLayout.selectionBoxes(shown)),
    );
    _inContentSpace(
      context,
      origin,
      (Canvas canvas) => paintNoteComposingUnderline(
        canvas,
        underlines,
        TypographyTokens.noteBody.color!,
      ),
    );
  }

  void _paintDecorations(PaintingContext context, Offset origin) {
    if (_decorations.isEmpty) {
      return;
    }
    _inContentSpace(context, origin, (Canvas canvas) {
      for (final NoteViewDecoration decoration in _decorations) {
        decoration.paint(canvas, _noteLayout, placeContentRect);
      }
    });
  }

  void _paintCaret(PaintingContext context, Offset origin) {
    final Rect? caret = caretRect;
    if (caret == null || !_blink.visible) {
      return;
    }
    _inContentSpace(
      context,
      origin,
      (Canvas canvas) => paintNoteCaret(
        canvas,
        caret.shift(Offset(0, scrollOffset)),
        _cursorColor,
      ),
    );
  }

  void _paintHandleLayers(PaintingContext context, Offset offset) {
    final NoteSelection? selection = _selection;
    if (selection == null) {
      _selectionStartInViewport.value = false;
      _selectionEndInViewport.value = false;
      return;
    }
    final Rect viewport = (Offset.zero & size).inflate(_viewportSlack);
    _selectionStartInViewport.value = viewport.contains(
      contentToLocal(
        _noteLayout.caretRect(selection.start, selection.affinity).topLeft,
      ),
    );
    _selectionEndInViewport.value = viewport.contains(
      contentToLocal(
        _noteLayout.caretRect(selection.end, selection.affinity).topLeft,
      ),
    );
    final LayerLink? startLink = _startHandleLayerLink;
    final LayerLink? endLink = _endHandleLayerLink;
    if (startLink == null || endLink == null) {
      return;
    }
    final SelectionEndpoints endpoints = _noteLayout.selectionEndpoints(
      selection,
    );
    context
      ..pushLayer(
        LeaderLayer(
          link: startLink,
          offset: _clampedLocal(endpoints.start.point) + offset,
        ),
        _paintNothing,
        Offset.zero,
      )
      ..pushLayer(
        LeaderLayer(
          link: endLink,
          offset: _clampedLocal(endpoints.end.point) + offset,
        ),
        _paintNothing,
        Offset.zero,
      );
  }

  Offset _clampedLocal(Offset contentPoint) {
    final Offset local = contentToLocal(contentPoint);
    return Offset(
      local.dx.clamp(0.0, size.width),
      local.dy.clamp(0.0, size.height),
    );
  }

  static void _paintNothing(PaintingContext context, Offset offset) {}
}
