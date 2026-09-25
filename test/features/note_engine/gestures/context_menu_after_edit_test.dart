import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/commands/inline_format.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_controller.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_view.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';

import '../../../support/note_editor_driver.dart';

const String _harbour = 'The harbour was quiet.';

final TargetPlatformVariant _android = TargetPlatformVariant.only(
  TargetPlatform.android,
);

final class _Editor {
  _Editor(this.controller)
    : focusNode = FocusNode(),
      undo = UndoHistoryController(),
      scroll = ScrollController();

  final NoteEditorController controller;
  final FocusNode focusNode;
  final UndoHistoryController undo;
  final ScrollController scroll;

  void dispose() {
    scroll.dispose();
    undo.dispose();
    focusNode.dispose();
    controller.dispose();
  }
}

Future<_Editor> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.testTextInput.register();
  addTearDown(tester.testTextInput.unregister);
  final _Editor editor = _Editor(NoteEditorController(text: _harbour));
  addTearDown(editor.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 688,
            height: 600,
            child: NoteEditorView(
              controller: editor.controller,
              focusNode: editor.focusNode,
              undoController: editor.undo,
              scrollController: editor.scroll,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return editor;
}

Offset _centreOf(WidgetTester tester, int start, int end) {
  final RenderNoteView view = tester.renderObject<RenderNoteView>(
    find.descendant(
      of: find.byType(NoteEditorView),
      matching: find.byType(NoteViewBody),
    ),
  );
  return view.contentToGlobal(
    view.noteLayout.rangeBounds(MdRange(start, end)).center,
  );
}

Future<void> _longPressHarbour(WidgetTester tester) async {
  final TestGesture gesture = await tester.startGesture(
    _centreOf(tester, 4, 11),
    kind: PointerDeviceKind.touch,
  );
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.up();
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
    'a format command that collapses the selection hides the context menu',
    (WidgetTester tester) async {
      final _Editor editor = await _pump(tester);
      await _longPressHarbour(tester);
      expect(
        editor.controller.selection,
        const TextSelection(baseOffset: 4, extentOffset: 11),
      );
      expect(find.text('Cut'), findsOneWidget);

      editor.controller.applyCommand(
        (EditorState state) => toggleInlineFormat(state, InlineFormat.link),
      );
      await tester.pump();

      expect(editor.controller.selection.isCollapsed, isTrue);
      expect(find.text('Cut'), findsNothing);
    },
    variant: _android,
  );

  testWidgets('typing after a selection hides the context menu', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester);
    await _longPressHarbour(tester);
    expect(find.text('Cut'), findsOneWidget);

    await NoteEditorDriver(tester).typeText('s');
    await tester.pump();

    expect(editor.controller.text, 'The s was quiet.');
    expect(find.text('Cut'), findsNothing);
  }, variant: _android);
}
