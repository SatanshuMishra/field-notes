import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the design rules choose a surface from the task', () {
    final File doc = File('docs/design/DESIGN.md');

    expect(doc.existsSync(), isTrue);

    final String text = doc.readAsStringSync();
    for (final String phrase in <String>[
      'Small sheet or popover',
      'Content-sized sheet or panel',
      'Full-screen view',
      'Full-screen task',
      'One-handed reach comes from where the controls sit',
      'rgba(28,22,16,.38)',
    ]) {
      expect(text, contains(phrase));
    }
  });
}
