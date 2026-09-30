import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _environmentBlock(String pubspec) {
  final RegExpMatch? match = RegExp(
    r'^environment:\n((?:[ \t]+.*\n?)+)',
    multiLine: true,
  ).firstMatch(pubspec);
  expect(match, isNotNull, reason: 'pubspec.yaml must declare environment:');
  return match!.group(1)!;
}

void main() {
  group('toolchain pin', () {
    test('the project requires Flutter 3.47.5 and Dart 3.13.4', () {
      final String environment = _environmentBlock(
        File('pubspec.yaml').readAsStringSync(),
      );

      expect(environment, contains('sdk: ^3.13.4'));
      expect(environment, contains("flutter: '>=3.47.5'"));
    });

    test('CI builds the goldens with Flutter 3.47.5', () {
      final String workflow = File('.github/workflows/goldens.yml')
          .readAsStringSync();

      expect(workflow, contains("flutter-version: '3.47.5'"));
    });
  });
}
