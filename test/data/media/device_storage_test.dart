import 'dart:io';

import 'package:field_notes/data/media/device_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

FileSystemException _failure(int code) =>
    FileSystemException('x', 'p', OSError('full', code));

void main() {
  test('Windows disk-full errors count as no space left', () {
    for (final int code in <int>[28, 112, 39]) {
      expect(
        isNoSpaceLeft(_failure(code), platform: TargetPlatform.windows),
        isTrue,
        reason: 'code $code on Windows',
      );
    }
    expect(
      isNoSpaceLeft(_failure(5), platform: TargetPlatform.windows),
      isFalse,
    );
    expect(
      isNoSpaceLeft(_failure(28), platform: TargetPlatform.android),
      isTrue,
    );
    expect(
      isNoSpaceLeft(_failure(39), platform: TargetPlatform.android),
      isFalse,
    );
    expect(
      isNoSpaceLeft(_failure(112), platform: TargetPlatform.android),
      isFalse,
    );
    expect(
      isNoSpaceLeft(_failure(112), platform: TargetPlatform.macOS),
      isFalse,
    );
  });
}
