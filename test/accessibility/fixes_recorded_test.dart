import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const Set<String> _frameworkMenuItems = <String>{
  'Cut',
  'Copy',
  'Paste',
  'Select all',
};

bool _accepted(String line) {
  final List<String> parts = line.split(' | ');
  final String rule = parts[0];
  final String label = parts[2];
  return switch (rule) {
    'missing-role' => label.startsWith('Dismiss'),
    'small-target' => _frameworkMenuItems.contains(label),
    _ => false,
  };
}

void main() {
  test('only accepted findings remain in the baselines', () {
    final List<String> lines = <String>[
      for (final String area in <String>[
        'shell',
        'settings',
        'capture',
        'viewer',
      ])
        for (final String line in File(
          'test/accessibility/baselines/$area.txt',
        ).readAsLinesSync())
          if (line.trim().isNotEmpty) line,
    ];
    expect(lines, isNotEmpty);
    expect(lines.where((String line) => !_accepted(line)), isEmpty);
  });
}
