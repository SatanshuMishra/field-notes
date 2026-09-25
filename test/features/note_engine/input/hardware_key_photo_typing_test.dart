import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/editor/composer_media_scope.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_controller.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_view.dart';

import '../../../support/text_input_messages.dart';
import '../../notes/support/notes_harness.dart';

const String _middlePhotoNote = 'A\n![p](photo/abc123abc123)\nB';
const String _lastPhotoNote =
    'Two photos\n![](photo/abc123abc123 "right medium")\n![](photo/def456def456 "right medium")\n';

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

Future<_Editor> _pump(WidgetTester tester, String text) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _Editor editor = _Editor(NoteEditorController(text: text));
  addTearDown(editor.dispose);
  final MediaResolver resolver = FakeNoteMediaResolver(<String, ResolvedMedia>{
    'a1b2c3d4e5f6': availablePhoto(photoIdA),
  })..memoizeAll();
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: ComposerMediaScope(
          resolver: resolver,
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
    ),
  );
  await tester.pump();
  editor.focusNode.requestFocus();
  await tester.pump();
  await tester.pump();
  return editor;
}

Map<Object?, Object?> _lastSentState(WidgetTester tester) {
  final List<MethodCall> sent = textInputCalls(
    tester,
    'TextInput.setEditingState',
  );
  return sent.last.arguments as Map<Object?, Object?>;
}

Future<void> _hardwareKeyOverSelectedPhoto(
  WidgetTester tester,
  String letter,
) async {
  final Map<Object?, Object?> state = _lastSentState(tester);
  final String platformText = state['text']! as String;
  final int start = state['selectionBase']! as int;
  final int end = state['selectionExtent']! as int;
  expect(platformText.substring(start, end), '\u{FFFC}');
  final String afterDeletion = platformText.replaceRange(start, end, '');
  await sendDeltas(tester, <Map<String, Object?>>[
    deletionDelta(
      oldText: platformText,
      range: TextRange(start: start, end: end),
    ),
    insertionDelta(oldText: afterDeletion, at: start, text: letter),
  ]);
  await tester.pump();
}

void main() {
  group('B3 hardware key over a selected photo', () {
    testWidgets(
      'a hardware key over a selected middle photo types on a new line after it',
      (WidgetTester tester) async {
        final _Editor editor = await _pump(tester, _middlePhotoNote);
        editor.controller.selection = const TextSelection(
          baseOffset: 2,
          extentOffset: 26,
        );
        await tester.pump();

        await _hardwareKeyOverSelectedPhoto(tester, 'X');

        expect(editor.controller.text, 'A\n![p](photo/abc123abc123)\nX\nB');
      },
    );

    testWidgets('a hardware key over a selected last photo keeps both photos', (
      WidgetTester tester,
    ) async {
      final _Editor editor = await _pump(tester, _lastPhotoNote);
      final int start = _lastPhotoNote.indexOf('![](photo/def456def456');
      final int end = _lastPhotoNote.length - 1;
      editor.controller.selection = TextSelection(
        baseOffset: start,
        extentOffset: end,
      );
      await tester.pump();

      await _hardwareKeyOverSelectedPhoto(tester, 'X');

      expect(
        editor.controller.text,
        'Two photos\n![](photo/abc123abc123 "right medium")\n'
        '![](photo/def456def456 "right medium")\nX\n',
      );
    });
  });
}
