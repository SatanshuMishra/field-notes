import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../states/shell_states.dart';
import '../states/viewer_states.dart';
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
  testWidgets('a feed card is one named button that holds its long press', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(tester, shellStates, 'a2-today-feed');
    _expectNone(ids, 'unlabelled-tap', 'a2-today-feed', <String>[
      '<unlabelled>',
    ]);
    _expectNone(ids, 'missing-role', 'a2-today-feed', <String>['<unlabelled>']);
    _expectNone(ids, 'doubled-target', 'a2-today-feed', <String>['']);
    _expectNone(ids, 'small-target', 'a2-today-feed', <String>['Play |']);
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<SemanticsNode> pressable = _nodes(
      tester,
      (SemanticsNode node) =>
          node.getSemanticsData().hasAction(SemanticsAction.longPress),
    );
    expect(pressable, isNotEmpty);
    for (final SemanticsNode node in pressable) {
      final SemanticsData data = node.getSemanticsData();
      expect(data.label.trim(), isNotEmpty);
      expect(data.flagsCollection.isButton, isTrue, reason: data.label);
      expect(data.hasAction(SemanticsAction.tap), isTrue, reason: data.label);
    }
    handle.dispose();
  });

  testWidgets('photo and video cards are announced as buttons, not images', (
    WidgetTester tester,
  ) async {
    await _idsIn(tester, shellStates, 'a2-today-feed');
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<SemanticsNode> cards = _nodes(
      tester,
      (SemanticsNode node) =>
          node.getSemanticsData().flagsCollection.isButton &&
          node.label.contains('09:30'),
    );
    expect(cards, hasLength(5));
    for (final SemanticsNode card in cards) {
      expect(
        card.getSemanticsData().flagsCollection.isImage,
        isFalse,
        reason: card.label,
      );
    }
    handle.dispose();
  });

  testWidgets('the card actions pill buttons are 48 dp', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(
      tester,
      shellStates,
      'a3-card-actions',
    );
    _expectNone(ids, 'small-target', 'a3-card-actions', <String>[
      'Edit note |',
      'Delete entry |',
    ]);
  });

  testWidgets('a day sheet card is one named button', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(
      tester,
      viewerStates,
      'd7-day-with-entries',
    );
    _expectNone(ids, 'unlabelled-tap', 'd7-day-with-entries', <String>[
      '<unlabelled>',
    ]);
    _expectNone(ids, 'missing-role', 'd7-day-with-entries', <String>[
      '<unlabelled>',
    ]);
  });
}
