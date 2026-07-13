import 'package:flutter/foundation.dart';

enum ShellLayout { sidebar, bottomBar }

ShellLayout resolveShellLayout(TargetPlatform platform) {
  return platform == TargetPlatform.macOS
      ? ShellLayout.sidebar
      : ShellLayout.bottomBar;
}
