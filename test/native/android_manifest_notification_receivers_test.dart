import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('B2 scheduled notification receivers', () {
    final String manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    test('declares the scheduled notification receiver', () {
      expect(
        RegExp(
          r'<receiver[^>]*android:name="com\.dexterous\.flutterlocalnotifications\.ScheduledNotificationReceiver"',
        ).hasMatch(manifest),
        isTrue,
      );
    });

    test('declares the boot receiver with boot and package-replaced actions', () {
      final RegExpMatch? boot = RegExp(
        r'<receiver[^>]*android:name="com\.dexterous\.flutterlocalnotifications\.ScheduledNotificationBootReceiver"[\s\S]*?</receiver>',
      ).firstMatch(manifest);
      expect(boot, isNotNull);
      expect(boot!.group(0), contains('android.intent.action.BOOT_COMPLETED'));
      expect(
        boot.group(0),
        contains('android.intent.action.MY_PACKAGE_REPLACED'),
      );
    });
  });
}
