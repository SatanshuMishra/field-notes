import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/note_engine.dart';

const List<String> _expectedExports = <String>[
  "export 'capabilities.dart';",
  "export 'editor/composer_media_scope.dart';",
  "export 'editor/editor_keys.dart';",
  "export 'editor/note_editor_controller.dart';",
  "export 'editor/note_editor_view.dart';",
  "export 'editor/text_input_focus.dart';",
  "export 'reader/note_reader_view.dart';",
];

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

  test('the barrel source is exactly the seven export directives, in order', () {
    final File barrel = File('lib/features/note_engine/note_engine.dart');
    final List<String> lines = barrel
        .readAsStringSync()
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();

    expect(lines, _expectedExports);
    expect(lines.any((String line) => line.startsWith('import ')), isFalse);
  });
}
