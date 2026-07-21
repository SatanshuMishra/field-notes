import 'package:flutter/foundation.dart';

const double todayRailWidth = 300;

enum TodayLayout { stacked, withRail }

TodayLayout resolveTodayLayout(TargetPlatform platform) {
  return platform == TargetPlatform.macOS
      ? TodayLayout.withRail
      : TodayLayout.stacked;
}
