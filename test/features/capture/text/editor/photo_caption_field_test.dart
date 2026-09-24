import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/capture/text/editor/note_editor.dart';
import 'package:field_notes/features/capture/text/editor/photo_caption_field.dart';
import 'package:field_notes/features/capture/text/editor/photo_toolbar.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/layout/note_typography.dart'
    show NoteTypography;
import 'package:field_notes/features/note_engine/note_engine.dart'
    show ComposerMediaScope, NoteEditorController;
import 'package:field_notes/features/note_engine/render/photo_figure.dart'
    show photoFigureFrameKey;

import '../../../../support/note_editor_driver.dart';
import '../../../../support/photo_line_fixture.dart';
import '../../../notes/support/notes_harness.dart'
    show FakeNoteMediaResolver, availablePhoto, photoIdA, photoIdB, prefixOf;

const Duration _hold = Duration(milliseconds: 110);

class _Harness {
  _Harness(String text) : controller = NoteEditorController(text: text);

  final Key key = UniqueKey();
  final NoteEditorController controller;
  final FocusNode focusNode = FocusNode();
  final UndoHistoryController undo = UndoHistoryController();
  final ScrollController scroll = ScrollController();

  Widget app({double width = 720, double height = 700}) {
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
            prefixOf(photoIdB): availablePhoto(
              photoIdB,
              width: 1200,
              height: 900,
            ),
          })..memoizeAll(),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: height,
              child: noteEditorFor(
                NoteEditorConfig(
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

Future<_Harness> _pump(
  WidgetTester tester,
  String text, {
  double width = 720,
}) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _Harness harness = _Harness(text);
  addTearDown(harness.dispose);
  await tester.pumpWidget(harness.app(width: width));
  await tester.pump();
  return harness;
}

Rect _photoFrame(WidgetTester tester, int ordinal) => tester.getRect(
  find.descendant(
    of: NoteEditorDriver(tester).photoFinder(ordinal),
    matching: find.byKey(photoFigureFrameKey),
  ),
);

Future<void> _openCaption(WidgetTester tester, int ordinal) async {
  final NoteEditorDriver driver = NoteEditorDriver(tester);
  await driver.press(driver.photoFinder(ordinal), _hold);
  await tester.pump();
  await driver.press(find.byKey(photoToolbarCaptionKey), _hold);
  await tester.pump();
}

void main() {
  final String a = mdPhotoLine(photoIdA);
  final String b = mdPhotoLine(photoIdB);

  testWidgets('Caption opens a field under the photo and commits into the '
      'alt slot', (WidgetTester tester) async {
    final String note = 'one\n$a\ntwo\n$b\nthree';
    final _Harness harness = await _pump(tester, note);

    await _openCaption(tester, 0);

    expect(find.byKey(photoCaptionFieldEditorKey), findsOneWidget);
    final Rect frame = _photoFrame(tester, 0);
    final Rect field = tester.getRect(find.byKey(photoCaptionFieldEditorKey));
    expect(field.top, closeTo(frame.bottom + 8, 0.5));
    expect(field.left, closeTo(frame.left, 0.5));
    expect(field.width, closeTo(frame.width, 0.5));

    await tester.enterText(find.byKey(photoCaptionFieldEditorKey), 'Low tide');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    final String captioned = mdPhotoLine(photoIdA, caption: 'Low tide');
    expect(captioned, '![Low tide](photo/a1b2c3d4e5f6 "right medium")');
    expect(harness.controller.text, 'one\n$captioned\ntwo\n$b\nthree');
    expect(find.byKey(photoCaptionFieldEditorKey), findsNothing);
  });

  testWidgets('the caption field is drawn in the caption style', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      'one\n![Harbour](photo/a1b2c3d4e5f6 "centre medium")\ntwo',
      width: 688,
    );
    final double captionTop = tester
        .getRect(
          find.descendant(
            of: NoteEditorDriver(tester).photoFinder(0),
            matching: find.text('Harbour'),
          ),
        )
        .top;

    await _openCaption(tester, 0);

    final Finder field = find.byKey(photoCaptionFieldEditorKey);
    final TextField textField = tester.widget<TextField>(field);
    expect(textField.style, NoteTypography.caption);
    expect(textField.textAlign, TextAlign.center);
    expect(textField.controller?.text, 'Harbour');
    expect(tester.getSize(field).width, closeTo(344, 0.5));
    expect(tester.getRect(field).top, closeTo(captionTop, 0.5));
  });

  testWidgets('Esc cancels a caption edit and leaves the note untouched', (
    WidgetTester tester,
  ) async {
    final String captioned = mdPhotoLine(photoIdA, caption: 'Harbour');
    final String note = 'one\n$captioned\ntwo';
    final _Harness harness = await _pump(tester, note);

    await _openCaption(tester, 0);

    expect(
      tester
          .widget<TextField>(find.byKey(photoCaptionFieldEditorKey))
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

  testWidgets('a press outside the field commits the caption', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pump(tester, 'one\n$a\ntwo');

    await _openCaption(tester, 0);
    await tester.enterText(find.byKey(photoCaptionFieldEditorKey), 'Dusk');
    await tester.pump();
    final TestGesture outside = await tester.startGesture(
      const Offset(1100, 1900),
    );
    await tester.pump(_hold);
    await outside.up();
    await tester.pump();

    expect(
      harness.controller.text,
      'one\n${mdPhotoLine(photoIdA, caption: 'Dusk')}\ntwo',
    );
    expect(find.byKey(photoCaptionFieldEditorKey), findsNothing);
  });

  testWidgets('a bracket or a line break never reaches the caption', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pump(tester, 'one\n$a\ntwo');

    await _openCaption(tester, 0);
    await tester.enterText(find.byKey(photoCaptionFieldEditorKey), 'a]b\nc');
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(photoCaptionFieldEditorKey))
          .controller
          ?.text,
      'abc',
    );

    await tester.enterText(
      find.byKey(photoCaptionFieldEditorKey),
      '  Low tide  ',
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(
      harness.controller.text,
      'one\n${mdPhotoLine(photoIdA, caption: 'Low tide')}\ntwo',
    );
  });
}
