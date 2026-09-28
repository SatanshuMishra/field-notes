import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../states/viewer_states.dart';
import '../states/shell_states.dart';
import '../support/a11y_rules.dart';
import '../support/a11y_state.dart';

Future<List<String>> _idsIn(
  WidgetTester tester,
  List<A11yState> states,
  String id,
) async {
  final A11yStateResult result = await runA11yState(
    tester,
    states.singleWhere((A11yState state) => state.id == id),
  );
  return switch (result) {
    A11yLoaded(:final List<A11yFinding> findings) => <String>[
      for (final A11yFinding finding in findings) finding.id,
    ],
    A11yNotLoaded(:final String message) => throw TestFailure(message),
  };
}

void _expectNone(
  List<String> ids,
  String rule,
  String state,
  List<String> labels,
) {
  for (final String label in labels) {
    final String prefix = '$rule | $state | $label';
    expect(
      ids.where((String id) => id.startsWith(prefix)),
      isEmpty,
      reason: prefix,
    );
  }
}

List<SemanticsNode> _nodes(
  WidgetTester tester,
  bool Function(SemanticsNode node) test,
) => find.semantics.byPredicate(test).evaluate().toList();

bool _atLeast48(Size size) => size.width >= 47.99 && size.height >= 47.99;

void main() {
  testWidgets('the day sheet close can be pressed and is 48 dp', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(tester, viewerStates, 'd8-day-empty');
    _expectNone(ids, 'small-target', 'd8-day-empty', <String>[
      'Add a note |',
      'Close |',
    ]);
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<SemanticsNode> nodes = _nodes(
      tester,
      (SemanticsNode node) => node.label == 'Close',
    );
    expect(nodes, hasLength(1));
    expect(
      nodes.single.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(
      _atLeast48(nodes.single.rect.size),
      isTrue,
      reason: '${nodes.single.rect.size}',
    );
    handle.dispose();
  });

  testWidgets('the mood banner names the mood once', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(tester, viewerStates, 'd12-mood-set');
    _expectNone(ids, 'small-target', 'd12-mood-set', <String>['change |']);
    final SemanticsHandle handle = tester.ensureSemantics();
    expect(
      _nodes(tester, (SemanticsNode node) => node.label.contains('Calm')),
      hasLength(1),
    );
    handle.dispose();
  });

  testWidgets('a search result reads each part once', (
    WidgetTester tester,
  ) async {
    await _idsIn(tester, shellStates, 'a9-search-results');
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<SemanticsNode> results = _nodes(
      tester,
      (SemanticsNode node) =>
          node.getSemanticsData().flagsCollection.isButton &&
          node.label.contains('entr'),
    );
    expect(results, isNotEmpty);
    for (final SemanticsNode result in results) {
      final List<String> parts = <String>[
        for (final String line in result.label.split('\n'))
          for (final String part in line.split(', '))
            if (part.trim().isNotEmpty) part.trim(),
      ];
      expect(parts.toSet(), hasLength(parts.length), reason: result.label);
      expect(
        result.getSemanticsData().flagsCollection.isImage,
        isFalse,
        reason: result.label,
      );
    }
    handle.dispose();
  });
}
