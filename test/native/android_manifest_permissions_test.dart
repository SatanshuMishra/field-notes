import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android main manifest permissions', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    const requiredPermissions = <String>[
      'android.permission.CAMERA',
      'android.permission.RECORD_AUDIO',
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.RECEIVE_BOOT_COMPLETED',
      'android.permission.SCHEDULE_EXACT_ALARM',
    ];

    const playRestrictedPermissions = <String>[
      'android.permission.USE_EXACT_ALARM',
      'android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
      'android.permission.READ_MEDIA_IMAGES',
      'android.permission.READ_MEDIA_VIDEO',
      'android.permission.READ_EXTERNAL_STORAGE',
    ];

    for (final permission in requiredPermissions) {
      test('declares $permission', () {
        final pattern = RegExp(
          '<uses-permission\\s+android:name="${RegExp.escape(permission)}"',
        );
        expect(
          pattern.hasMatch(manifest),
          isTrue,
          reason: 'AndroidManifest.xml must declare $permission',
        );
      });
    }

    for (final permission in playRestrictedPermissions) {
      test('removes $permission, which Google Play restricts', () {
        final declared = RegExp(
          '<uses-permission\\s+android:name="${RegExp.escape(permission)}"'
          '(?![^>]*tools:node="remove")',
        );
        final removed = RegExp(
          '<uses-permission\\s+android:name="${RegExp.escape(permission)}"'
          '\\s+tools:node="remove"\\s*/>',
        );
        expect(declared.hasMatch(manifest), isFalse);
        expect(
          removed.hasMatch(manifest),
          isTrue,
          reason: 'a plugin must not merge $permission back in',
        );
      });
    }

    test('the manifest declares the tools namespace for removals', () {
      expect(
        manifest,
        contains('xmlns:tools="http://schemas.android.com/tools"'),
      );
    });

    test('permissions are declared outside the application element', () {
      final firstPermIndex = manifest.indexOf('<uses-permission');
      final appIndex = manifest.indexOf('<application');
      expect(firstPermIndex, greaterThanOrEqualTo(0));
      expect(appIndex, greaterThanOrEqualTo(0));
      expect(firstPermIndex, lessThan(appIndex));
    });
  });
}
