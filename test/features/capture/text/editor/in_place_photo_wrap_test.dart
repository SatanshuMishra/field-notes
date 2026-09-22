import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/capture/text/editor/editor.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/notes/notes.dart';

import '../../../notes/support/notes_harness.dart';

const double _tolerance = 0.5;

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
      },
    )..memoizeAll();

Future<_Harness> _pump(
  WidgetTester tester,
  String text, {
  double width = 560,
  double height = 700,
}) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _Harness harness = _Harness(text);
  addTearDown(harness.dispose);
  await tester.pumpWidget(harness.app(width: width, height: height));
  await tester.pump();
  return harness;
}

RenderEditable _editable(WidgetTester tester) =>
    tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;

Rect _figure(WidgetTester tester, [int ordinal = 0]) =>
    tester.getRect(find.byKey(inPlacePhotoKey(ordinal)));

List<Rect> _glyphs(WidgetTester tester, int from, int to) {
  final RenderEditable editable = _editable(tester);
  final String text = editable.plainText;
  final List<Rect> rects = <Rect>[];
  for (int i = from; i < to && i < text.length; i++) {
    if (_blank(text[i])) {
      continue;
    }
    for (final TextBox box in editable.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + 1),
    )) {
      rects.add(
        Rect.fromPoints(
          editable.localToGlobal(Offset(box.left, box.top)),
          editable.localToGlobal(Offset(box.right, box.bottom)),
        ),
      );
    }
  }
  return rects;
}

bool _blank(String character) =>
    character == ' ' ||
    character == '\n' ||
    character == '\t' ||
    character == '\r' ||
    character == '\uFFFC';

void _expectClearOf(List<Rect> glyphs, Rect figure) {
  final Rect picture = figure.deflate(_tolerance);
  for (final Rect glyph in glyphs) {
    expect(
      glyph.overlaps(picture),
      isFalse,
      reason: '$glyph runs across the photo at $figure',
    );
  }
}

List<Rect> _besideOf(List<Rect> glyphs, Rect figure) => <Rect>[
      for (final Rect glyph in glyphs)
        if (glyph.center.dy > figure.top && glyph.center.dy < figure.bottom)
          glyph,
    ];

Rect _glyph(WidgetTester tester, int offset) =>
    _glyphs(tester, offset, offset + 1).first;

String _prose(int words) =>
    List<String>.generate(words, (int i) => 'word${i % 7}').join(' ');

