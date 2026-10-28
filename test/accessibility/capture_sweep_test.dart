import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'states/capture_states.dart';
import 'support/a11y_report.dart';
import 'support/a11y_state.dart';

void main() {
  a11ySweepArea(
    area: 'capture',
    groupName: 'every capture state loads and matches its baseline',
    states: captureStates,
  );

  test('capture baselines hold no open lines', () {
    final List<File> baselines = <File>[
      for (final FileSystemEntity entity in Directory(
        '$a11yBaselineRoot/capture',
      ).listSync())
        if (entity is File && entity.path.endsWith('.txt')) entity,
    ];
    expect(baselines, isNotEmpty);
    final List<String> open = <String>[
      for (final File baseline in baselines)
        for (final A11yBaselineLine line in readA11yBaselineLines(baseline))
          if ('# ${line.reason}'.startsWith('# open'))
            '${baseline.path}: ${line.text}',
    ];
    expect(open, isEmpty);
  });
}
