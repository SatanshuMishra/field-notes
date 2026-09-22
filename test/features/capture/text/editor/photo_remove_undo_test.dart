import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/features/capture/text/editor/editor.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';

import '../../../notes/support/notes_harness.dart';

class _Harness {
  _Harness(String text) : controller = MarkdownStyleController(text: text);

  final MarkdownStyleController controller;
  final FocusNode focusNode = FocusNode();
  final UndoHistoryController undo = UndoHistoryController();
  final ScrollController scroll = ScrollController();

  Widget app({bool composing = true}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: ComposerMediaScope(
          resolver: _resolver(),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 560,
              height: 700,
              child: composing
                  ? InPlacePhotoEditor(
                      config: NoteEditorConfig(
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

FakeNoteMediaResolver _resolver() => FakeNoteMediaResolver(
      <String, ResolvedMedia>{
        prefixOf(photoIdA): availablePhoto(photoIdA, width: 1200, height: 900),
      },
    )..memoizeAll();

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

Future<void> _removeSelectedPhoto(WidgetTester tester) async {
  await tester.tap(find.byKey(inPlacePhotoKey(0)));
  await tester.pump();
  await tester.tap(find.byKey(photoToolbarRemoveKey));
  await tester.pumpAndSettle();
}

void main() {
  final String a = photoLine(photoIdA, caption: 'Low tide');

  testWidgets('the trash removes the photo and offers Undo',
      (WidgetTester tester) async {
    final _Harness harness = await _pump(tester, 'one\n$a\ntwo');

    await _removeSelectedPhoto(tester);

    expect(harness.controller.text, 'one\ntwo');
    expect(find.byKey(inPlacePhotoKey(0)), findsNothing);
    expect(find.text(photoRemovedMessage), findsOneWidget);
    expect(find.text(photoRemovedUndoLabel), findsOneWidget);

    dismissTransientToast();
    await tester.pump();
  });

  testWidgets('Undo restores the line byte for byte',
      (WidgetTester tester) async {
    final String note = 'one\n$a\ntwo';
    final _Harness harness = await _pump(tester, note);

    await _removeSelectedPhoto(tester);
    await tester.tap(find.text(photoRemovedUndoLabel));
    await tester.pump();

    expect(harness.controller.text, note);
    expect(find.text(photoRemovedMessage), findsNothing);
  });

  testWidgets('the toast goes when the composer closes',
      (WidgetTester tester) async {
    final _Harness harness = await _pump(tester, 'one\n$a\ntwo');

    await _removeSelectedPhoto(tester);
    expect(find.text(photoRemovedMessage), findsOneWidget);

    await tester.pumpWidget(harness.app(composing: false));
    await tester.pump();

    expect(find.text(photoRemovedMessage), findsNothing);
  });

  testWidgets('Backspace on a selected photo removes it with no toast',
      (WidgetTester tester) async {
    final _Harness harness = await _pump(tester, 'one\n$a\ntwo');
    harness.focusNode.requestFocus();
    await tester.tap(find.byKey(inPlacePhotoKey(0)));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    expect(harness.controller.text, 'one\ntwo');
    expect(find.text(photoRemovedMessage), findsNothing);
  });
}
