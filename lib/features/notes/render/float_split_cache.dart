import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'note_photo_plan.dart';

const double floatBandBucketEm = 0.5;
const int floatSplitHysteresisLines = 1;
const int floatSplitCacheCapacity = 8;
const double floatEdgeTolerance = 0.5;

bool lineStartsBeside(double top, double floatHeight) =>
    top < floatHeight - floatEdgeTolerance;

int floatBandBucket({required double band, required double em}) {
  final double spare = band - photoBandResidualEm * em;
  return math.max(0, (spare / (floatBandBucketEm * em)).floor());
}

double floatBandWidth({
  required double band,
  required int bucket,
  required double em,
}) =>
    math.min(band, (photoBandResidualEm + bucket * floatBandBucketEm) * em);

@immutable
final class FloatSplit {
  const FloatSplit({
    required this.span,
    required this.scaler,
    required this.bucket,
    required this.width,
    required this.offset,
    required this.head,
    required this.tail,
    required this.lines,
    required this.lineTops,
  });

  final InlineSpan span;
  final TextScaler scaler;
  final int bucket;
  final double width;
  final int offset;
  final InlineSpan head;
  final InlineSpan? tail;
  final int lines;
  final List<double> lineTops;

  bool matches(InlineSpan other, TextScaler otherScaler) =>
      identical(span, other) && scaler == otherScaler;

  int linesBeside(double floatHeight) =>
      lineTops.where((double top) => lineStartsBeside(top, floatHeight)).length;

  bool holdsFor(double floatHeight) {
    final int beside = linesBeside(floatHeight);
    return beside > 0 && (beside - lines).abs() <= floatSplitHysteresisLines;
  }

  @override
  String toString() => 'FloatSplit(at $offset, $lines lines beside, '
      'bucket $bucket, width ${width.toStringAsFixed(1)})';
}

@immutable
final class _SplitKey {
  const _SplitKey(this.span, this.scaler, this.bucket);

  final InlineSpan span;
  final TextScaler scaler;
  final int bucket;

  @override
  bool operator ==(Object other) =>
      other is _SplitKey &&
      identical(span, other.span) &&
      scaler == other.scaler &&
      bucket == other.bucket;

  @override
  int get hashCode => Object.hash(identityHashCode(span), scaler, bucket);
}

final class FloatSplitCache {
  FloatSplitCache({this.capacity = floatSplitCacheCapacity})
      : assert(capacity > 0, 'a cache holds at least one split');

  final int capacity;
  final LinkedHashMap<_SplitKey, FloatSplit> _entries =
      LinkedHashMap<_SplitKey, FloatSplit>();
  FloatSplit? _served;

  int get length => _entries.length;

  FloatSplit? lookup({
    required InlineSpan span,
    required TextScaler scaler,
    required int bucket,
    required double floatHeight,
  }) {
    final FloatSplit? served = _served;
    if (served != null &&
        served.matches(span, scaler) &&
        (served.bucket == bucket || served.bucket == bucket - 1) &&
        served.holdsFor(floatHeight)) {
      return served;
    }
    final _SplitKey key = _SplitKey(span, scaler, bucket);
    final FloatSplit? entry = _entries.remove(key);
    if (entry == null) {
      return null;
    }
    _entries[key] = entry;
    if (!entry.holdsFor(floatHeight)) {
      return null;
    }
    _served = entry;
    return entry;
  }

  FloatSplit store(FloatSplit split) {
    final _SplitKey key = _SplitKey(split.span, split.scaler, split.bucket);
    _entries.remove(key);
    _entries[key] = split;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
    _served = split;
    return split;
  }

  void clear() {
    _entries.clear();
    _served = null;
  }
}
