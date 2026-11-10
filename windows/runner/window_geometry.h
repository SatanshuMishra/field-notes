#ifndef RUNNER_WINDOW_GEOMETRY_H_
#define RUNNER_WINDOW_GEOMETRY_H_

#include <windows.h>

#include <cmath>

constexpr double kMinimumContentWidth = 720;
constexpr double kMinimumContentHeight = 600;
constexpr double kOpeningWindowWidth = 1200;
constexpr double kOpeningWindowHeight = 800;

constexpr double kTitleBarHeight = 42;

inline LONG PhysicalLength(double logical, UINT dpi) {
  return static_cast<LONG>(std::ceil(logical * dpi / USER_DEFAULT_SCREEN_DPI));
}

inline SIZE WindowSizeForContent(double width, double height, UINT dpi) {
  const UINT frame_dpi =
      dpi == 0 ? static_cast<UINT>(USER_DEFAULT_SCREEN_DPI) : dpi;
  RECT frame{0, 0, 0, 0};
  if (!::AdjustWindowRectExForDpi(&frame, WS_OVERLAPPEDWINDOW, FALSE, 0,
                                  frame_dpi)) {
    frame = RECT{0, 0, 0, 0};
  }
  return SIZE{PhysicalLength(width, frame_dpi) + frame.right - frame.left,
              PhysicalLength(height, frame_dpi) + frame.bottom};
}

#endif
