import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'states/sync_states.dart';
import 'support/a11y_state.dart';

void main() {
  a11ySweepArea(
    area: 'sync',
    groupName: 'every sync state loads and matches its baseline',
    states: syncStates,
  );

  test('sync baselines hold no open lines', () {
    final List<String> open = <String>[
      for (final File file in Directory(
        'test/accessibility/baselines/sync',
      ).listSync().whereType<File>())
        for (final String line in file.readAsLinesSync())
          if (line.substring(line.lastIndexOf(' # ') + 1).startsWith('# open'))
            '${file.path}: $line',
    ];
    expect(open, isEmpty, reason: open.join('\n'));
  });
}
