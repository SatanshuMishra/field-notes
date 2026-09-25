import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/capture/text/composer_footer.dart';
import 'package:field_notes/features/capture/text/editor/note_editor.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show ComposerMediaScope, NoteEditorController;

import '../../../support/note_editor_driver.dart';
import '../../notes/support/notes_harness.dart';

const double _phoneColumn = 400;
const Duration _hold = Duration(milliseconds: 110);

final class _Composing {
  _Composing(String text) : controller = NoteEditorController(text: text);

  final NoteEditorController controller;
  final FocusNode focusNode = FocusNode();
  final UndoHistoryController undo = UndoHistoryController();
  final ScrollController scroll = ScrollController();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
    undo.dispose();
    scroll.dispose();
  }
}

Future<_Composing> _pumpPhoneComposing(
  WidgetTester tester,
  FakePhotoImporter importer,
) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _Composing composing = _Composing('A\n\nB\n\nC');
  addTearDown(composing.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ComposerMediaScope(
          resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
            prefixOf(photoIdA): availablePhoto(
              photoIdA,
              width: 1200,
              height: 900,
            ),
          })..memoizeAll(),
          child: Align(
            alignment: Alignment.topLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: _phoneColumn,
                  height: 500,
                  child: noteEditorFor(
                    NoteEditorConfig(
                      controller: composing.controller,
                      focusNode: composing.focusNode,
                      undoController: composing.undo,
                      scrollController: composing.scroll,
                      photoImporter: importer.call,
                    ),
                  ),
                ),
                SizedBox(
                  width: _phoneColumn,
                  child: ComposerFooter(
                    controller: composing.controller,
                    onAddPhoto: importer.call,
                    editorFocusNode: composing.focusNode,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return composing;
}

void main() {
  testWidgets('a phone column says move or caption after adding a photo', (
    WidgetTester tester,
  ) async {
    final FakePhotoImporter importer = FakePhotoImporter(
      results: <List<String>>[
        <String>[prefixOf(photoIdA)],
      ],
    );
    final _Composing composing = await _pumpPhoneComposing(tester, importer);
    final NoteEditorDriver driver = NoteEditorDriver(tester);
    await driver.setSelection(const TextSelection.collapsed(offset: 1));

    await driver.press(find.byKey(composerAddPhotoKey), _hold);
    await tester.pump();
    await tester.pump();

    expect(importer.calls, 1);
    expect(composing.controller.text, contains('photo/${prefixOf(photoIdA)}'));
    expect(
      find.text('Photo added — tap it to move or caption it'),
      findsOneWidget,
    );
    expect(find.text('Photo added — tap it to size & place it'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
  });
}
