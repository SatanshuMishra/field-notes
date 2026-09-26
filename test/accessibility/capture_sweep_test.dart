import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'states/capture_states.dart';
import 'support/a11y_state.dart';

void main() {
  a11ySweepArea(
    area: 'capture',
    groupName: 'every capture state loads and matches its baseline',
    states: captureStates,
  );

  test('the capture baseline records the known composer problems', () {
    final List<String> lines = File(
      'test/accessibility/baselines/capture.txt',
    ).readAsLinesSync();
    for (final String prefix in const <String>[
      'missing-role | c2-composer-new | Cancel | ',
      'missing-role | c2-composer-new | Save | ',
      'unlabelled-tap | c2-composer-new | <unlabelled> | ',
    ]) {
      expect(lines, anyElement(startsWith(prefix)));
    }
  });
}
