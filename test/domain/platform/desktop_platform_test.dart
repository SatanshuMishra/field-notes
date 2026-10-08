import 'package:field_notes/domain/platform/desktop_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS and Windows are desktop platforms and no other platform is', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      final bool expected =
          platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows;
      expect(isDesktopPlatform(platform), expected, reason: platform.name);
    }
    expect(isDesktopPlatform(TargetPlatform.android), isFalse);
    expect(isDesktopPlatform(TargetPlatform.iOS), isFalse);
    expect(isDesktopPlatform(TargetPlatform.linux), isFalse);
    expect(isDesktopPlatform(TargetPlatform.fuchsia), isFalse);
  });
}
