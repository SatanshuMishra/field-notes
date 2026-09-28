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

Future<void> _expectDialogButtons(
  WidgetTester tester,
  List<A11yState> states,
  String state,
  List<String> labels,
) async {
  final List<String> ids = await _idsIn(tester, states, state);
  _expectNone(ids, 'small-target', state, <String>[
    for (final String label in labels) '$label |',
  ]);
}

void main() {
  testWidgets(
    'the discard-note dialog buttons are 48 dp',
    (WidgetTester tester) => _expectDialogButtons(
      tester,
      captureStates,
      'c10-discard-dialog',
      <String>['Keep editing', 'Discard'],
    ),
  );

  testWidgets(
    'the discard-recording dialog buttons are 48 dp',
    (WidgetTester tester) => _expectDialogButtons(
      tester,
      captureStates,
      'c18-discard-recording',
      <String>['Cancel', 'Discard'],
    ),
  );

  testWidgets(
    'the change-mood dialog buttons are 48 dp',
    (WidgetTester tester) => _expectDialogButtons(
      tester,
      viewerStates,
      'd13-change-mood-dialog',
      <String>['Cancel', 'Change mood'],
    ),
  );

  testWidgets(
    'the delete-entry dialog buttons are 48 dp',
    (WidgetTester tester) => _expectDialogButtons(
      tester,
      viewerStates,
      'd14-delete-entry-dialog',
      <String>['Cancel', 'Delete'],
    ),
  );

  testWidgets(
    'the delete-all dialog buttons are 48 dp',
    (WidgetTester tester) => _expectDialogButtons(
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
