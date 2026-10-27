import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'states/shell_states.dart';
import 'support/a11y_state.dart';

const String _shellBaselines = 'test/accessibility/baselines/shell';

String _reasonOf(String line) {
  final int at = line.lastIndexOf(' # ');
  return at < 0 ? '' : line.substring(at + 1);
}

void main() {
  a11ySweepArea(
    area: 'shell',
    groupName: 'every shell state loads and matches its baseline',
    states: shellStates,
  );

  test('shell baselines hold no open lines', () {
    final List<File> baselines = <File>[
      for (final FileSystemEntity entity in Directory(
        _shellBaselines,
      ).listSync())
        if (entity is File && entity.path.endsWith('.txt')) entity,
    ];
    expect(baselines, isNotEmpty);
    final List<String> open = <String>[
      for (final File baseline in baselines)
        for (final String line in baseline.readAsLinesSync())
          if (_reasonOf(line).startsWith('# open')) '${baseline.path}: $line',
    ];
    expect(open, isEmpty, reason: open.join('\n'));
  });
}
