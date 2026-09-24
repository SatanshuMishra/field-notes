import 'dart:math' as math;

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_typography.dart';
import 'package:field_notes/features/note_engine/layout/photo_planner.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/painting.dart';

const double _besideFloatSlack = 0.5;

final class PlacedPhoto {
  const PlacedPhoto({
    required this.rowIndex,
    required this.sourceRange,
    required this.visibleRange,
    required this.reference,
    required this.occurrence,
    required this.plan,
    required this.figureRect,
    required this.imageRect,
  });

  final int rowIndex;
  final TextRange sourceRange;
  final TextRange visibleRange;
  final String reference;
  final int occurrence;
  final PhotoLayoutPlan plan;
  final Rect figureRect;
  final Rect imageRect;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlacedPhoto &&
          rowIndex == other.rowIndex &&
          sourceRange == other.sourceRange &&
          visibleRange == other.visibleRange &&
          reference == other.reference &&
          occurrence == other.occurrence &&
          plan == other.plan &&
          figureRect == other.figureRect &&
          imageRect == other.imageRect;

  @override
  int get hashCode => Object.hash(
    rowIndex,
    sourceRange,
    visibleRange,
    reference,
    occurrence,
    plan,
    figureRect,
    imageRect,
  );

  @override
  String toString() =>
      'PlacedPhoto(row $rowIndex, $reference#$occurrence, '
      's[${sourceRange.start}, ${sourceRange.end}), $figureRect, $plan)';
}

final class NoteFlow {
  NoteFlow._({
    required this.inputs,
    required List<LaidOutRow> rows,
    required List<PlacedPhoto> photos,
    required this.height,
  }) : rows = List<LaidOutRow>.unmodifiable(rows),
       photos = List<PlacedPhoto>.unmodifiable(photos),
       _bottomsSoFar = List<double>.unmodifiable(_runningMaxBottoms(rows));

  final LayoutInputs inputs;
  final List<LaidOutRow> rows;
  final List<PlacedPhoto> photos;
  final double height;
  final List<double> _bottomsSoFar;

  double get columnWidth => inputs.columnWidth;

  Iterable<LineFragment> get fragments =>
      rows.expand((LaidOutRow row) => row.fragments);

