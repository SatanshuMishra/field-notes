import 'package:flutter_test/flutter_test.dart';

import 'states/settings_states.dart';
import 'support/a11y_rules.dart';
import 'support/a11y_state.dart';

const List<String> _aboutStates = <String>[
  'b9-settings-about',
  'b10-settings-about-phone',
];

const Set<String> _modalBarrierFindings = <String>{
  'missing-role | b4-select-open | Dismiss | <root>',
  'missing-role | b5-delete-all-dialog | Dismiss | <root>',
};

A11yState _state(String id) {
  for (final A11yState state in settingsStates) {
    if (state.id == id) {
      return state;
    }
  }
  throw TestFailure('$id is not one of the settings states');
}

Future<List<A11yFinding>> _findings(
  WidgetTester tester,
  A11yState state,
) async {
  final A11yStateResult result = await runA11yState(tester, state);
  return switch (result) {
    A11yLoaded(:final List<A11yFinding> findings) => findings,
    A11yNotLoaded(:final String message) => throw TestFailure(message),
  };
}

void main() {
  testWidgets('the About states have no accessibility findings', (
    WidgetTester tester,
  ) async {
    final List<String> offending = <String>[];
    for (final String id in _aboutStates) {
      final List<A11yFinding> findings = await _findings(tester, _state(id));
      offending.addAll(<String>[
        for (final A11yFinding finding in findings) finding.id,
      ]);
    }
    expect(
      offending,
      isEmpty,
      reason: 'the About states have findings:\n${offending.join('\n')}',
    );
  });

  testWidgets('the rebuilt settings add no accessibility findings', (
    WidgetTester tester,
  ) async {
    final List<String> offending = <String>[];
    for (final A11yState state in settingsStates) {
      final List<A11yFinding> findings = await _findings(tester, state);
      offending.addAll(<String>[
        for (final A11yFinding finding in findings)
          if (!_modalBarrierFindings.contains(finding.id)) finding.id,
      ]);
    }
    expect(
      offending,
      isEmpty,
      reason:
          'settings findings beyond the two modal barriers:\n'
          '${offending.join('\n')}',
    );
  });
}
