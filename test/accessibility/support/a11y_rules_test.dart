import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

Future<List<String>> _idsOf(WidgetTester tester, Widget widget) async =>
    <String>[
      for (final A11yFinding finding in await _findingsOf(
        tester,
        KeyedSubtree(key: _plantedKey, child: widget),
        const <A11yStatefulControl>[],
      ))
        finding.id,
    ];

Widget _button(String? label, double side, {Widget? child}) => Semantics(
  container: true,
  button: true,
  label: label,
  onTap: _noop,
  child: _box(side, side, child),
);

class _InvisibleNode extends SingleChildRenderObjectWidget {
  const _InvisibleNode({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderInvisibleNode();
}

class _RenderInvisibleNode extends RenderProxyBox {
  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
  }

  @override
  void assembleSemanticsNode(
    SemanticsNode node,
    SemanticsConfiguration config,
    Iterable<SemanticsNode> children,
  ) {
    node.updateWith(
      config: config,
      childrenInInversePaintOrder: <SemanticsNode>[
        ...children,
        SemanticsNode()
          ..rect = Rect.zero
          ..updateWith(
            config: SemanticsConfiguration()
              ..isButton = true
              ..label = 'Invisible'
              ..onTap = _noop,
          ),
      ],
    );
  }
}

List<SemanticsNode> _childrenOf(SemanticsNode node) {
  final List<SemanticsNode> children = <SemanticsNode>[];
  node.visitChildren((SemanticsNode child) {
    children.add(child);
    return true;
  });
  return children;
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

  testWidgets('a doubled target is reported on the later node unless only '
      'the earlier one is labelled', (WidgetTester tester) async {
    Widget doubled(String? outer, String? inner) =>
        _button(outer, 64, child: _button(inner, 64));

    expect(await _idsOf(tester, doubled('Outer', 'Inner')), <String>[
      'doubled-target | planted | Inner | Outer',
    ]);
    expect(await _idsOf(tester, doubled(null, null)), <String>[
      'unlabelled-tap | planted | <unlabelled> | <root>',
      'unlabelled-tap | planted | <unlabelled> | <root> #2',
      'doubled-target | planted | <unlabelled> | <root>',
    ]);
    expect(await _idsOf(tester, doubled('Outer', null)), <String>[
      'doubled-target | planted | Outer | <root>',
      'unlabelled-tap | planted | <unlabelled> | Outer',
    ]);
    expect(await _idsOf(tester, doubled(null, 'Inner')), <String>[
      'unlabelled-tap | planted | <unlabelled> | <root>',
      'doubled-target | planted | Inner | <root>',
    ]);
  });

  testWidgets('a repeated ID is numbered from its second occurrence', (
    WidgetTester tester,
  ) async {
    expect(
      await _idsOf(
        tester,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _button(null, 48),
            _button('Close', 24),
            _button(null, 48),
            _button(null, 48),
          ],
        ),
      ),
      <String>[
        'unlabelled-tap | planted | <unlabelled> | <root>',
        'small-target | planted | Close | <root>',
        'unlabelled-tap | planted | <unlabelled> | <root> #2',
        'unlabelled-tap | planted | <unlabelled> | <root> #3',
      ],
    );
  });

  testWidgets('merged and hidden nodes are not judged', (
    WidgetTester tester,
  ) async {
    Widget unnamed({required bool hidden}) => Semantics(
      container: true,
      hidden: hidden,
      onTap: _noop,
      child: _box(48, 48),
    );

    expect(await _idsOf(tester, _button('Close', 24)), <String>[
      'small-target | planted | Close | <root>',
    ]);
    expect(
      await _idsOf(
        tester,
        MergeSemantics(
          child: _box(48, 48, Center(child: _button('Close', 24))),
        ),
      ),
      isEmpty,
    );
    expect(await _idsOf(tester, unnamed(hidden: false)), <String>[
      'unlabelled-tap | planted | <unlabelled> | <root>',
      'missing-role | planted | <unlabelled> | <root>',
    ]);
    expect(await _idsOf(tester, unnamed(hidden: true)), isEmpty);
  });

  testWidgets('an invisible node Flutter rejects is not judged', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(child: _InvisibleNode(child: _box(48, 48))),
        ),
      ),
    );
    expect(
      tester.takeException(),
      isA<FlutterError>().having(
        (FlutterError error) => error.toString(),
        'text',
        contains('Invisible SemanticsNodes should not be added to the tree.'),
      ),
    );
    expect(
      <String>[
        for (final SemanticsNode child in _childrenOf(
          tester.getSemantics(find.byType(_InvisibleNode)),
        ))
          if (child.isInvisible) child.label,
      ],
      <String>['Invisible'],
    );
    expect(a11yFindings(tester, state: 'planted'), isEmpty);
    handle.dispose();
  });

  testWidgets('an unlabelled text field is not reported as unlabelled', (
    WidgetTester tester,
  ) async {
    Widget field({required bool textField}) => Semantics(
      container: true,
      textField: textField,
      onTap: _noop,
      child: _box(200, 48),
    );

    expect(await _idsOf(tester, field(textField: true)), isEmpty);
    expect(await _idsOf(tester, field(textField: false)), <String>[
      'unlabelled-tap | planted | <unlabelled> | <root>',
      'missing-role | planted | <unlabelled> | <root>',
    ]);
  });

  testWidgets('repeated text ignores blank lines and keeps letter case', (
    WidgetTester tester,
  ) async {
    Widget labelled(String label) => Semantics(
      container: true,
      button: true,
      label: label,
      onTap: _noop,
      child: _box(200, 48),
    );

    expect(await _idsOf(tester, labelled('Walk\n\nRun\n  \nSit')), isEmpty);
    expect(await _idsOf(tester, labelled('Walk\nwalk')), isEmpty);
    expect(await _idsOf(tester, labelled(' Walk\n\nWalk ')), <String>[
      'repeated-text | planted | Walk / Walk | <root>',
    ]);
  });

  testWidgets('a small button flush against the view is judged', (
    WidgetTester tester,
  ) async {
    final A11yStateResult result = await runA11yState(
      tester,
      A11yState(
        id: 'flush',
        pump: (WidgetTester tester) => tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: KeyedSubtree(
                  key: _plantedKey,
                  child: _button('Today', 40),
                ),
              ),
            ),
          ),
        ),
        proof: <A11yProof>[A11yProof(find.byKey(_plantedKey))],
      ),
    );
    expect(
      switch (result) {
        A11yLoaded(:final List<A11yFinding> findings) => <String>[
          for (final A11yFinding finding in findings) finding.id,
        ],
        A11yNotLoaded(:final String message) => throw TestFailure(message),
      },
      <String>['small-target | flush | Today | <root>'],
    );
  });

  testWidgets(
    'a node several render objects share is judged by their combined bounds',
    (WidgetTester tester) async {
      final List<String> ids = <String>[
        for (final A11yFinding finding in await _findingsOf(
          tester,
          KeyedSubtree(
            key: _plantedKey,
            child: SizedBox(
              width: 200,
              child: ClipRect(
                child: SizedBox(
                  height: 30,
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    maxHeight: 80,
                    child: const TextField(
                      decoration: InputDecoration(labelText: 'Name'),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const <A11yStatefulControl>[],
        ))
          finding.id,
      ];
      expect(ids, isEmpty);
    },
  );

  testWidgets('a node no render object owns is judged by its visible rect', (
    WidgetTester tester,
  ) async {
    final LongPressGestureRecognizer hold = LongPressGestureRecognizer()
      ..onLongPress = _noop;
    addTearDown(hold.dispose);
    final List<String> ids = <String>[
      for (final A11yFinding finding in await _findingsOf(
        tester,
        KeyedSubtree(
          key: _plantedKey,
          child: SizedBox(
            width: 200,
            height: 10,
            child: SingleChildScrollView(
              child: Text.rich(TextSpan(text: 'Hold me', recognizer: hold)),
            ),
          ),
        ),
        const <A11yStatefulControl>[],
      ))
        finding.id,
    ];
    expect(ids, contains('small-target | planted | Hold me | <root>'));
  });

  testWidgets('a node that reaches past its parent is judged by the part a '
      'tap can reach', (WidgetTester tester) async {
    final List<String> ids = <String>[
      for (final A11yFinding finding in await _findingsOf(
        tester,
        KeyedSubtree(
          key: _plantedKey,
          child: Semantics(
            container: true,
            child: _box(
              48,
              20,
              OverflowBox(maxHeight: 48, child: _button('Reach me', 48)),
            ),
          ),
        ),
        const <A11yStatefulControl>[],
      ))
        finding.id,
    ];
    expect(ids, contains('small-target | planted | Reach me | <root>'));
  });
}
