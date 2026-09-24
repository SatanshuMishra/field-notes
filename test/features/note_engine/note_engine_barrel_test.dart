import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/note_engine.dart';

void main() {
  testWidgets(
    'the barrel exports the editor, reader, controller, keys, media scope and focus predicate',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final NoteEditorController controller = NoteEditorController(
        text: 'fog',
      );
      addTearDown(controller.dispose);
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      final UndoHistoryController undo = UndoHistoryController();
      addTearDown(undo.dispose);
      final ScrollController scroll = ScrollController();
      addTearDown(scroll.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: ComposerMediaScope(
              resolver: null,
              child: Column(
                children: <Widget>[
                  SizedBox(
                    height: 300,
                    child: NoteEditorView(
                      controller: controller,
                      focusNode: focus,
                      undoController: undo,
                      scrollController: scroll,
                    ),
                  ),
                  const SizedBox(
                    height: 300,
                    child: NoteReaderView(source: '# Harbour day'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(noteEditorKey), findsOneWidget);
      expect(find.byType(NoteReaderView), findsOneWidget);
      expect(
        tester.state<NoteEditorViewState>(find.byType(NoteEditorView)),
        isA<NoteEditorViewState>(),
      );

      focus.requestFocus();
      await tester.pump();
      expect(isTextInputFocused(), isTrue);

      expect(tablesEnabled, isA<bool>());
      expect(spellCheckAvailable, isA<bool>());

      expect(parseNoteTree('a'), isA<MdTree>());
    },
  );
}
