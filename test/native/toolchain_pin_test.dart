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

Map<String, String> _jobs(String workflow) {
  final String body = workflow.substring(workflow.indexOf('\njobs:\n') + 7);
  final List<RegExpMatch> headers = RegExp(
    r'^  ([\w-]+):$',
    multiLine: true,
  ).allMatches(body).toList();
  return <String, String>{
    for (int index = 0; index < headers.length; index++)
      headers[index].group(1)!: body.substring(
        headers[index].end,
        index + 1 < headers.length ? headers[index + 1].start : body.length,
      ),
  };
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

    test('the release workflow builds with Flutter 3.47.5', () {
      final Map<String, String> jobs = _jobs(
        File('.github/workflows/release.yml').readAsStringSync(),
      );
      final Map<String, String> builds = <String, String>{
        for (final MapEntry<String, String> job in jobs.entries)
          if (job.value.contains('subosito/flutter-action')) job.key: job.value,
      };

      expect(builds.keys.toSet(), <String>{'macos', 'windows', 'android'});
      for (final MapEntry<String, String> build in builds.entries) {
        expect(
          "flutter-version: '3.47.5'".allMatches(build.value),
          hasLength(1),
          reason: 'the ${build.key} job must pin Flutter 3.47.5',
        );
        expect(
          'flutter-version:'.allMatches(build.value),
          hasLength(1),
          reason: 'the ${build.key} job must pin one Flutter version',
        );
      }
    });
  });
}
