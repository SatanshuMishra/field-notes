import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../states/capture_states.dart';
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
  testWidgets('the note editor field has a name and no unnamed gesture node', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(
      tester,
      captureStates,
      'c2-composer-new',
    );
    _expectNone(ids, 'unlabelled-tap', 'c2-composer-new', <String>[
      '<unlabelled>',
    ]);
    _expectNone(ids, 'missing-role', 'c2-composer-new', <String>[
      '<unlabelled>',
    ]);
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<SemanticsNode> fields = _nodes(
      tester,
      (SemanticsNode node) =>
          node.getSemanticsData().flagsCollection.isTextField,
    );
    expect(fields, isNotEmpty);
    for (final SemanticsNode field in fields) {
      expect(field.label.trim(), isNotEmpty);
    }
    handle.dispose();
  });

  testWidgets('the note reader has no unnamed gesture node', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(
      tester,
      viewerStates,
      'd2-viewer-photo',
    );
    _expectNone(ids, 'unlabelled-tap', 'd2-viewer-photo', <String>[
      '<unlabelled>',
    ]);
    _expectNone(ids, 'missing-role', 'd2-viewer-photo', <String>[
      '<unlabelled>',
    ]);
  });

  testWidgets('a to-do is read once', (WidgetTester tester) async {
    final List<String> ids = await _idsIn(
      tester,
      viewerStates,
      'd1-viewer-todos',
    );
    _expectNone(ids, 'unlabelled-tap', 'd1-viewer-todos', <String>[
      '<unlabelled>',
    ]);
    final SemanticsHandle handle = tester.ensureSemantics();
    expect(
      _nodes(
        tester,
        (SemanticsNode node) => node.label.contains('call the ferry office'),
      ),
      hasLength(1),
    );
    expect(
      _nodes(
        tester,
        (SemanticsNode node) =>
            node.label.contains('☑') || node.label.contains('☐'),
      ),
      isEmpty,
    );
    handle.dispose();
  });
}
