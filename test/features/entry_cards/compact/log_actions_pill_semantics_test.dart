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

  testWidgets('the card frame keeps its long press and custom actions', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    int edits = 0;
    int deletes = 0;
    int longPresses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: LogCardFrame(
              onOpen: () {},
              onLongPress: () => longPresses++,
              semanticActions: <CustomSemanticsAction, VoidCallback>{
                const CustomSemanticsAction(label: 'Edit note'): () => edits++,
                const CustomSemanticsAction(label: 'Delete log'): () =>
                    deletes++,
              },
              builder: (BuildContext context, bool hovered) =>
                  const SizedBox(width: 200, height: 100),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final FinderBase<SemanticsNode> frame = find.semantics.byPredicate(
      (SemanticsNode node) =>
          node.getSemanticsData().hasAction(SemanticsAction.customAction) &&
          node.getSemanticsData().hasAction(SemanticsAction.longPress),
    );
    expect(frame, findsOne);
    tester.semantics.customAction(
      frame,
      const CustomSemanticsAction(label: 'Edit note'),
    );
    await tester.pump();
    tester.semantics.customAction(
      frame,
      const CustomSemanticsAction(label: 'Delete log'),
    );
    await tester.pump();
    tester.semantics.longPress(frame);
    await tester.pump();
    expect(edits, 1);
    expect(deletes, 1);
    expect(longPresses, 1);
    handle.dispose();
  });
}
