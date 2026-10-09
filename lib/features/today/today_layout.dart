import 'package:field_notes/domain/platform/desktop_platform.dart';
import 'package:flutter/foundation.dart';

const double todayRailWidth = 266;

enum TodayLayout { stacked, withRail }

TodayLayout resolveTodayLayout(TargetPlatform platform) {
  return isDesktopPlatform(platform)
      ? TodayLayout.withRail
      : TodayLayout.stacked;
}
