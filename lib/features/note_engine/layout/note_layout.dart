import 'dart:ui' show Locale, Offset, Rect, Size, TextAffinity, TextPosition;

import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/painting.dart' show TextScaler;
import 'package:flutter/rendering.dart' show TextSelectionPoint;

enum VerticalMove { up, down }

enum PhotoFlow { floatLeft, floatRight, block }

final class LayoutInputs {
  LayoutInputs({
    required this.source,
    required this.tree,
    required this.visibleText,
    required this.activeLine,
    required this.columnWidth,
    required this.textScaler,
    required this.boldText,
    required this.locale,
    required this.readerMode,
    required Map<String, Size> mediaDimensions,
    Set<String> unavailableMedia = const <String>{},
  }) : mediaDimensions = Map<String, Size>.unmodifiable(mediaDimensions),
       unavailableMedia = Set<String>.unmodifiable(unavailableMedia) {
    if (tree.sourceLength != source.length) {
      throw ArgumentError.value(
        tree.sourceLength,
        'tree.sourceLength',
        'must equal the source length ${source.length}',
      );
    }
    if (visibleText.sourceLength != source.length) {
      throw ArgumentError.value(
        visibleText.sourceLength,
        'visibleText.sourceLength',
        'must equal the source length ${source.length}',
      );
    }
    if (visibleText.activeLine != activeLine) {
      throw ArgumentError.value(
        visibleText.activeLine,
        'visibleText.activeLine',
        'must equal activeLine $activeLine',
      );
    }
    if (readerMode && activeLine != null) {
      throw ArgumentError.value(
        activeLine,
        'activeLine',
        'must be null in reader mode',
      );
    }
    if (!columnWidth.isFinite || columnWidth <= 0) {
      throw ArgumentError.value(
        columnWidth,
        'columnWidth',
        'must be finite and positive',
      );
    }
  }

  final String source;
  final MdTree tree;
  final VisibleText visibleText;
  final int? activeLine;
  final double columnWidth;
  final TextScaler textScaler;
  final bool boldText;
  final Locale locale;
  final bool readerMode;
  final Map<String, Size> mediaDimensions;
  final Set<String> unavailableMedia;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayoutInputs &&
          source == other.source &&
          activeLine == other.activeLine &&
          columnWidth == other.columnWidth &&
          textScaler == other.textScaler &&
          boldText == other.boldText &&
          locale == other.locale &&
          readerMode == other.readerMode &&
          _mapEquals(mediaDimensions, other.mediaDimensions) &&
          _setEquals(unavailableMedia, other.unavailableMedia) &&
          tree == other.tree &&
          visibleText == other.visibleText;

  @override
  int get hashCode => Object.hash(
    source,
    tree,
    visibleText,
    activeLine,
    columnWidth,
    textScaler,
    boldText,
    locale,
    readerMode,
    Object.hashAllUnordered(<int>[
      for (final MapEntry<String, Size> entry in mediaDimensions.entries)
        Object.hash(entry.key, entry.value),
    ]),
    Object.hashAllUnordered(unavailableMedia),
  );

  @override
  String toString() =>
      'LayoutInputs(${source.length} units, active: $activeLine, '
      'width: $columnWidth, $textScaler, bold: $boldText, $locale, '
      'reader: $readerMode, media: $mediaDimensions, '
      'unavailable: $unavailableMedia)';
}

final class LineBox {
  const LineBox({required this.rect, required this.baseline});

  final Rect rect;
  final double baseline;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LineBox && rect == other.rect && baseline == other.baseline;

  @override
  int get hashCode => Object.hash(rect, baseline);

  @override
  String toString() => 'LineBox($rect, baseline: $baseline)';
}

final class FragmentInfo {
  const FragmentInfo({
    required this.blockIndex,
    required this.sourceRange,
    required this.visibleRange,
    required this.lineBox,
    required this.besideFloat,
  });

  final int blockIndex;
  final MdRange sourceRange;
  final MdRange visibleRange;
  final LineBox lineBox;
  final bool besideFloat;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FragmentInfo &&
          blockIndex == other.blockIndex &&
          sourceRange == other.sourceRange &&
          visibleRange == other.visibleRange &&
          lineBox == other.lineBox &&
          besideFloat == other.besideFloat;

  @override
  int get hashCode =>
      Object.hash(blockIndex, sourceRange, visibleRange, lineBox, besideFloat);

  @override
  String toString() =>
      'FragmentInfo($blockIndex, s$sourceRange, v$visibleRange, $lineBox, '
      'besideFloat: $besideFloat)';
}

final class PhotoRect {
  const PhotoRect({
    required this.sourceRange,
    required this.reference,
    required this.occurrence,
    required this.rect,
    required this.imageRect,
    required this.flow,
  });

  final MdRange sourceRange;
  final String reference;
  final int occurrence;
  final Rect rect;
  final Rect imageRect;
  final PhotoFlow flow;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoRect &&
          sourceRange == other.sourceRange &&
          reference == other.reference &&
          occurrence == other.occurrence &&
          rect == other.rect &&
          imageRect == other.imageRect &&
          flow == other.flow;

  @override
  int get hashCode =>
      Object.hash(sourceRange, reference, occurrence, rect, imageRect, flow);

  @override
  String toString() =>
      'PhotoRect($reference#$occurrence, s$sourceRange, $rect, '
      'image: $imageRect, ${flow.name})';
}

final class SelectionEndpoints {
  const SelectionEndpoints({
    required this.start,
    required this.end,
    required this.startLineHeight,
    required this.endLineHeight,
  });

  final TextSelectionPoint start;
  final TextSelectionPoint end;
  final double startLineHeight;
  final double endLineHeight;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectionEndpoints &&
          start == other.start &&
          end == other.end &&
          startLineHeight == other.startLineHeight &&
          endLineHeight == other.endLineHeight;

  @override
  int get hashCode => Object.hash(start, end, startLineHeight, endLineHeight);

  @override
  String toString() =>
      'SelectionEndpoints($start, $end, heights: $startLineHeight, '
      '$endLineHeight)';
}

abstract interface class NoteLayout {
  LayoutInputs get inputs;

  Size get size;

  List<PhotoRect> get photoRects;

  List<FragmentInfo> get fragments;

  Rect caretRect(int position, TextAffinity affinity);

  List<Rect> selectionBoxes(NoteSelection selection);

  SelectionEndpoints selectionEndpoints(NoteSelection selection);

  Rect rangeBounds(MdRange range);

  LineBox lineBoxAt(int position, TextAffinity affinity);

  TextPosition positionAt(Offset point);

  MdRange wordBoundary(int position);

  MdRange lineBoundary(int position, TextAffinity affinity);

  MdRange paragraphBoundary(int position);

  MdRange get documentBoundary;

  TextPosition verticalTarget(
    int position,
    TextAffinity affinity,
    double goalX,
    VerticalMove direction,
  );
}

bool _mapEquals(Map<String, Size> a, Map<String, Size> b) {
  if (a.length != b.length) {
    return false;
  }
  for (final MapEntry<String, Size> entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
