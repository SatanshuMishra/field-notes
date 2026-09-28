import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

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
  testWidgets('This week can be pressed and is 48 dp', (
    WidgetTester tester,
  ) async {
    await _idsIn(tester, shellStates, 'a11-calendar-next-month');
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<SemanticsNode> nodes = _nodes(
      tester,
      (SemanticsNode node) => node.label == 'This week',
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

  testWidgets('every calendar day and weekday is read on its own', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(
      tester,
      shellStates,
      'a11-calendar-next-month',
    );
    _expectNone(ids, 'repeated-text', 'a11-calendar-next-month', <String>['']);
    final SemanticsHandle handle = tester.ensureSemantics();
    expect(
      _nodes(
        tester,
        (SemanticsNode node) =>
            node.label
                .split('\n')
                .where((String line) => line.startsWith('Day '))
                .length >
            1,
      ),
      isEmpty,
    );
    expect(
      _nodes(tester, (SemanticsNode node) => node.label.contains('Monday')),
      isNotEmpty,
    );
    handle.dispose();
  });

  testWidgets('the calendar controls are 48 dp', (WidgetTester tester) async {
    final List<String> ids = await _idsIn(
      tester,
      shellStates,
      'a4-calendar-month',
    );
    expect(
      ids.where((String id) => id.startsWith('small-target | ')),
      isEmpty,
      reason: '$ids',
    );
  });

  testWidgets('the month picker hides the calendar and names its scrim', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(
      tester,
      shellStates,
      'a5-calendar-picker',
    );
    _expectNone(ids, 'unlabelled-tap', 'a5-calendar-picker', <String>['']);
    _expectNone(ids, 'missing-role', 'a5-calendar-picker', <String>[
      '<unlabelled>',
    ]);
    expect(
      ids.where((String id) => id.startsWith('small-target | ')),
      isEmpty,
      reason: '$ids',
    );
    final SemanticsHandle handle = tester.ensureSemantics();
    expect(
      _nodes(tester, (SemanticsNode node) => node.label.startsWith('Day 10')),
      isEmpty,
    );
    handle.dispose();
  });
}
