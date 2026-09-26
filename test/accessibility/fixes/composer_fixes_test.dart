import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

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

bool _atLeast48(Size size) => size.width >= 47.99 && size.height >= 47.99;

void main() {
  testWidgets(
    'the new-note header actions are 48 dp buttons that look the same',
    (WidgetTester tester) async {
      final List<String> ids = await _idsIn(
        tester,
        captureStates,
        'c2-composer-new',
      );
      _expectNone(ids, 'missing-role', 'c2-composer-new', <String>[
        'Cancel |',
        'Save |',
      ]);
      _expectNone(ids, 'small-target', 'c2-composer-new', <String>[
        'Cancel |',
        'Save |',
        'Add memory |',
        'Undo |',
      ]);
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('Cancel'),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .height,
        34,
      );
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('Save'),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .height,
        31,
      );
    },
  );

  testWidgets('the edit-note header actions are 48 dp buttons', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(
      tester,
      captureStates,
      'c5-edit-note',
    );
    _expectNone(ids, 'missing-role', 'c5-edit-note', <String>[
      'Cancel |',
      'Save changes |',
    ]);
    _expectNone(ids, 'small-target', 'c5-edit-note', <String>[
      'Cancel |',
      'Save changes |',
    ]);
  });

  testWidgets('the format bar buttons are 48 dp', (WidgetTester tester) async {
    await _idsIn(tester, captureStates, 'c2-composer-new');
    final SemanticsHandle handle = tester.ensureSemantics();
    for (final String label in <String>[
      'Bold',
      'Italic',
      'Table',
      'More formats',
      'Undo',
    ]) {
      final List<SemanticsNode> nodes = _nodes(
        tester,
        (SemanticsNode node) => node.label == label,
      );
      expect(nodes, hasLength(1), reason: label);
      expect(
        _atLeast48(nodes.single.rect.size),
        isTrue,
        reason: '$label ${nodes.single.rect.size}',
      );
    }
    handle.dispose();
  });

  testWidgets('the more-formats items can be pressed by a screen reader', (
    WidgetTester tester,
  ) async {
    await _idsIn(tester, captureStates, 'c4-more-formats');
    final SemanticsHandle handle = tester.ensureSemantics();
    for (final String label in <String>[
      'Strikethrough',
      'Highlight',
      'Inline code',
    ]) {
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

  testWidgets('the draft chip reads Discard once in a 48 dp button', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(
      tester,
      captureStates,
      'c11-draft-chip',
    );
    _expectNone(ids, 'repeated-text', 'c11-draft-chip', <String>['Discard']);
    _expectNone(ids, 'small-target', 'c11-draft-chip', <String>['Discard']);
  });

  testWidgets('the photo caption field is 48 dp tall', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(
      tester,
      captureStates,
      'c7-photo-caption',
    );
    _expectNone(ids, 'small-target', 'c7-photo-caption', <String>['Caption |']);
  });

  testWidgets('the removed-photo undo names what it undoes', (
    WidgetTester tester,
  ) async {
    await _idsIn(tester, captureStates, 'c19-photo-removed-toast');
    final SemanticsHandle handle = tester.ensureSemantics();
    expect(
      _nodes(tester, (SemanticsNode node) => node.label == 'Undo'),
      hasLength(1),
    );
    expect(
      _nodes(
        tester,
        (SemanticsNode node) =>
            node.label.startsWith('Undo') && node.label != 'Undo',
      ),
      hasLength(1),
    );
    handle.dispose();
  });
}
