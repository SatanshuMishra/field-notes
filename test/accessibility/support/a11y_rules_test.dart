import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a11y_baseline.dart';
import 'a11y_rules.dart';
import 'a11y_state.dart';

const Key _plantedKey = ValueKey<String>('planted');

void _noop() {}

class _Example {
  const _Example({
    required this.name,
    required this.planted,
    required this.prefix,
    required this.fixed,
    this.stateful = const <A11yStatefulControl>[],
  });

  final String name;
  final Widget planted;
  final String prefix;
  final Widget fixed;
  final List<A11yStatefulControl> stateful;
}

Widget _box(double width, double height, [Widget? child]) =>
    SizedBox(width: width, height: height, child: child);

final List<_Example> _examples = <_Example>[
  _Example(
    name: 'unlabelled card button',
    planted: Semantics(
      key: _plantedKey,
      button: true,
      onTap: _noop,
      child: GestureDetector(onTap: _noop, child: _box(200, 80)),
    ),
    prefix: 'unlabelled-tap | planted | <unlabelled> | ',
    fixed: Semantics(
      key: _plantedKey,
      button: true,
      label: 'Open entry',
      onTap: _noop,
      child: _box(200, 80),
    ),
  ),
  _Example(
    name: 'doubled pill button',
    planted: Semantics(
      key: _plantedKey,
      button: true,
      label: 'Edit note',
      onTap: _noop,
      child: GestureDetector(onTap: _noop, child: _box(64, 64)),
    ),
    prefix: 'doubled-target | planted | Edit note | ',
    fixed: Semantics(
      key: _plantedKey,
      button: true,
      label: 'Edit note',
      onTap: _noop,
      child: _box(64, 64),
    ),
  ),
  _Example(
    name: 'repeated prompt label',
    planted: Semantics(
      key: _plantedKey,
      button: true,
      label:
          'How are you feeling today?\nPeony\nHow are you feeling today?\n'
          'tap to plant today\'s bloom',
      onTap: _noop,
      child: _box(300, 64),
    ),
    prefix:
        'repeated-text | planted | How are you feeling today? / Peony / '
        'How are you feeling today? / tap to plant today\'s bloom | ',
    fixed: Semantics(
      key: _plantedKey,
      button: true,
      label: 'How are you feeling today?\ntap to plant today\'s bloom',
      onTap: _noop,
      child: _box(300, 64),
    ),
  ),
  _Example(
    name: 'tappable text with no role',
    planted: GestureDetector(
      key: _plantedKey,
      onTap: _noop,
      child: _box(120, 48, const Text('Cancel')),
    ),
    prefix: 'missing-role | planted | Cancel | ',
    fixed: Semantics(
      key: _plantedKey,
      button: true,
      child: GestureDetector(
        onTap: _noop,
        child: _box(120, 48, const Text('Cancel')),
      ),
    ),
  ),
  _Example(
    name: 'toggle with no state',
    planted: Semantics(
      key: _plantedKey,
      button: true,
      label: 'Daily reminder',
      onTap: _noop,
      child: _box(200, 48),
    ),
    prefix: 'missing-state | planted | Daily reminder | ',
    fixed: Semantics(
      key: _plantedKey,
      button: true,
      toggled: false,
      label: 'Daily reminder',
      onTap: _noop,
      child: _box(200, 48),
    ),
    stateful: <A11yStatefulControl>[
      A11yStatefulControl.finder(
        find.byKey(_plantedKey),
        A11yStateKind.toggled,
      ),
    ],
  ),
  _Example(
    name: 'toggle with no state, listed by label',
    planted: Semantics(
      key: _plantedKey,
      button: true,
      label: 'Daily reminder',
      onTap: _noop,
      child: _box(200, 48),
    ),
    prefix: 'missing-state | planted | Daily reminder | ',
    fixed: Semantics(
      key: _plantedKey,
      button: true,
      toggled: false,
      label: 'Daily reminder',
      onTap: _noop,
      child: _box(200, 48),
    ),
    stateful: const <A11yStatefulControl>[
      A11yStatefulControl.label('Daily reminder', A11yStateKind.toggled),
    ],
  ),
  _Example(
    name: 'tiny icon',
    planted: Semantics(
      key: _plantedKey,
      button: true,
      label: 'Close',
      onTap: _noop,
      child: _box(24, 24),
    ),
    prefix: 'small-target | planted | Close | ',
    fixed: Semantics(
      key: _plantedKey,
      button: true,
      label: 'Close',
      onTap: _noop,
      child: _box(48, 48),
    ),
  ),
];

A11yState _planted(Widget widget, List<A11yStatefulControl> stateful) =>
    A11yState(
      id: 'planted',
      pump: (WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          home: Material(child: Center(child: widget)),
        ),
      ),
      proof: <A11yProof>[A11yProof(find.byKey(_plantedKey))],
      stateful: stateful,
    );

