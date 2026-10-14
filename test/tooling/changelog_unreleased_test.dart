import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the unreleased notes list this release\'s changes in plain English', () {
    final String text = File('CHANGELOG.md').readAsStringSync();
    final int start = text.indexOf('## [Unreleased]');
    final int end = text.indexOf('## [1.0.2]');
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final String section = text.substring(start, end);
    final int improved = section.indexOf('### Improved');
    final int fixed = section.indexOf('### Fixed');
    expect(improved, greaterThanOrEqualTo(0));
    expect(fixed, greaterThan(improved));

    List<String> items(String block) => block
        .split('\n')
        .where((String line) => line.startsWith('- '))
        .toList();

    expect(items(section.substring(improved, fixed)), <String>[
      '- A short countdown before recording starts.',
      '- A new live visualiser while you record.',
      '- Voice waveforms now show the shape of your recording.',
    ]);
    expect(items(section.substring(fixed)), <String>[
      '- On Windows, Field Notes no longer closes when you switch back to it while reminders are on.',
      '- Settings now use the same background colours as the rest of the app.',
      '- A voice note in a past day keeps playing when you move the pointer away from it.',
      '- The Restarting Field Notes screen no longer shows a yellow underline under its text.',
    ]);
  });
}
