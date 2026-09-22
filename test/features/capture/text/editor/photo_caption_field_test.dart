import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/capture/text/editor/editor.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';

import '../../../notes/support/notes_harness.dart';

class _Harness {
  _Harness(String text) : controller = MarkdownStyleController(text: text);

  final MarkdownStyleController controller;
  final FocusNode focusNode = FocusNode();
  final UndoHistoryController undo = UndoHistoryController();
  final ScrollController scroll = ScrollController();

  Widget app({double width = 560, double height = 700}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: ComposerMediaScope(
          resolver: _resolver(),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: height,
              child: InPlacePhotoEditor(
                config: NoteEditorConfig(
                  controller: controller,
                  focusNode: focusNode,
                  undoController: undo,
                  scrollController: scroll,
                ),
              ),
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
        prefixOf(photoIdB): availablePhoto(photoIdB, width: 1200, height: 900),
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

Future<void> _openCaption(WidgetTester tester, int ordinal) async {
  await tester.tap(find.byKey(inPlacePhotoKey(ordinal)));
  await tester.pump();
  await tester.tap(find.byKey(photoToolbarCaptionKey));
  await tester.pump();
}

void main() {
  final String a = photoLine(photoIdA);
  final String b = photoLine(photoIdB);

  testWidgets('Caption opens a field under the photo and commits into the '
      'alt slot', (WidgetTester tester) async {
    final String note = 'one\n$a\ntwo\n$b\nthree';
    final _Harness harness = await _pump(tester, note);

    await _openCaption(tester, 0);

    expect(find.byKey(photoCaptionFieldEditorKey), findsOneWidget);
    final Rect figure = tester.getRect(find.byKey(inPlacePhotoKey(0)));
    final Rect field = tester.getRect(find.byKey(photoCaptionFieldEditorKey));
    expect(field.top, greaterThan(figure.top));
    expect(field.bottom, lessThanOrEqualTo(figure.bottom + 0.5));

    await tester.enterText(
      find.byKey(photoCaptionFieldEditorKey),
      'Low tide',
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    final String captioned = photoLine(photoIdA, caption: 'Low tide');
    expect(captioned, contains('![Low tide](photo/'));
    expect(harness.controller.text, 'one\n$captioned\ntwo\n$b\nthree');
    expect(find.byKey(photoCaptionFieldEditorKey), findsNothing);
  });

  testWidgets('Esc cancels a caption edit and leaves the note untouched',
      (WidgetTester tester) async {
    final String captioned = photoLine(photoIdA, caption: 'Harbour');
    final String note = 'one\n$captioned\ntwo';
    final _Harness harness = await _pump(tester, note);

    await _openCaption(tester, 0);

    expect(
      tester.widget<TextField>(find.byKey(photoCaptionFieldEditorKey))
          .controller
          ?.text,
      'Harbour',
    );

    await tester.enterText(
      find.byKey(photoCaptionFieldEditorKey),
      'Harbour at dusk',
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(harness.controller.text, note);
    expect(find.byKey(photoCaptionFieldEditorKey), findsNothing);
    expect(harness.focusNode.hasFocus, isTrue);
  });
}
