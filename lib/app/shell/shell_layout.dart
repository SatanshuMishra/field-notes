import 'package:field_notes/domain/platform/desktop_platform.dart';
import 'package:flutter/foundation.dart';

enum ShellLayout { sidebar, bottomBar }

ShellLayout resolveShellLayout(TargetPlatform platform) {
  return isDesktopPlatform(platform)
      ? ShellLayout.sidebar
      : ShellLayout.bottomBar;
}
