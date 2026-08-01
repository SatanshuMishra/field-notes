import 'package:flutter/foundation.dart';

const double todayRailWidth = 266;

enum TodayLayout { stacked, withRail }

TodayLayout resolveTodayLayout(TargetPlatform platform) {
  return platform == TargetPlatform.macOS
      ? TodayLayout.withRail
      : TodayLayout.stacked;
}
