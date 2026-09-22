import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the goldens workflow runs for every path the note goldens render from',
      () {
    final String workflow =
        File('.github/workflows/goldens.yml').readAsStringSync();
    final List<String> lines =
        workflow.split('\n').map((String line) => line.trim()).toList();

    const List<String> requiredGlobs = <String>[
      'lib/design/**',
      'test/design/goldens/**',
      'assets/fonts/**',
      'pubspec.yaml',
      '.github/workflows/goldens.yml',
      'lib/domain/notes/**',
      'lib/features/notes/**',
      'lib/features/entry_cards/notes/**',
      'lib/features/entry_cards/media/**',
      'test/features/notes/support/**',
    ];

    for (final String glob in requiredGlobs) {
      expect(
        lines,
        contains("- '$glob'"),
        reason: 'goldens.yml must trigger on changes under $glob',
      );
    }
  });
}
