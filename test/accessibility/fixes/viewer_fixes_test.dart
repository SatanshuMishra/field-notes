import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

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

bool _atLeast48(Size size) => size.width >= 47.99 && size.height >= 47.99;

void main() {
  testWidgets('the viewer steps can be pressed and are 48 dp', (
    WidgetTester tester,
  ) async {
    await _idsIn(tester, viewerStates, 'd15-viewer-middle-entry');
    final SemanticsHandle handle = tester.ensureSemantics();
    for (final String label in <String>['Earlier log', 'Later log']) {
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
  });

  testWidgets('the viewer header buttons are 48 dp', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(
      tester,
      viewerStates,
      'd1-viewer-todos',
    );
    _expectNone(ids, 'small-target', 'd1-viewer-todos', <String>[
      'Close |',
      'Edit note |',
      'Delete entry |',
    ]);
  });

  testWidgets('the video surface is a named button or silent', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(
      tester,
      viewerStates,
      'd4-viewer-video',
    );
    expect(
      ids.where(
        (String id) =>
            id.startsWith('missing-role | ') ||
            id.startsWith('unlabelled-tap | '),
      ),
      isEmpty,
      reason: '$ids',
    );
  });
}
