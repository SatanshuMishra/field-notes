import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'states/media_states.dart';
import 'support/a11y_baseline.dart';
import 'support/a11y_report.dart' show readA11yBaselineLines;
import 'support/a11y_state.dart';

void main() {
  a11ySweepArea(
    area: 'media',
    groupName: 'every media state loads and matches its baseline',
    states: mediaStates,
  );

  test('media baselines hold no open lines', () {
    final List<File> baselines = Directory('$a11yBaselineRoot/media')
        .listSync()
        .whereType<File>()
        .toList();
    expect(baselines, isNotEmpty);
    final List<String> open = <String>[
      for (final File baseline in baselines)
        for (final A11yBaselineLine line in readA11yBaselineLines(baseline))
          if (line.open) '${baseline.uri.pathSegments.last}: ${line.text}',
    ];
    expect(open, isEmpty);
  });
}
