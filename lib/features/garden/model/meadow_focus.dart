import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:field_notes/design/format/plural.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/widgets/meadow_landmarks.dart';
import 'package:field_notes/features/garden/widgets/meadow_ribbon.dart';

const List<String> meadowMonthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

enum MeadowFocusKind { month, landmark }

@immutable
class MeadowFocusCounts {
  const MeadowFocusCounts({required this.blooms, required this.sprouts});

  final int blooms;
  final int sprouts;

  String get label {
    final String blooms = pluralize(this.blooms, 'bloom');
    return sprouts > 0 ? '$blooms · ${pluralize(sprouts, 'sprout')}' : blooms;
  }

  @override
  bool operator ==(Object other) =>
      other is MeadowFocusCounts &&
      other.blooms == blooms &&
      other.sprouts == sprouts;

  @override
  int get hashCode => Object.hash(blooms, sprouts);
}

List<MeadowLandmark> meadowRangedLandmarks(
  MeadowYear year, {
  required bool isCurrentYear,
}) => List<MeadowLandmark>.unmodifiable(<MeadowLandmark>[
  for (final MeadowLandmark landmark in meadowLandmarks(
    year,
    isCurrentYear: isCurrentYear,
  ))
    if (landmark.range != null) landmark,
]);

@immutable
class MeadowFocus {
  const MeadowFocus({
    required this.kind,
    required this.index,
    required this.count,
    required this.range,
    required this.title,
  });

  static MeadowFocus month(MeadowYear year, int index) {
    final int month = index.clamp(0, year.months.length - 1);
    final MeadowRange full = meadowMonthRange(year.months[month]);
    return MeadowFocus(
      kind: MeadowFocusKind.month,
      index: month,
      count: year.months.length,
      range: MeadowRange(
        first: full.first,
        last: math.min(full.last, year.daysInYear - 1),
        key: full.key,
      ),
      title: meadowMonthNames[month],
    );
  }

  static MeadowFocus? landmark(
    MeadowYear year,
    int index, {
    required bool isCurrentYear,
  }) {
    final List<MeadowLandmark> ranged = meadowRangedLandmarks(
      year,
      isCurrentYear: isCurrentYear,
    );
    if (ranged.isEmpty) {
      return null;
    }
    final int at = index.clamp(0, ranged.length - 1);
    final MeadowLandmark landmark = ranged[at];
    return MeadowFocus(
      kind: MeadowFocusKind.landmark,
      index: at,
      count: ranged.length,
      range: landmark.range!,
      title: landmark.title,
    );
  }

  final MeadowFocusKind kind;
  final int index;
  final int count;
  final MeadowRange range;
  final String title;

  bool get isFirst => index <= 0;

  bool get isLast => index >= count - 1;

  String get noun => kind == MeadowFocusKind.month ? 'month' : 'landmark';

  MeadowFocus step(MeadowYear year, int delta, {required bool isCurrentYear}) {
    final int next = (index + delta).clamp(0, count - 1);
    if (next == index) {
      return this;
    }
    return switch (kind) {
      MeadowFocusKind.month => MeadowFocus.month(year, next),
      MeadowFocusKind.landmark =>
        MeadowFocus.landmark(year, next, isCurrentYear: isCurrentYear) ?? this,
    };
  }

  MeadowFocusCounts countsIn(MeadowYear year, {required int growthPoint}) {
    int blooms = 0;
    int sprouts = 0;
    for (final MeadowDay day in year.days.nonNulls) {
      if (day.index < range.first ||
          day.index > range.last ||
          day.index >= growthPoint) {
        continue;
      }
      if (day.mood == null) {
        sprouts++;
      } else {
        blooms++;
      }
    }
    return MeadowFocusCounts(blooms: blooms, sprouts: sprouts);
  }

  @override
  bool operator ==(Object other) =>
      other is MeadowFocus &&
      other.kind == kind &&
      other.index == index &&
      other.count == count &&
      other.range == range &&
      other.title == title;

  @override
  int get hashCode => Object.hash(kind, index, count, range, title);

  @override
  String toString() =>
      'MeadowFocus(kind: $kind, index: $index, title: $title, '
      'range: ${range.first}-${range.last})';
}
