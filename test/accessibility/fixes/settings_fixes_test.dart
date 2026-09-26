import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../states/settings_states.dart';
import '../states/capture_states.dart';
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
  testWidgets(
    'the settings controls are 48 dp buttons that report their state',
    (WidgetTester tester) async {
      final List<String> ids = await _idsIn(
        tester,
        settingsStates,
        'b1-settings',
      );
      _expectNone(ids, 'missing-role', 'b1-settings', <String>[
        '20:30 |',
        'Sunday |',
      ]);
      _expectNone(ids, 'missing-state', 'b1-settings', <String>[
        'On this device',
      ]);
      _expectNone(ids, 'small-target', 'b1-settings', <String>[
        'Daily reminder |',
        'Sound effects |',
        'Spell check |',
      ]);
    },
  );

  testWidgets('the disabled sync fields are named and marked disabled', (
    WidgetTester tester,
  ) async {
    await _idsIn(tester, settingsStates, 'b1-settings');
    final SemanticsHandle handle = tester.ensureSemantics();
    for (final String name in <String>[
      'Server URL',
      'Access token',
      'Recovery passphrase',
    ]) {
      final List<SemanticsNode> fields = _nodes(
        tester,
        (SemanticsNode node) =>
            node.getSemanticsData().flagsCollection.isTextField &&
            node.label.contains(name),
      );
      expect(fields, hasLength(1), reason: name);
      final SemanticsData data = fields.single.getSemanticsData();
      expect(data.flagsCollection.isEnabled, Tristate.isFalse, reason: name);
      expect(data.hasAction(SemanticsAction.tap), isFalse, reason: name);
    }
    handle.dispose();
  });

  testWidgets('the camera switch is a button', (WidgetTester tester) async {
    final List<String> ids = await _idsIn(
      tester,
      captureStates,
      'c15-video-idle',
    );
    _expectNone(ids, 'missing-role', 'c15-video-idle', <String>['Back camera']);
    _expectNone(ids, 'small-target', 'c15-video-idle', <String>['Back camera']);
  });
}
