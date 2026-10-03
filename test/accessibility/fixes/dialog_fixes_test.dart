import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../states/capture_states.dart';
import '../states/viewer_states.dart';
import '../states/settings_states.dart';
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

Future<void> _expectConfirmButtons(
  WidgetTester tester,
  List<A11yState> states,
  String state,
  List<String> labels,
) async {
  final List<String> ids = await _idsIn(tester, states, state);
  _expectNone(ids, 'small-target', state, <String>[
    for (final String label in labels) '$label |',
  ]);
  final SemanticsHandle handle = tester.ensureSemantics();
  for (final String label in labels) {
    final List<SemanticsNode> nodes = _nodes(
      tester,
      (SemanticsNode node) => node.label == label,
    );
    expect(nodes, hasLength(1), reason: label);
    expect(
      nodes.single.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
      reason: label,
    );
    expect(
      _atLeast48(nodes.single.rect.size),
      isTrue,
      reason: '$label ${nodes.single.rect.size}',
    );
  }
  handle.dispose();
}

void main() {
  testWidgets(
    'the discard-note confirm sheet buttons are 48 dp',
    (WidgetTester tester) => _expectConfirmButtons(
      tester,
      captureStates,
      'c10-discard-dialog',
      <String>['Keep editing', 'Discard'],
    ),
  );

  testWidgets(
    'the recording let-go panel buttons are 48 dp',
    (WidgetTester tester) => _expectConfirmButtons(
      tester,
      captureStates,
      'c18-discard-recording',
      <String>['Keep going', 'Let it go'],
    ),
  );

  testWidgets(
    'the change-mood confirm sheet buttons are 48 dp',
    (WidgetTester tester) => _expectConfirmButtons(
      tester,
      viewerStates,
      'd13-change-mood-dialog',
      <String>['Cancel', 'Change mood'],
    ),
  );

  testWidgets(
    'the delete-entry confirm sheet buttons are 48 dp',
    (WidgetTester tester) => _expectConfirmButtons(
      tester,
      viewerStates,
      'd14-delete-entry-dialog',
      <String>['Cancel', 'Delete'],
    ),
  );

  testWidgets(
    'the delete-all confirm sheet buttons are 48 dp',
    (WidgetTester tester) => _expectConfirmButtons(
      tester,
      settingsStates,
      'b5-delete-all-dialog',
      <String>['Keep my journal', 'Delete everything'],
    ),
  );

  testWidgets('the settings notice dismiss is 48 dp', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(
      tester,
      settingsStates,
      'b3-settings-notice',
    );
    expect(
      ids.where(
        (String id) =>
            id.startsWith('small-target | b3-settings-notice | ') &&
            id.split(' | ')[2].contains('Dismiss'),
      ),
      isEmpty,
      reason: '$ids',
    );
  });
}