  List<LaidOutRow> rowsIntersecting(double top, double bottom) {
    if (rows.isEmpty || bottom < top) {
      return List<LaidOutRow>.unmodifiable(const <LaidOutRow>[]);
    }
    int low = 0;
    int high = rows.length;
    while (low < high) {
      final int mid = (low + high) >> 1;
      if (_bottomsSoFar[mid] < top) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    final int first = low;
    low = first;
    high = rows.length;
    while (low < high) {
      final int mid = (low + high) >> 1;
      if (rows[mid].top <= bottom) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return List<LaidOutRow>.unmodifiable(<LaidOutRow>[
      for (int i = first; i < low; i++)
        if (rows[i].bottom >= top) rows[i],
    ]);
  }

  static List<double> _runningMaxBottoms(List<LaidOutRow> rows) {
    final List<double> bottoms = <double>[];
    double running = double.negativeInfinity;
    for (final LaidOutRow row in rows) {
      running = math.max(running, row.bottom);
      bottoms.add(running);
    }
    return bottoms;
  }

  @override
  String toString() =>
      'NoteFlow(${rows.length} rows, ${photos.length} photos, '
      'height: $height)';
}

NoteFlow flowNote(
  LayoutInputs inputs, {
  RowLayouter rowLayouter = layoutRow,
  PhotoPlanner photoPlanner = planPhoto,
}) {
  final double column = inputs.columnWidth;
  final double em = NoteTypography.emOf(inputs.textScaler);
  final double belowFloatGap = NoteTypography.paragraphGapEm * em;
  final List<LayoutRow> layoutRows = layoutRowsOf(inputs);
  final List<LaidOutRow> laidOut = <LaidOutRow>[];
  final List<PlacedPhoto> photos = <PlacedPhoto>[];
  final Map<String, int> seen = <String, int>{};
  _Float? active;
  double? anchor;
  double previousBottom = 0;
  double height = 0;
  for (final LayoutRow row in layoutRows) {
    final double own = laidOut.isEmpty
        ? 0
        : anchor ?? previousBottom + row.gapBefore;
    anchor = null;
    final _Float? float = active;
    switch (row.kind) {
      case LayoutRowKind.photo:
        final double top = float == null
            ? own
            : math.max(float.bottom + belowFloatGap, own);
        active = null;
        final MdPhotoLine line = MdPhotoLine.ofBlock(
          _blockOf(row),
          inputs.source,
        );
        final PlacedPhoto photo = _placePhoto(
          inputs,
          row,
          line,
          top: top,
          occurrence: seen[line.reference] ?? 0,
          photoPlanner: photoPlanner,
        );
        seen[photo.reference] = photo.occurrence + 1;
        photos.add(photo);
        laidOut.add(_photoRow(row, photo));
        height = math.max(height, photo.figureRect.bottom);
        switch (photo.plan.mode) {
          case PhotoMode.floatLeft:
          case PhotoMode.floatRight:
            active = _Float.of(photo, column: column, em: em);
            anchor = top;
            previousBottom = top;
          case PhotoMode.centred:
            previousBottom = photo.figureRect.bottom;
        }
      case LayoutRowKind.table:
      case LayoutRowKind.code:
      case LayoutRowKind.divider:
        final double top = float == null
            ? own
            : math.max(float.bottom + belowFloatGap, own);
        active = null;
        final LaidOutRow result = rowLayouter(
          inputs,
          row,
          RowRegion(top: top, left: 0, width: column),
        );
        laidOut.add(result);
        previousBottom = result.bottom;
        height = math.max(height, result.bottom);
      case LayoutRowKind.text:
      case LayoutRowKind.blankLine:
        final (LaidOutRow, bool) placed = float == null
            ? (
                rowLayouter(
                  inputs,
                  row,
                  RowRegion(top: own, left: 0, width: column),
                ),
                false,
              )
            : _besideFloat(inputs, row, own, float, rowLayouter);
        active = placed.$2 ? float : null;
        laidOut.add(placed.$1);
        previousBottom = placed.$1.bottom;
        height = math.max(height, placed.$1.bottom);
    }
  }
  return NoteFlow._(
    inputs: inputs,
    rows: laidOut,
    photos: photos,
    height: height,
  );
}

final class _Float {
  const _Float({
    required this.bottom,
    required this.bandLeft,
    required this.bandWidth,
  });

  factory _Float.of(
    PlacedPhoto photo, {
    required double column,
    required double em,
  }) {
    final double width = photo.plan.width;
    final double gutter = floatGutterEm * em;
    return photo.plan.mode == PhotoMode.floatLeft
        ? _Float(
            bottom: photo.figureRect.bottom,
            bandLeft: width + gutter,
            bandWidth: column - width - gutter,
          )
        : _Float(
            bottom: photo.figureRect.bottom,
            bandLeft: 0,
            bandWidth: column - width - gutter,
          );
  }

  final double bottom;
  final double bandLeft;
  final double bandWidth;

  double get threshold => bottom - _besideFloatSlack;
}

(LaidOutRow, bool) _besideFloat(
  LayoutInputs inputs,
  LayoutRow row,
  double top,
  _Float float,
  RowLayouter rowLayouter,
) {
  final RowRegion full = RowRegion(
    top: top,
    left: 0,
    width: inputs.columnWidth,
  );
  if (top >= float.threshold) {
    return (rowLayouter(inputs, row, full), false);
  }
  final LaidOutRow band = rowLayouter(
    inputs,
    row,
    RowRegion(
      top: top,
      left: float.bandLeft,
      width: float.bandWidth,
      besideFloat: true,
    ),
  );
  final List<VisualLine> lines = <VisualLine>[
    for (final LineFragment fragment in band.fragments)
      if (fragment.kind != FragmentKind.marker) ...fragment.lines,
  ];
  final int crossing = lines.indexWhere(
    (VisualLine line) => line.top >= float.threshold,
  );
  if (crossing < 0) {
    return (band, true);
  }
  if (crossing == 0) {
    return (rowLayouter(inputs, row, full), false);
  }
  final VisualLine split = lines[crossing];
  final int at = split.visibleRange.start;
  final LaidOutRow head = rowLayouter(
    inputs,
    row,
    RowRegion(
      top: top,
      left: float.bandLeft,
      width: float.bandWidth,
      besideFloat: true,
    ),
    visibleTo: at,
  );
  final LaidOutRow tail = rowLayouter(
    inputs,
    row,
    RowRegion(top: split.top, left: 0, width: inputs.columnWidth),
    visibleFrom: at,
  );
  return (
    LaidOutRow(
      row: row,
      fragments: <LineFragment>[...head.fragments, ...tail.fragments],
      decorations: <RowDecoration>[...head.decorations, ...tail.decorations],
      top: head.top,
      bottom: tail.bottom,
      contentWidth: inputs.columnWidth,
      styleRuns: band.styleRuns,
    ),
    false,
  );
}

MdBlock _blockOf(LayoutRow row) {
  final MdBlock? block = row.block;
  if (block == null) {
    throw ArgumentError.value(row, 'row', 'is a photo row without a block');
  }
  return block;
}

PlacedPhoto _placePhoto(
  LayoutInputs inputs,
  LayoutRow row,
  MdPhotoLine line, {
  required double top,
  required int occurrence,
  required PhotoPlanner photoPlanner,
}) {
  final double column = inputs.columnWidth;
  final String reference = line.reference;
  final PhotoLayoutPlan plan = photoPlanner(
    placement: line.placement,
    columnWidth: column,
    textScaler: inputs.textScaler,
    aspect: photoAspectFor(inputs.mediaDimensions[reference]),
    unavailable:
        !line.canResolve || inputs.unavailableMedia.contains(reference),
    caption: line.caption,
    boldText: inputs.boldText,
    locale: inputs.locale,
  );
  final double left = switch (plan.mode) {
    PhotoMode.floatLeft => 0,
    PhotoMode.floatRight => column - plan.width,
    PhotoMode.centred => (column - plan.width) / 2,
  };
  final AtomicObject? atomic = inputs.visibleText.atomicAtSource(
    row.sourceRange.start,
  );
  final int visibleStart = atomic == null
      ? row.visibleRange.start
      : atomic.visibleOffset;
  return PlacedPhoto(
    rowIndex: row.index,
    sourceRange: row.sourceRange,
    visibleRange: TextRange(start: visibleStart, end: visibleStart + 1),
    reference: reference,
    occurrence: occurrence,
    plan: plan,
    figureRect: Rect.fromLTWH(left, top, plan.width, plan.figureHeight),
    imageRect: Rect.fromLTWH(left, top, plan.width, plan.photoHeight),
  );
}

LaidOutRow _photoRow(LayoutRow row, PlacedPhoto photo) => LaidOutRow(
  row: row,
  fragments: <LineFragment>[
    LineFragment(
      rowIndex: row.index,
      kind: FragmentKind.photo,
      visibleRange: photo.visibleRange,
      origin: photo.figureRect.topLeft,
      layoutWidth: photo.figureRect.width,
      height: photo.figureRect.height,
    ),
  ],
  decorations: const <RowDecoration>[],
  top: photo.figureRect.top,
  bottom: photo.figureRect.bottom,
  contentWidth: photo.plan.width,
  styleRuns: <({TextRange visibleRange, String styleKind})>[
    (visibleRange: photo.visibleRange, styleKind: 'photoLine'),
  ],
);
