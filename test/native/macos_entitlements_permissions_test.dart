import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const requiredEntitlements = <String>[
    'com.apple.security.device.camera',
    'com.apple.security.device.audio-input',
    'com.apple.security.personal-information.photos-library',
    'com.apple.security.files.user-selected.read-write',
  ];

  const entitlementFiles = <String>[
    'macos/Runner/DebugProfile.entitlements',
    'macos/Runner/Release.entitlements',
  ];

  for (final path in entitlementFiles) {
    group(path, () {
      final xml = File(path).readAsStringSync();

      test('keeps the app sandbox enabled', () {
        expect(
          xml.contains('<key>com.apple.security.app-sandbox</key>'),
          isTrue,
          reason: '$path must keep the app-sandbox entitlement',
        );
      });

      for (final key in requiredEntitlements) {
        test('grants $key', () {
          final pattern = RegExp(
            '<key>${RegExp.escape(key)}</key>\\s*<true\\s*/>',
          );
          expect(
            pattern.hasMatch(xml),
            isTrue,
            reason: '$path must grant $key with <true/>',
          );
        });
      }
    });
  }
}