void main() {
  group('a floated photo', () {
    testWidgets('keeps the paragraph beside it and the rest below it',
        (WidgetTester tester) async {
      final String photo = photoLine(photoIdA, size: PhotoSize.large);
      final String text = 'one\n$photo\n${_prose(120)}';
      await _pump(tester, text);
      final int start = text.indexOf(photo);
      final int paragraph = start + photo.length + 1;

      final Rect figure = _figure(tester);
      expect(figure.right, closeTo(560, _tolerance));
      expect(
        _glyph(tester, paragraph).top,
        closeTo(figure.top, 6),
      );

      final List<Rect> glyphs = _glyphs(tester, paragraph, text.length);
      _expectClearOf(glyphs, figure);
      expect(_besideOf(glyphs, figure).length, greaterThan(20));
      final List<Rect> below = <Rect>[
        for (final Rect rect in glyphs)
          if (rect.top >= figure.bottom - _tolerance) rect,
      ];
      expect(below, isNotEmpty);
      expect(
        below.map((Rect rect) => rect.right).reduce((a, b) => a > b ? a : b),
        greaterThan(figure.left),
      );
    });

    testWidgets('on the left it indents the text beside it',
        (WidgetTester tester) async {
      final String photo = photoLine(
        photoIdA,
        side: PhotoSide.left,
        size: PhotoSize.large,
      );
      final String text = 'one\n$photo\n${_prose(120)}';
      await _pump(tester, text);
      final int paragraph = text.indexOf(photo) + photo.length + 1;

      final Rect figure = _figure(tester);
      expect(figure.left, closeTo(0, _tolerance));

      final List<Rect> glyphs = _glyphs(tester, paragraph, text.length);
      _expectClearOf(glyphs, figure);
      expect(_besideOf(glyphs, figure).length, greaterThan(20));
    });

    testWidgets('a paragraph with line breaks still clears a left photo',
        (WidgetTester tester) async {
      final String photo = photoLine(
        photoIdA,
        side: PhotoSide.left,
        size: PhotoSize.large,
      );
      final String body = List<String>.filled(8, _prose(6)).join('\n');
      final String text = 'one\n$photo\n$body';
      await _pump(tester, text);
      final int paragraph = text.indexOf(photo) + photo.length + 1;

      final Rect figure = _figure(tester);
      final List<Rect> glyphs = _glyphs(tester, paragraph, text.length);
      _expectClearOf(glyphs, figure);
      expect(_besideOf(glyphs, figure).length, greaterThan(20));
    });

    testWidgets('a short paragraph pushes the next block below the photo',
        (WidgetTester tester) async {
      final String photo = photoLine(photoIdA, size: PhotoSize.large);
      final String text = 'one\n$photo\nshort note\n\n# after';
      await _pump(tester, text);
      final int after = text.indexOf('# after');

      expect(
        _glyph(tester, after).top,
        greaterThanOrEqualTo(_figure(tester).bottom - _tolerance),
      );
    });

    testWidgets('a short paragraph at the end keeps the photo scrollable',
        (WidgetTester tester) async {
      final String photo = photoLine(photoIdA, size: PhotoSize.large);
      final String text = 'one\n$photo\nshort note';
      final _Harness harness = await _pump(tester, text, height: 120);

      await tester.pump();
      final Rect figure = _figure(tester);
      expect(figure.bottom, greaterThan(120));
      expect(
        harness.scroll.position.maxScrollExtent + 120,
        greaterThanOrEqualTo(figure.bottom - _tolerance),
      );
    });

    testWidgets('the source is untouched by the wrap',
        (WidgetTester tester) async {
      final String photo = photoLine(photoIdA, size: PhotoSize.large);
      final String text = 'one\n$photo\n${_prose(60)}';
      final _Harness harness = await _pump(tester, text);

      expect(harness.controller.text, text);
      final String drawn =
          _editable(tester).text!.toPlainText(includeSemanticsLabels: false);
      expect(drawn.length, text.length);
      for (int i = 0; i < text.length; i++) {
        if (drawn[i] == text[i]) {
          continue;
        }
        expect(_blank(text[i]), isTrue, reason: 'character $i was rewritten');
        expect(drawn[i], '\uFFFC');
      }
    });
  });

  group('scrolling', () {
    testWidgets('the wheel scrolls with the pointer over a photo',
        (WidgetTester tester) async {
      final String photo = photoLine(photoIdA, size: PhotoSize.large);
      final String text = 'one\n$photo\n${_prose(400)}';
      final _Harness harness = await _pump(tester, text, height: 300);

      final Offset onPhoto = _figure(tester).center;
      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(onPhoto));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
      await tester.pump();

      expect(harness.scroll.offset, closeTo(120, 1));
    });

    testWidgets('the trackpad scrolls with the pointer over a photo',
        (WidgetTester tester) async {
      final String photo = photoLine(photoIdA, size: PhotoSize.large);
      final String text = 'one\n$photo\n${_prose(400)}';
      final _Harness harness = await _pump(tester, text, height: 300);

      final Offset onPhoto = _figure(tester).center;
      final TestPointer pointer = TestPointer(2, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(pointer.panZoomStart(onPhoto));
      await tester.sendEventToBinding(
        pointer.panZoomUpdate(onPhoto, pan: const Offset(0, -90)),
      );
      await tester.sendEventToBinding(pointer.panZoomEnd());
      await tester.pump();

      expect(harness.scroll.offset, greaterThan(50));
    });
  });

  group('the caret beside a left photo', () {
    testWidgets('never hides under the picture', (WidgetTester tester) async {
      final String photo = photoLine(
        photoIdA,
        side: PhotoSide.left,
        size: PhotoSize.large,
      );
      final String text = 'one\n$photo\n${_prose(120)}';
      final _Harness harness = await _pump(tester, text);
      harness.focusNode.requestFocus();
      await tester.pump();

      final Rect figure = _figure(tester);
      final int paragraph = text.indexOf(photo) + photo.length + 1;
      for (int offset = paragraph; offset < text.length; offset++) {
        harness.controller.selection = TextSelection.collapsed(offset: offset);
        await tester.pump();

        final Rect caret = _caretRect(tester);
        if (caret.top >= figure.bottom - _tolerance) {
          continue;
        }
        expect(
          caret.left,
          greaterThanOrEqualTo(figure.right - _tolerance),
          reason: 'caret at $offset sits under the photo',
        );
      }
    });
  });
}

Rect _caretRect(WidgetTester tester) {
  final Finder drawn = find.byKey(inPlaceCaretKey);
  if (drawn.evaluate().isNotEmpty) {
    return tester.getRect(drawn);
  }
  final RenderEditable editable = _editable(tester);
  final Rect local = editable.getLocalRectForCaret(
    TextPosition(
      offset: editable.selection!.baseOffset,
      affinity: editable.selection!.affinity,
    ),
  );
  return Rect.fromPoints(
    editable.localToGlobal(local.topLeft),
    editable.localToGlobal(local.bottomRight),
  );
}
