import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<String> _baselineLines() => <String>[
  for (final String area in <String>['shell', 'settings', 'capture', 'viewer'])
    ...File('test/accessibility/baselines/$area.txt').readAsLinesSync(),
];

void main() {
  test('the corrected sweep records the problems it used to miss', () {
    final List<String> lines = _baselineLines();
    for (final String prefix in <String>[
      'inert-button | c4-more-formats | Strikethrough | ',
      'inert-button | d15-viewer-middle-entry | Earlier log | ',
      'inert-button | d15-viewer-middle-entry | Later log | ',
      'inert-button | a11-calendar-next-month | This week | ',
      'inert-button | d8-day-empty | Close | ',
      'small-target | c2-composer-new | Bold | ',
    ]) {
      expect(lines, anyElement(startsWith(prefix)), reason: prefix);
    }
  });
}
