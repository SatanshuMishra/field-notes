import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android main manifest permissions', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    const requiredPermissions = <String>[
      'android.permission.CAMERA',
      'android.permission.RECORD_AUDIO',
      'android.permission.READ_MEDIA_IMAGES',
      'android.permission.READ_MEDIA_VIDEO',
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.RECEIVE_BOOT_COMPLETED',
      'android.permission.SCHEDULE_EXACT_ALARM',
      'android.permission.USE_EXACT_ALARM',
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

    test('caps legacy external-storage read at API 32', () {
      final pattern = RegExp(
        '<uses-permission\\s+android:name="android.permission.READ_EXTERNAL_STORAGE"'
        '\\s+android:maxSdkVersion="32"\\s*/>',
      );
      expect(pattern.hasMatch(manifest), isTrue);
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
