import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('macOS Info.plist permission purpose strings', () {
    final plist = File('macos/Runner/Info.plist').readAsStringSync();

    const requiredKeys = <String>[
      'NSCameraUsageDescription',
      'NSMicrophoneUsageDescription',
      'NSPhotoLibraryUsageDescription',
    ];

    for (final key in requiredKeys) {
      test('$key is declared with a non-empty explanation', () {
        final pattern = RegExp(
          '<key>${RegExp.escape(key)}</key>\\s*<string>(.+?)</string>',
          dotAll: true,
        );
        final match = pattern.firstMatch(plist);
        expect(match, isNotNull,
            reason: '$key must be present and followed by a <string>');
        expect(match!.group(1)!.trim(), isNotEmpty,
            reason: '$key must not be a blank prompt');
      });
    }
  });
}
