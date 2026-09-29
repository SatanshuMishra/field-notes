import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/capture/core/draft_restored_chip.dart';
import 'package:field_notes/features/capture/text/editor/format_bar.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteEditorController;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _useKeyboardHighlight() {
  final FocusHighlightStrategy previous =
      FocusManager.instance.highlightStrategy;
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = previous);
}

Future<void> _focusInside(WidgetTester tester, Finder control) async {
  Focus.of(
    tester.element(
      find.descendant(of: control, matching: find.byType(Padding)).first,
    ),
  ).requestFocus();
  await tester.pumpAndSettle();
}

void _expectRingOnEdge(WidgetTester tester, Finder control, double radius) {
  final Finder ring = find.descendant(
    of: control,
    matching: find.byKey(focusRingKey),
  );
  expect(
    tester.renderObject(ring),
    paints..drrect(
      outer: RRect.fromRectAndRadius(
        Offset.zero & tester.getSize(ring),
        Radius.circular(radius),
      ),
      color: FieldNotesColors.light.ink,
    ),
  );
}

void main() {
  testWidgets(
    'a control whose ring sits on its edge paints it inside its edge',
    (WidgetTester tester) async {
      _useKeyboardHighlight();
      final FocusNode focusNode = FocusNode(debugLabel: 'control');
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: FocusRing(
              focusNode: focusNode,
              placement: FocusRingPlacement.edge,
              onPressed: () {},
              child: const SizedBox(width: 120, height: 48),
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pumpAndSettle();

      expect(
        tester.renderObject(find.byKey(focusRingKey)),
        paints..rect(
          rect: (Offset.zero & const Size(120, 48)).deflate(1.5),
          color: FieldNotesColors.light.ink,
          strokeWidth: 3,
          style: PaintingStyle.stroke,
        ),
      );
    },
  );

  testWidgets('a format bar button keeps its ring on its own edge', (
    WidgetTester tester,
  ) async {
    _useKeyboardHighlight();
    final NoteEditorController controller = NoteEditorController(text: '');
    final UndoHistoryController undo = UndoHistoryController();
    addTearDown(controller.dispose);
    addTearDown(undo.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 600,
              child: FormatBar(controller: controller, undoController: undo),
            ),
          ),
        ),
      ),
    );

    final Finder bold = find.byKey(formatBoldKey);
    Focus.of(
      tester.element(
        find.descendant(of: bold, matching: find.byType(Center)).first,
      ),
    ).requestFocus();
    await tester.pumpAndSettle();

    _expectRingOnEdge(tester, bold, Shapes.radiusXs);
  });

  testWidgets(
    'the restored draft chip keeps its Discard ring on its own edge',
    (WidgetTester tester) async {
      _useKeyboardHighlight();
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                child: DraftRestoredChip(onDiscard: () {}),
              ),
            ),
          ),
        ),
      );

      final Finder chip = find.byType(DraftRestoredChip);
      await _focusInside(tester, find.byKey(draftRestoredDiscardKey));

      _expectRingOnEdge(tester, chip, Shapes.radiusPill);
    },
  );
}
