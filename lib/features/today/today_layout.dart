import 'package:field_notes/domain/platform/desktop_platform.dart';
import 'package:flutter/foundation.dart';

const double todayRailWidth = 266;
const double todayRailMinWindowWidth = 1120;

enum TodayLayout { stacked, narrowDesktop, withRail }

TodayLayout resolveTodayLayout(
  TargetPlatform platform, {
  required double windowWidth,
}) {
  if (!isDesktopPlatform(platform)) {
    return TodayLayout.stacked;
  }
  return windowWidth >= todayRailMinWindowWidth
      ? TodayLayout.withRail
      : TodayLayout.narrowDesktop;
}
