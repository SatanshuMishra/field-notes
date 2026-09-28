import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/entry_cards/compact/log_actions_pill.dart';

void main() {
  testWidgets('every tappable node in the pill has a label', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    int edits = 0;
    int deletes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: LogActionsPill(
              onEdit: () => edits++,
              onDelete: () => deletes++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.semantics.byPredicate(
        (SemanticsNode node) =>
            node.getSemanticsData().hasAction(SemanticsAction.tap) &&
            node.label.isEmpty,
      ),
      findsNothing,
    );
    tester.semantics.tap(find.semantics.byLabel('Edit note'));
    tester.semantics.tap(find.semantics.byLabel('Delete entry'));
    await tester.pump();
    expect(edits, 1);
    expect(deletes, 1);
    handle.dispose();
  });

  testWidgets('the card reveal keeps its long press and custom actions', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    int edits = 0;
    int deletes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: LogActionsReveal(
              onEdit: () => edits++,
              onDelete: () => deletes++,
              child: const SizedBox(width: 200, height: 100),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final FinderBase<SemanticsNode> reveal = find.semantics.byPredicate(
      (SemanticsNode node) =>
          node.getSemanticsData().hasAction(SemanticsAction.customAction) &&
          node.getSemanticsData().hasAction(SemanticsAction.longPress),
    );
    expect(reveal, findsOne);
    tester.semantics.customAction(
      reveal,
      const CustomSemanticsAction(label: 'Edit note'),
    );
    await tester.pump();
    tester.semantics.customAction(
      reveal,
      const CustomSemanticsAction(label: 'Delete entry'),
    );
    await tester.pump();
    expect(edits, 1);
    expect(deletes, 1);
    handle.dispose();
  });
}
