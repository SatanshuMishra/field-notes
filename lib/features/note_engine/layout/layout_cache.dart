import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/layout/photo_planner.dart';
import 'package:flutter/painting.dart';

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

  final Map<PhotoPlanKey, PhotoLayoutPlan> _plans =
      <PhotoPlanKey, PhotoLayoutPlan>{};
  final Set<PhotoPlanKey> _markedPlans = <PhotoPlanKey>{};

  int get planCount => _plans.length;

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
    _markedPlans.clear();
  }

  void evictUnused() {
    _plans.removeWhere(
      (PhotoPlanKey key, PhotoLayoutPlan plan) => !_markedPlans.contains(key),
    );
  }

  void clear() {
    _plans.clear();
    _markedPlans.clear();
  }
}
