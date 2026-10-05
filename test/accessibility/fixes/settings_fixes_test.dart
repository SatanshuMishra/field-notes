import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../states/settings_states.dart';
import '../states/capture_states.dart';
import '../support/a11y_rules.dart';
import '../support/a11y_state.dart';

const List<String> _syncActions = <String>[
  'Start syncing',
  'Join my journal',
  'Restore with recovery phrase',
];

const List<String> _mockUpFields = <String>[
  'Server URL',
  'Access token',
  'Recovery passphrase',
];

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

void _expectSyncActionButtons(WidgetTester tester) {
  for (final String name in _syncActions) {
    final List<SemanticsNode> buttons = _nodes(
      tester,
      (SemanticsNode node) =>
          node.getSemanticsData().flagsCollection.isButton &&
          node.label == name,
    );
    expect(buttons, hasLength(1), reason: name);
    final SemanticsData data = buttons.single.getSemanticsData();
    expect(data.flagsCollection.isEnabled, Tristate.isTrue, reason: name);
    expect(data.hasAction(SemanticsAction.tap), isTrue, reason: name);
  }
  for (final String name in _mockUpFields) {
    expect(
      _nodes(tester, (SemanticsNode node) => node.label.contains(name)),
      isEmpty,
      reason: name,
    );
  }
  expect(
    _nodes(
      tester,
      (SemanticsNode node) =>
          node.getSemanticsData().flagsCollection.isTextField,
    ),
    isEmpty,
  );
}

void main() {
  testWidgets(
    'the settings controls are 48 dp buttons that report their state',
    (WidgetTester tester) async {
      final List<String> sync = await _idsIn(
        tester,
        settingsStates,
        'b1-settings',
      );
      for (final String rule in <String>[
        'small-target',
        'missing-role',
        'unlabelled-tap',
      ]) {
        _expectNone(sync, rule, 'b1-settings', _syncActions);
      }
      final List<String> reminders = await _idsIn(
        tester,
        settingsStates,
        'b6-settings-reminders',
      );
      _expectNone(reminders, 'missing-role', 'b6-settings-reminders', <String>[
        '8:30 PM |',
      ]);
      _expectNone(reminders, 'small-target', 'b6-settings-reminders', <String>[
        'Daily reminder |',
        'Sound effects |',
      ]);
      final List<String> journal = await _idsIn(
        tester,
        settingsStates,
        'b7-settings-journal',
      );
      _expectNone(journal, 'missing-role', 'b7-settings-journal', <String>[
        'Sunday |',
      ]);
      _expectNone(journal, 'small-target', 'b7-settings-journal', <String>[
        'Spell check |',
      ]);
    },
  );

  testWidgets(
    'the Mac offers the sync actions as named buttons and no mock-up fields',
    (WidgetTester tester) async {
      await _idsIn(tester, settingsStates, 'b1-settings');
      final SemanticsHandle handle = tester.ensureSemantics();
      _expectSyncActionButtons(tester);
      handle.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'the phone offers the sync actions as named buttons and no mock-up fields',
    (WidgetTester tester) async {
      await _idsIn(tester, settingsStates, 'b1-settings');
      final SemanticsHandle handle = tester.ensureSemantics();
      _expectSyncActionButtons(tester);
      handle.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('the camera switch is a button', (WidgetTester tester) async {
    final List<String> ids = await _idsIn(
      tester,
      captureStates,
      'c15-video-idle',
    );
    _expectNone(ids, 'missing-role', 'c15-video-idle', <String>[
      'Camera / Back camera',
    ]);
    _expectNone(ids, 'small-target', 'c15-video-idle', <String>[
      'Camera / Back camera',
    ]);
  });
}