Future<List<A11yFinding>> _findingsOf(
  WidgetTester tester,
  Widget widget,
  List<A11yStatefulControl> stateful,
) async {
  final A11yStateResult result = await runA11yState(
    tester,
    _planted(widget, stateful),
  );
  return switch (result) {
    A11yLoaded(:final List<A11yFinding> findings) => findings,
    A11yNotLoaded(:final String message) => throw TestFailure(message),
  };
}

A11yFinding _finding(String rule, String label) => A11yFinding(
  rule: rule,
  state: 'baseline',
  label: label,
  anchor: '',
  rect: const Rect.fromLTWH(10, 20, 30, 40),
);

void main() {
  testWidgets('each known problem is caught by its rule', (
    WidgetTester tester,
  ) async {
    for (final _Example example in _examples) {
      final List<String> ids = <String>[
        for (final A11yFinding finding in await _findingsOf(
          tester,
          example.planted,
          example.stateful,
        ))
          finding.id,
      ];
      expect(
        ids.any((String id) => id.startsWith(example.prefix)),
        isTrue,
        reason: '${example.name}: expected ${example.prefix} in $ids',
      );
    }
  });

  testWidgets('a widget without problems has no findings', (
    WidgetTester tester,
  ) async {
    for (final _Example example in _examples) {
      final List<String> ids = <String>[
        for (final A11yFinding finding in await _findingsOf(
          tester,
          example.fixed,
          example.stateful,
        ))
          finding.id,
      ];
      expect(ids, isEmpty, reason: example.name);
    }
  });

  testWidgets('a state whose key widget is absent fails as not loaded', (
    WidgetTester tester,
  ) async {
    final List<A11yState> states = <A11yState>[
      A11yState(
        id: 'absent-key',
        pump: (WidgetTester tester) => tester.pumpWidget(
          const MaterialApp(
            home: Material(child: Center(child: Text('Loaded'))),
          ),
        ),
        proof: <A11yProof>[
          A11yProof(find.byKey(const ValueKey<String>('never-built'))),
        ],
      ),
      A11yState(
        id: 'too-few',
        pump: (WidgetTester tester) => tester.pumpWidget(
          const MaterialApp(
            home: Material(child: Center(child: Text('Loaded'))),
          ),
        ),
        proof: <A11yProof>[A11yProof(find.text('Loaded'), count: 2)],
      ),
      A11yState(
        id: 'throwing-pump',
        pump: (WidgetTester tester) async {
          throw StateError('the fixture failed');
        },
        proof: <A11yProof>[A11yProof(find.text('Loaded'))],
      ),
    ];
    for (final A11yState state in states) {
      final A11yStateResult result = await runA11yState(tester, state);
      expect(result, isA<A11yNotLoaded>(), reason: state.id);
      expect(
        (result as A11yNotLoaded).message,
        startsWith('${state.id} did not load: '),
      );
    }
  });

  test('the baseline flags new and stale findings', () {
    final Directory directory = Directory.systemTemp.createTempSync(
      'a11y_baseline_',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final String path = '${directory.path}/area.txt';
    final File file = File(path);
    final A11yFinding kept = _finding('missing-role', 'Cancel');
    final A11yFinding added = _finding('unlabelled-tap', '');

    final A11yBaselineResult missing = compareA11yBaseline(path, <A11yFinding>[
      kept,
    ]);
    expect(missing.missing, isTrue);
    expect(missing.matches, isFalse);
    expect(describeA11yBaseline(path, missing), '$path baseline missing');

    file.writeAsStringSync('${kept.id}\n');
    final A11yBaselineResult grown = compareA11yBaseline(path, <A11yFinding>[
      kept,
      added,
    ]);
    expect(grown.missing, isFalse);
    expect(grown.matches, isFalse);
    expect(
      <String>[for (final A11yFinding finding in grown.added) finding.id],
      <String>[added.id],
    );
    expect(grown.stale, isEmpty);
    expect(
      describeA11yBaseline(path, grown),
      allOf(
        contains(added.id),
        contains(a11yRuleDescriptions['unlabelled-tap']),
        contains(added.rect.toString()),
      ),
    );

    const String gone = 'small-target | baseline | Close | <root>';
    file.writeAsStringSync('${kept.id}\n$gone\n');
    final A11yBaselineResult shrunk = compareA11yBaseline(path, <A11yFinding>[
      kept,
    ]);
    expect(shrunk.matches, isFalse);
    expect(shrunk.added, isEmpty);
    expect(shrunk.stale, <String>[gone]);
    expect(describeA11yBaseline(path, shrunk), contains(gone));

    file.writeAsStringSync('${kept.id}\n');
    expect(compareA11yBaseline(path, <A11yFinding>[kept]).matches, isTrue);

    file.writeAsStringSync('  \n${kept.id}\n\t\n');
    expect(compareA11yBaseline(path, <A11yFinding>[kept]).matches, isTrue);

    writeA11yBaseline(path, <A11yFinding>[kept, added]);
    final List<String> sorted = <String>[kept.id, added.id]..sort();
    expect(file.readAsStringSync(), '${sorted.join('\n')}\n');
    expect(
      compareA11yBaseline(path, <A11yFinding>[added, kept]).matches,
      isTrue,
    );
  });
}
