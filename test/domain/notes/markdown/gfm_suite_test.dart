import 'package:flutter_test/flutter_test.dart';

import 'support/html_to_tree.dart';

void main() {
  final Map<String, Object?> manifest = loadManifest();
  final Map<int, SpecExample> gfm = <int, SpecExample>{
    for (final SpecExample e in loadSpecExamples('gfm-0.29-gfm.json'))
      e.number: e,
  };
  final Map<int, Exclusion> excluded = <int, Exclusion>{
    for (final Exclusion e in manifestExclusions(manifest, 'gfm')) e.number: e,
  };

  List<String> failuresOf(List<int> numbers) => <String>[
    for (final int number in numbers)
      if (!excluded.containsKey(number))
        ?exampleFailure(gfm[number]!, tables: true),
  ];

  test('gfm task list and strikethrough examples pass except manifest '
      'exclusions', () {
    for (final int number in <int>[279, 280]) {
      expect(gfm[number]!.section, 'Task list items (extension)');
    }
    for (final int number in <int>[491, 492, 493]) {
      expect(gfm[number]!.section, 'Strikethrough (extension)');
    }
    expect(excluded[491]?.reason, 'deviation');
    expect(excluded[491]?.rule, 'G1');
    final List<String> failures = failuresOf(<int>[279, 280, 491, 492, 493]);
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('gfm table examples pass', () {
    final List<int> tables = <int>[for (int n = 198; n <= 205; n++) n];
    for (final int number in tables) {
      expect(gfm[number]!.section, 'Tables (extension)');
      expect(excluded.containsKey(number), isFalse, reason: '$number');
    }
    final List<String> failures = failuresOf(tables);
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
