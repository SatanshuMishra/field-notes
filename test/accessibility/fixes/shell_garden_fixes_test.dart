import 'package:field_notes/features/garden/scene/meadow_stage.dart';
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

void main() {
  testWidgets('the tabs and the settings button are 48 dp', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(
      tester,
      shellStates,
      'a1-today-empty',
    );
    _expectNone(ids, 'small-target', 'a1-today-empty', <String>[
      'Today |',
      'Search |',
      'Settings |',
    ]);
  });

  testWidgets('the garden describes its plot and reads each tally once', (
    WidgetTester tester,
  ) async {
    await _idsIn(tester, shellStates, 'a7-garden-blooms');
    final SemanticsHandle handle = tester.ensureSemantics();
    expect(
      _nodes(tester, (SemanticsNode node) => node.label == '1 Grateful'),
      hasLength(1),
    );
    expect(
      _nodes(tester, (SemanticsNode node) => node.label == 'Grateful'),
      isEmpty,
    );
    final Finder stage = find.byType(MeadowStage);
    final Size meadow = tester.getSize(stage);
    expect(
      _nodes(
        tester,
        (SemanticsNode node) =>
            node.label ==
                meadowStageLabel(tester.widget<MeadowStage>(stage).year) &&
            (node.rect.width - meadow.width).abs() < 1 &&
            (node.rect.height - meadow.height).abs() < 1,
      ),
      isNotEmpty,
    );
    handle.dispose();
  });
}
