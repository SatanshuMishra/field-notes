import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'states/settings_states.dart';
import 'support/a11y_state.dart';

void main() {
  a11ySweepArea(
    area: 'settings',
    groupName: 'every settings state loads and matches its baseline',
    states: settingsStates,
  );

  test('settings baselines hold no open lines', () {
    final List<String> open = <String>[
      for (final File file in Directory(
        'test/accessibility/baselines/settings',
      ).listSync().whereType<File>())
        for (final String line in file.readAsLinesSync())
          if (line.substring(line.lastIndexOf(' # ') + 1).startsWith('# open'))
            '${file.path}: $line',
    ];
    expect(open, isEmpty, reason: open.join('\n'));
  });
}
