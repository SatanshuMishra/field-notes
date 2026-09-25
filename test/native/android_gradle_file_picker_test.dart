import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android Gradle file_picker Kotlin plugin', () {
    final buildScript = File('android/build.gradle.kts').readAsStringSync();

    test('the file_picker subproject gets the Kotlin Android plugin', () {
      final pattern = RegExp(
        r'subprojects\s*\{[^}]*name\s*==\s*"file_picker"[^}]*'
        r'plugins\.withId\(\s*"com\.android\.library"\s*\)\s*\{[^}]*'
        r'apply\(\s*plugin\s*=\s*"org\.jetbrains\.kotlin\.android"\s*\)',
        dotAll: true,
      );
      expect(
        pattern.hasMatch(buildScript),
        isTrue,
        reason:
            'android/build.gradle.kts must apply org.jetbrains.kotlin.android '
            'to the file_picker subproject once com.android.library is applied',
      );
    });
  });
}
