import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a11y_rules.dart';
import 'a11y_state.dart';

const Key _plantedKey = ValueKey<String>('planted');

void _noop() {}

Widget _box(double width, double height) =>
    SizedBox(width: width, height: height);

A11yState _planted(
  Widget widget, {
  List<A11yStatefulControl> stateful = const <A11yStatefulControl>[],
}) => A11yState(
  id: 'planted',
  pump: (WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: Center(
          child: KeyedSubtree(key: _plantedKey, child: widget),
        ),
      ),
    ),
  ),
  proof: <A11yProof>[A11yProof(find.byKey(_plantedKey))],
  stateful: stateful,
);

Future<List<String>> _idsOf(WidgetTester tester, Widget widget) async {
  final A11yStateResult result = await runA11yState(tester, _planted(widget));
  return switch (result) {
    A11yLoaded(:final List<A11yFinding> findings) => <String>[
      for (final A11yFinding finding in findings) finding.id,
    ],
    A11yNotLoaded(:final String message) => throw TestFailure(message),
  };
}

bool _hasPrefix(List<String> ids, String prefix) =>
    ids.any((String id) => id.startsWith(prefix));

void main() {
  testWidgets('an enabled button with no tap action is caught as inert', (
    WidgetTester tester,
  ) async {
    final List<String> inert = await _idsOf(
      tester,
      Semantics(
        button: true,
        label: 'Strikethrough',
        excludeSemantics: true,
        child: GestureDetector(onTap: _noop, child: _box(160, 48)),
      ),
    );
    expect(
      _hasPrefix(inert, 'inert-button | planted | Strikethrough | '),
      isTrue,
      reason: '$inert',
    );

    final List<String> pressable = await _idsOf(
      tester,
      Semantics(
        button: true,
        label: 'Strikethrough',
        excludeSemantics: true,
        onTap: _noop,
        child: GestureDetector(onTap: _noop, child: _box(160, 48)),
      ),
    );
    expect(pressable, isEmpty);

    final List<String> disabled = await _idsOf(
      tester,
      Semantics(
        button: true,
        enabled: false,
        label: 'Redo',
        child: _box(48, 48),
      ),
    );
    expect(disabled, isEmpty);
  });

  testWidgets('a small button that fills its scroller is judged', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsOf(
      tester,
      SizedBox(
        width: 300,
        height: 30,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              Semantics(
                button: true,
                label: 'Bold',
                onTap: _noop,
                child: _box(30, 30),
              ),
              _box(255, 30),
              Semantics(
                button: true,
                label: 'Cut off',
                onTap: _noop,
                child: _box(30, 30),
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      _hasPrefix(ids, 'small-target | planted | Bold | '),
      isTrue,
      reason: '$ids',
    );
    expect(
      _hasPrefix(ids, 'small-target | planted | Cut off | '),
      isFalse,
      reason: '$ids',
    );
  });

  testWidgets(
    'a small button cut off by the view is skipped and one shown whole is judged',
    (WidgetTester tester) async {
      final A11yStateResult result = await runA11yState(
        tester,
        A11yState(
          id: 'edges',
          pump: (WidgetTester tester) => tester.pumpWidget(
            MaterialApp(
              home: Material(
                child: Stack(
                  key: _plantedKey,
                  children: <Widget>[
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Semantics(
                        button: true,
                        label: 'Flush',
                        onTap: _noop,
                        child: _box(24, 24),
                      ),
                    ),
                    Positioned(
                      right: -12,
                      bottom: 0,
                      child: Semantics(
                        button: true,
                        label: 'Past the edge',
                        onTap: _noop,
                        child: _box(24, 24),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          proof: <A11yProof>[A11yProof(find.byKey(_plantedKey))],
        ),
      );
      final List<String> ids = switch (result) {
        A11yLoaded(:final List<A11yFinding> findings) => <String>[
          for (final A11yFinding finding in findings) finding.id,
        ],
        A11yNotLoaded(:final String message) => throw TestFailure(message),
      };
      expect(
        _hasPrefix(ids, 'small-target | edges | Flush | '),
        isTrue,
        reason: '$ids',
      );
      expect(
        _hasPrefix(ids, 'small-target | edges | Past the edge | '),
        isFalse,
        reason: '$ids',
      );
    },
  );

  testWidgets('a stateful control that matches nothing fails as not loaded', (
    WidgetTester tester,
  ) async {
    for (final A11yStatefulControl control in <A11yStatefulControl>[
      A11yStatefulControl.finder(
        find.byKey(const ValueKey<String>('never-built')),
        A11yStateKind.toggled,
      ),
      A11yStatefulControl.label('Never named', A11yStateKind.selected),
    ]) {
      final A11yStateResult result = await runA11yState(
        tester,
        _planted(
          Semantics(
            button: true,
            label: 'Present',
            onTap: _noop,
            child: _box(48, 48),
          ),
          stateful: <A11yStatefulControl>[control],
        ),
      );
      expect(result, isA<A11yNotLoaded>());
      expect(
        (result as A11yNotLoaded).message,
        startsWith('planted did not load'),
      );
    }
  });

  testWidgets('a state whose build throws fails as not loaded', (
    WidgetTester tester,
  ) async {
    final A11yStateResult result = await runA11yState(
      tester,
      A11yState(
        id: 'thrower',
        pump: (WidgetTester tester) => tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Column(
                children: <Widget>[
                  const Text('Loaded', key: _plantedKey),
                  Builder(
                    builder: (BuildContext context) =>
                        throw StateError('broken build'),
                  ),
                ],
              ),
            ),
          ),
        ),
        proof: <A11yProof>[A11yProof(find.byKey(_plantedKey))],
      ),
    );
    expect(result, isA<A11yNotLoaded>());
    expect(
      (result as A11yNotLoaded).message,
      startsWith('thrower did not load'),
    );
  });
}
