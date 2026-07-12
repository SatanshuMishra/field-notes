import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/shell_layout.dart';

void main() {
  group('resolveShellLayout', () {
    test('macOS resolves to the sidebar layout', () {
      expect(resolveShellLayout(TargetPlatform.macOS), ShellLayout.sidebar);
    });

    test('android resolves to the bottom bar layout', () {
      expect(resolveShellLayout(TargetPlatform.android), ShellLayout.bottomBar);
    });

    test('other platforms fall back to the bottom bar layout', () {
      const List<TargetPlatform> others = <TargetPlatform>[
        TargetPlatform.iOS,
        TargetPlatform.linux,
        TargetPlatform.windows,
        TargetPlatform.fuchsia,
      ];
      for (final TargetPlatform platform in others) {
        expect(resolveShellLayout(platform), ShellLayout.bottomBar);
      }
    });
  });
}
