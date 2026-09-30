import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android turns Impeller on and requires Android 10', () {
    final String manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final String gradle = File('android/app/build.gradle.kts')
        .readAsStringSync();

    final RegExp enableImpeller = RegExp(
      r'<meta-data\s+android:name="io\.flutter\.embedding\.android\.EnableImpeller"'
      r'\s+android:value="true"\s*/>',
    );
    expect(enableImpeller.hasMatch(manifest), isTrue);
    expect(gradle, contains('minSdk = 29'));
    expect(gradle, isNot(contains('minSdk = flutter.minSdkVersion')));
  });

  test('macOS turns Impeller on', () {
    final String plist = File('macos/Runner/Info.plist').readAsStringSync();

    final RegExp enableImpeller = RegExp(
      r'<key>FLTEnableImpeller</key>\s*<true/>',
    );
    expect(enableImpeller.hasMatch(plist), isTrue);
  });
}
