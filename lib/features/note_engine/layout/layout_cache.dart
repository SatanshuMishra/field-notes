import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/photo_planner.dart';
import 'package:flutter/painting.dart';

final class RowCacheKey {
  const RowCacheKey({
    required this.kind,
    required this.sourceText,
    required this.visibleText,
    required this.layoutContext,
    required this.regionWidth,
    required this.besideFloat,
    required this.columnWidth,
    required this.textScaler,
    required this.boldText,
    required this.locale,
    this.visibleFrom,
    this.visibleTo,
  });

  factory RowCacheKey.of(
    LayoutInputs inputs,
    LayoutRow row,
    RowRegion region, {
    int? visibleFrom,
    int? visibleTo,
  }) {
    final int base = row.visibleRange.start;
    return RowCacheKey(
      kind: row.kind,
      sourceText: inputs.source.substring(
        row.sourceRange.start,
        row.sourceRange.end,
      ),
      visibleText: inputs.visibleText.text.substring(
        row.visibleRange.start,
        row.visibleRange.end,
      ),
      layoutContext: row.layoutContext,
      regionWidth: region.width,
      besideFloat: region.besideFloat,
      columnWidth: inputs.columnWidth,
      textScaler: inputs.textScaler,
      boldText: inputs.boldText,
      locale: inputs.locale,
      visibleFrom: visibleFrom == null ? null : visibleFrom - base,
      visibleTo: visibleTo == null ? null : visibleTo - base,
    );
  }

  final LayoutRowKind kind;
  final String sourceText;
  final String visibleText;
  final Object layoutContext;
  final double regionWidth;
  final bool besideFloat;
  final double columnWidth;
  final TextScaler textScaler;
  final bool boldText;
  final Locale locale;
  final int? visibleFrom;
  final int? visibleTo;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RowCacheKey &&
          kind == other.kind &&
          regionWidth == other.regionWidth &&
          besideFloat == other.besideFloat &&
          columnWidth == other.columnWidth &&
          textScaler == other.textScaler &&
          boldText == other.boldText &&
          locale == other.locale &&
          visibleFrom == other.visibleFrom &&
          visibleTo == other.visibleTo &&
          sourceText == other.sourceText &&
          visibleText == other.visibleText &&
          layoutContext == other.layoutContext;

  @override
  int get hashCode => Object.hash(
    kind,
    sourceText,
    visibleText,
    layoutContext,
    regionWidth,
    besideFloat,
    columnWidth,
    textScaler,
    boldText,
    locale,
    visibleFrom,
    visibleTo,
  );

  @override
  String toString() =>
      'RowCacheKey(${kind.name}, ${sourceText.length} units, '
      'width: $regionWidth${besideFloat ? ', besideFloat' : ''}, '
      'from: $visibleFrom, to: $visibleTo)';
}

final class PhotoPlanKey {
  const PhotoPlanKey({
    required this.placement,
    required this.columnWidth,
    required this.textScaler,
    required this.aspect,
    required this.unavailable,
    required this.caption,
    required this.boldText,
    required this.locale,
  });

  final MdPhotoPlacement placement;
  final double columnWidth;
  final TextScaler textScaler;
  final double? aspect;
  final bool unavailable;
  final String caption;
  final bool boldText;
  final Locale? locale;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoPlanKey &&
          placement == other.placement &&
          columnWidth == other.columnWidth &&
          textScaler == other.textScaler &&
          aspect == other.aspect &&
          unavailable == other.unavailable &&
          caption == other.caption &&
          boldText == other.boldText &&
          locale == other.locale;

  @override
  int get hashCode => Object.hash(
    placement,
    columnWidth,
    textScaler,
    aspect,
    unavailable,
    caption,
    boldText,
    locale,
  );

  @override
  String toString() =>
      'PhotoPlanKey($placement, $columnWidth, aspect: $aspect'
      '${unavailable ? ', unavailable' : ''})';
}

final class LayoutCache {
  LayoutCache();

  final Map<RowCacheKey, LaidOutRow> _rows = <RowCacheKey, LaidOutRow>{};
  final Map<PhotoPlanKey, PhotoLayoutPlan> _plans =
      <PhotoPlanKey, PhotoLayoutPlan>{};
  final Set<RowCacheKey> _markedRows = <RowCacheKey>{};
  final Set<PhotoPlanKey> _markedPlans = <PhotoPlanKey>{};

  int get rowCount => _rows.length;

  int get planCount => _plans.length;

  LaidOutRow? lookup(RowCacheKey key, {bool mark = true}) {
    final LaidOutRow? found = _rows[key];
    if (found != null && mark) {
      _markedRows.add(key);
    }
    return found;
  }

  void store(RowCacheKey key, LaidOutRow row, {bool mark = true}) {
    _rows[key] = row;
    if (mark) {
      _markedRows.add(key);
    }
  }

  PhotoLayoutPlan? lookupPlan(PhotoPlanKey key, {bool mark = true}) {
    final PhotoLayoutPlan? found = _plans[key];
    if (found != null && mark) {
      _markedPlans.add(key);
    }
    return found;
  }

  void storePlan(PhotoPlanKey key, PhotoLayoutPlan plan, {bool mark = true}) {
    _plans[key] = plan;
    if (mark) {
      _markedPlans.add(key);
    }
  }

  void beginPass() {
    _markedRows.clear();
    _markedPlans.clear();
  }

  void evictUnused() {
    _rows.removeWhere(
      (RowCacheKey key, LaidOutRow row) => !_markedRows.contains(key),
    );
    _plans.removeWhere(
      (PhotoPlanKey key, PhotoLayoutPlan plan) => !_markedPlans.contains(key),
    );
  }

  void clear() {
    _rows.clear();
    _plans.clear();
    _markedRows.clear();
    _markedPlans.clear();
  }
}
