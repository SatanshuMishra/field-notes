import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/note_engine/editor/note_editor_controller.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_view.dart';

import '../../../support/text_input_messages.dart';

const String _converted = '\u{65E5}\u{672C}\u{8A9E}\u{8A33}';

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
  final _Editor editor = _Editor(NoteEditorController(text: ''));
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
  editor.focusNode.requestFocus();
  await tester.pump();
  await tester.pump();
  return editor;
}

Future<void> _convertWord(WidgetTester tester) async {
  await sendDeltas(tester, <Map<String, Object?>>[
    insertionDelta(
      oldText: '',
      at: 0,
      text: _converted,
      selection: const TextSelection(baseOffset: 0, extentOffset: 4),
      composing: const TextRange(start: 0, end: 4),
    ),
  ]);
  await tester.pump();
}

Future<void> _blurAndReturn(WidgetTester tester, _Editor editor) async {
  editor.focusNode.unfocus();
  await tester.pump();
  editor.focusNode.requestFocus();
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
    'a converted word committed by focus loss keeps the caret after the word',
    (WidgetTester tester) async {
      final _Editor editor = await _pump(tester);
      await _convertWord(tester);
      expect(editor.controller.text, _converted);
      expect(
        editor.controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 4),
      );

      await _blurAndReturn(tester, editor);

      expect(editor.controller.state.composing, isNull);
      expect(editor.controller.text, _converted);
      expect(
        editor.controller.selection,
        const TextSelection.collapsed(offset: 4),
      );
    },
  );

  testWidgets(
    'Return after a converted word was committed by focus loss adds a line',
    (WidgetTester tester) async {
      final _Editor editor = await _pump(tester);
      await _convertWord(tester);
      await _blurAndReturn(tester, editor);

      final Map<Object?, Object?> sent =
          textInputCalls(tester, 'TextInput.setEditingState').last.arguments
              as Map<Object?, Object?>;
      final String platformText = sent['text']! as String;
      final int start = sent['selectionBase']! as int;
      final int end = sent['selectionExtent']! as int;
      await sendDeltas(tester, <Map<String, Object?>>[
        replacementDelta(
          oldText: platformText,
          range: TextRange(start: start, end: end),
          text: '\n',
        ),
      ]);
      await tester.pump();

      expect(editor.controller.text, '$_converted\n');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'a composing word the user never converted is kept with the caret after it',
    (WidgetTester tester) async {
      final _Editor editor = await _pump(tester);
      await sendDeltas(tester, <Map<String, Object?>>[
        insertionDelta(
          oldText: '',
          at: 0,
          text: 'nihongo',
          composing: const TextRange(start: 0, end: 7),
        ),
      ]);
      await tester.pump();

      await _blurAndReturn(tester, editor);

      expect(editor.controller.text, 'nihongo');
      expect(
        editor.controller.selection,
        const TextSelection.collapsed(offset: 7),
      );
    },
  );

  testWidgets(
    'a selection reaching outside the composing range is kept on focus loss',
    (WidgetTester tester) async {
      final _Editor editor = await _pump(tester);
      await sendDeltas(tester, <Map<String, Object?>>[
        insertionDelta(
          oldText: '',
          at: 0,
          text: _converted,
          selection: const TextSelection(baseOffset: 0, extentOffset: 4),
          composing: const TextRange(start: 2, end: 4),
        ),
      ]);
      await tester.pump();

      await _blurAndReturn(tester, editor);

      expect(editor.controller.state.composing, isNull);
      expect(editor.controller.text, _converted);
      expect(
        editor.controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 4),
      );
    },
  );
}
