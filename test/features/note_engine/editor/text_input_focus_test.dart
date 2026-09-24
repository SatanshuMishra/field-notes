import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/note_engine/editor/note_editor_controller.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_view.dart';
import 'package:field_notes/features/note_engine/editor/text_input_focus.dart';

void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

T _disposed<T extends ChangeNotifier>(T notifier) {
  addTearDown(notifier.dispose);
  return notifier;
}

void main() {
  testWidgets(
    'the predicate sees the note editor and editable text as text inputs',
    (WidgetTester tester) async {
      _pinSurface(tester);
      final NoteEditorController controller = _disposed(
        NoteEditorController(text: 'fog'),
      );
      final FocusNode editorFocus = _disposed(FocusNode());
      final FocusNode fieldFocus = _disposed(FocusNode());
      final FocusNode plainFocus = _disposed(FocusNode());
      final UndoHistoryController undo = _disposed(UndoHistoryController());
      final ScrollController scroll = _disposed(ScrollController());

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 300,
                  child: NoteEditorView(
                    controller: controller,
                    focusNode: editorFocus,
                    undoController: undo,
                    scrollController: scroll,
                  ),
                ),
                TextField(focusNode: fieldFocus),
                Focus(
                  focusNode: plainFocus,
                  child: const SizedBox(width: 10, height: 10),
                ),
              ],
            ),
          ),
        ),
      );

      expect(isTextInputFocused(), isFalse);

      editorFocus.requestFocus();
      await tester.pump();
      expect(isTextInputFocused(), isTrue);

      fieldFocus.requestFocus();
      await tester.pump();
      expect(isTextInputFocused(), isTrue);

      plainFocus.requestFocus();
      await tester.pump();
      expect(isTextInputFocused(), isFalse);

      plainFocus.unfocus();
      await tester.pump();
      expect(isTextInputFocused(), isFalse);
    },
  );

  testWidgets('a control in the photo toolbar counts as the editor', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final NoteEditorController controller = _disposed(
      NoteEditorController(text: '![p](photo/abc123abc123)'),
    );
    final FocusNode editorFocus = _disposed(FocusNode());
    final FocusNode toolbarFocus = _disposed(FocusNode());
    final UndoHistoryController undo = _disposed(UndoHistoryController());
    final ScrollController scroll = _disposed(ScrollController());
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 24);

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SizedBox(
            height: 600,
            child: NoteEditorView(
              controller: controller,
              focusNode: editorFocus,
              undoController: undo,
              scrollController: scroll,
              photoToolbarBuilder:
                  (BuildContext context, NotePhotoToolbarRequest request) =>
                      Focus(
                        focusNode: toolbarFocus,
                        child: const SizedBox(width: 20, height: 20),
                      ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    toolbarFocus.requestFocus();
    await tester.pump();

    expect(toolbarFocus.hasFocus, isTrue);
    expect(isTextInputFocused(), isTrue);
  });

  testWidgets('removing a focused editor is no longer a text input', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final NoteEditorController controller = _disposed(
      NoteEditorController(text: 'fog'),
    );
    final FocusNode editorFocus = _disposed(FocusNode());
    final UndoHistoryController undo = _disposed(UndoHistoryController());
    final ScrollController scroll = _disposed(ScrollController());

    Widget app({required bool showEditor}) => MaterialApp(
      home: Material(
        child: SizedBox(
          height: 600,
          child: showEditor
              ? NoteEditorView(
                  controller: controller,
                  focusNode: editorFocus,
                  undoController: undo,
                  scrollController: scroll,
                )
              : const SizedBox(),
        ),
      ),
    );

    await tester.pumpWidget(app(showEditor: true));
    editorFocus.requestFocus();
    await tester.pump();
    expect(isTextInputFocused(), isTrue);

    await tester.pumpWidget(app(showEditor: false));
    await tester.pump();

    expect(isTextInputFocused(), isFalse);
  });
}
