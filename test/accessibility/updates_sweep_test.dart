import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'states/updates_states.dart';
import 'support/a11y_state.dart';

void main() {
  a11ySweepArea(
    area: 'updates',
    groupName: 'every updates state loads and matches its baseline',
    states: updatesStates,
  );

  test('updates baselines hold no open lines', () {
    final List<String> open = <String>[
      for (final File file in Directory(
        'test/accessibility/baselines/updates',
      ).listSync().whereType<File>())
        for (final String line in file.readAsLinesSync())
          if (line.substring(line.lastIndexOf(' # ') + 1).startsWith('# open'))
            '${file.path}: $line',
    ];
    expect(open, isEmpty, reason: open.join('\n'));
  });
}
