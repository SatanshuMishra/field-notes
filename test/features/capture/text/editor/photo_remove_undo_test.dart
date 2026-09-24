import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/features/capture/text/editor/note_editor.dart';
import 'package:field_notes/features/capture/text/editor/photo_toolbar.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show ComposerMediaScope, NoteEditorController;

import '../../../../support/note_editor_driver.dart';
import '../../../../support/photo_line_fixture.dart';
import '../../../notes/support/notes_harness.dart'
    show FakeNoteMediaResolver, availablePhoto, photoIdA, prefixOf;

const Duration _hold = Duration(milliseconds: 110);

class _Harness {
  _Harness(String text) : controller = NoteEditorController(text: text);

  final Key key = UniqueKey();
  final NoteEditorController controller;
  final FocusNode focusNode = FocusNode();
  final UndoHistoryController undo = UndoHistoryController();
  final ScrollController scroll = ScrollController();

  Widget app({bool composing = true}) {
    return MaterialApp(
      key: key,
      debugShowCheckedModeBanner: false,
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
            child: SizedBox(
              width: 720,
              height: 700,
              child: composing
                  ? noteEditorFor(
                      NoteEditorConfig(
                        controller: controller,
                        focusNode: focusNode,
                        undoController: undo,
                        scrollController: scroll,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }

  void dispose() {
    controller.dispose();
    focusNode.dispose();
    undo.dispose();
    scroll.dispose();
  }
}

Future<_Harness> _pump(WidgetTester tester, String text) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _Harness harness = _Harness(text);
  addTearDown(harness.dispose);
  await tester.pumpWidget(harness.app());
  await tester.pump();
  return harness;
}

Future<void> _selectPhoto(WidgetTester tester) async {
  final NoteEditorDriver driver = NoteEditorDriver(tester);
  await driver.press(driver.photoFinder(0), _hold);
  await tester.pump();
}

Future<void> _removeSelectedPhoto(WidgetTester tester) async {
  await _selectPhoto(tester);
  await NoteEditorDriver(
    tester,
  ).press(find.byKey(photoToolbarRemoveKey), _hold);
  await tester.pumpAndSettle();
}

void main() {
  final String a = mdPhotoLine(photoIdA, caption: 'Low tide');

  testWidgets('the trash removes the photo and offers Undo', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pump(tester, 'one\n$a\ntwo');

    await _removeSelectedPhoto(tester);

    expect(harness.controller.text, 'one\n\ntwo');
    expect(NoteEditorDriver(tester).photoFinder(0), findsNothing);
    expect(find.text(photoRemovedMessage), findsOneWidget);
    expect(find.text(photoRemovedUndoLabel), findsOneWidget);

    dismissTransientToast();
    await tester.pump();
  });

  testWidgets('Undo restores the line byte for byte', (
    WidgetTester tester,
  ) async {
    final String note = 'one\n$a\ntwo';
    final _Harness harness = await _pump(tester, note);

    await _removeSelectedPhoto(tester);
    await NoteEditorDriver(
      tester,
    ).press(find.text(photoRemovedUndoLabel), _hold);
    await tester.pump();

    expect(harness.controller.text, note);
    expect(harness.controller.selection.start, 4);
    expect(find.byKey(photoToolbarKey), findsOneWidget);
    expect(find.text(photoRemovedMessage), findsNothing);
  });

  testWidgets('the toast goes when the composer closes', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pump(tester, 'one\n$a\ntwo');

    await _removeSelectedPhoto(tester);
    expect(find.text(photoRemovedMessage), findsOneWidget);

    await tester.pumpWidget(harness.app(composing: false));
    await tester.pump();

    expect(find.text(photoRemovedMessage), findsNothing);
  });

  testWidgets('Backspace on a selected photo removes it with no toast', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pump(tester, 'one\n$a\ntwo');
    harness.focusNode.requestFocus();
    await _selectPhoto(tester);

    await NoteEditorDriver(tester).pressKey(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    expect(harness.controller.text, 'one\n\ntwo');
    expect(find.text(photoRemovedMessage), findsNothing);
  });

  testWidgets(
    'typing after a removal dismisses the toast and undo takes the letter first',
    (WidgetTester tester) async {
      final _Harness harness = await _pump(tester, 'one\n$a\ntwo');
      final NoteEditorDriver driver = NoteEditorDriver(tester);

      await _removeSelectedPhoto(tester);
      expect(find.text(photoRemovedMessage), findsOneWidget);

      await driver.typeText('x');
      await tester.pumpAndSettle();

      expect(find.text(photoRemovedMessage), findsNothing);
      expect(harness.controller.text, isNot('one\n\ntwo'));

      await driver.pressKey(LogicalKeyboardKey.keyZ, meta: true);

      expect(harness.controller.text, 'one\n\ntwo');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
