import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android release signing', () {
    final String script = File('android/app/build.gradle.kts')
        .readAsStringSync();

    test('release builds sign with key.properties when it exists', () {
      expect(script, contains('rootProject.file("key.properties")'));
      expect(
        script,
        contains('hasReleaseKey = keystorePropertiesFile.exists()'),
      );
      expect(script, contains('keystoreProperties.load('));

      final RegExp releaseConfig = RegExp(
        r'signingConfigs\s*\{\s*create\("release"\)\s*\{[^}]*if \(hasReleaseKey\)'
        r'[^}]*\}',
        dotAll: true,
      );
      final Match? match = releaseConfig.firstMatch(script);
      expect(match, isNotNull);
      final String block = match!.group(0)!;
      expect(
        block,
        contains('keyAlias = keystoreProperties.getProperty("keyAlias")'),
      );
      expect(
        block,
        contains('keyPassword = keystoreProperties.getProperty("keyPassword")'),
      );
      expect(
        block,
        contains(
          'storeFile = file(keystoreProperties.getProperty("storeFile"))',
        ),
      );
      expect(
        block,
        contains(
          'storePassword = keystoreProperties.getProperty("storePassword")',
        ),
      );

      final RegExp selection = RegExp(
        r'release\s*\{\s*signingConfig\s*=\s*if \(hasReleaseKey\)\s*\{\s*'
        r'signingConfigs\.getByName\("release"\)\s*\}\s*else\s*\{\s*'
        r'signingConfigs\.getByName\("debug"\)\s*\}',
        dotAll: true,
      );
      expect(selection.hasMatch(script), isTrue);
    });
  });
}
