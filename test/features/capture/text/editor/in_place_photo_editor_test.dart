import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

  Widget app({
    double width = 560,
    double height = 700,
    double scale = 1,
    MediaResolver? resolver,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: ComposerMediaScope(
              resolver: resolver ?? _resolver(),
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
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _Harness harness = _Harness(text);
  addTearDown(harness.dispose);
  await tester.pumpWidget(
    harness.app(width: width, height: height, scale: scale),
  );
  await tester.pump();
  return harness;
}

RenderEditable _editable(WidgetTester tester) =>
    tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;

Rect _glyph(WidgetTester tester, int offset) {
  final RenderEditable editable = _editable(tester);
  final TextBox box = editable
      .getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + 1),
      )
      .first;
  return Rect.fromPoints(
    editable.localToGlobal(Offset(box.left, box.top)),
    editable.localToGlobal(Offset(box.right, box.bottom)),
  );
}

Rect _figure(WidgetTester tester, [int ordinal = 0]) =>
    tester.getRect(find.byKey(inPlacePhotoKey(ordinal)));

TextSpan? _spanOf(WidgetTester tester, String text) {
  TextSpan? found;
  _editable(tester).text!.visitChildren((InlineSpan span) {
    if (span is TextSpan && span.text == text) {
      found = span;
      return false;
    }
    return true;
  });
  return found;
}

void _expectOnBand(WidgetTester tester, int lineStart, [int ordinal = 0]) {
  expect(
    _figure(tester, ordinal).center.dy,
    closeTo(_glyph(tester, lineStart).center.dy, _tolerance),
  );
}

void _expectAtLineTop(WidgetTester tester, int lineStart, [int ordinal = 0]) {
  expect(
    _figure(tester, ordinal).top,
    closeTo(_glyph(tester, lineStart).top, _tolerance),
  );
}

void main() {
  final String a = photoLine(photoIdA);
  final String note = 'one\n$a\ntwo';
  final String stacked = 'one\n$a\n# two';
  final int stackedStart = stacked.indexOf(a);
  final int stackedAfter = stacked.indexOf('# two');
  final int photoStart = note.indexOf(a);
  final int photoEnd = photoStart + a.length;
  final int twoStart = note.indexOf('two');

  group('the band', () {
    testWidgets('lays out at the figure height, with the figure on it',
        (WidgetTester tester) async {
      await _pump(tester, stacked);

      final PhotoPlan plan = planFloat(
        measure: 560,
        em: 16,
        side: PhotoSide.right,
        size: PhotoSize.medium,
        aspect: 1200 / 900,
      );
      final Rect figure = _figure(tester);
      expect(figure.size, Size(plan.width, plan.height));
      _expectOnBand(tester, stackedStart);
      expect(
        _glyph(tester, 2).bottom,
        lessThanOrEqualTo(figure.top - photoBandPadding + _tolerance),
      );
      expect(
        _glyph(tester, stackedAfter).top,
        greaterThanOrEqualTo(figure.bottom + photoBandPadding - _tolerance),
      );
      expect(
        _glyph(tester, stackedAfter).top - (figure.bottom + photoBandPadding),
        lessThan(16),
      );
    });

    testWidgets('draws its Markdown invisibly and hides the caret on it',
        (WidgetTester tester) async {
      final _Harness harness = await _pump(tester, note);

      expect(_spanOf(tester, a)?.style?.color, const Color(0x00000000));

      harness.controller.selection =
          TextSelection.collapsed(offset: photoStart + 4);
      await tester.pump();

      expect(
        tester.widget<EditableText>(find.byType(EditableText)).cursorColor,
        const Color(0x00000000),
      );
      expect(find.byKey(inPlacePhotoRingKey), findsOneWidget);

      harness.controller.selection =
          TextSelection.collapsed(offset: twoStart + 1);
      await tester.pump();

      expect(
        tester.widget<EditableText>(find.byType(EditableText)).cursorColor,
        isNot(const Color(0x00000000)),
      );
      expect(find.byKey(inPlacePhotoRingKey), findsNothing);
    });

    testWidgets('a right photo sits against the right edge of the column',
        (WidgetTester tester) async {
      await _pump(tester, note);

      expect(_figure(tester).right, closeTo(560, _tolerance));
    });
  });

  group('the figure tracks its band', () {
    testWidgets('while the editor scrolls', (WidgetTester tester) async {
      final String before = List<String>.filled(30, 'a line of text').join('\n');
      final String after = List<String>.filled(30, 'more text').join('\n');
      final String long = '$before\n$a\n$after';
      final _Harness harness = await _pump(tester, long, height: 400);
      final int start = long.indexOf(a);

      for (final double offset in <double>[0, 200, 420, 700]) {
        harness.scroll.jumpTo(offset);
        await tester.pump();

        _expectAtLineTop(tester, start);
      }
    });

    testWidgets('while the window resizes', (WidgetTester tester) async {
      final _Harness harness = await _pump(tester, note);

      for (final double width in <double>[560, 700, 480, 900]) {
        await tester.pumpWidget(harness.app(width: width));
        await tester.pump();

        _expectAtLineTop(tester, photoStart);
        expect(_figure(tester).right, closeTo(width, _tolerance));
      }
    });

    for (final double scale in <double>[1.0, 1.5, 2.0]) {
      testWidgets('at ${scale}x text', (WidgetTester tester) async {
        await _pump(tester, stacked, scale: scale, width: 900);

        _expectOnBand(tester, stackedStart);
        expect(
          _glyph(tester, stackedAfter).top,
          greaterThanOrEqualTo(
            _figure(tester).bottom + photoBandPadding - _tolerance,
          ),
        );
      });
    }

    testWidgets('while text is typed above it', (WidgetTester tester) async {
      final _Harness harness = await _pump(tester, note);

      harness.controller.value = TextEditingValue(
        text: 'one\nand another line\n$a\ntwo',
        selection: const TextSelection.collapsed(offset: 20),
      );
      await tester.pump();

      _expectAtLineTop(tester, 'one\nand another line\n'.length);
    });
  });

  testWidgets('past the live-style limit the photo still shows in place',
      (WidgetTester tester) async {
    final String prose = 'word ' * 1300;
    final String long = '$prose\n$a\ntwo';
    expect(long.length, greaterThan(MarkdownStyleController.liveStyleLimit));
    await _pump(tester, long);

    expect(_spanOf(tester, a)?.style?.color, const Color(0x00000000));
    _expectAtLineTop(tester, long.indexOf(a));
  });

  testWidgets('select-all covers the exact source, photo lines included',
      (WidgetTester tester) async {
    final _Harness harness = await _pump(tester, note);

    harness.controller.selection =
        TextSelection(baseOffset: 0, extentOffset: note.length);
    await tester.pump();

    expect(harness.controller.selection.textInside(note), note);
    final String drawn =
        _editable(tester).text!.toPlainText(includeSemanticsLabels: false);
    expect(drawn.length, note.length);
    for (int i = 0; i < note.length; i++) {
      if (drawn[i] == note[i]) {
        continue;
      }
      expect(note[i], anyOf(' ', '\n'));
      expect(drawn[i], '\uFFFC');
    }
  });

  group('selecting and editing', () {
    testWidgets('a click on the picture selects its photo',
        (WidgetTester tester) async {
      final _Harness harness = await _pump(tester, note);

      await tester.tap(find.byKey(inPlacePhotoKey(0)));
      await tester.pump();

      expect(harness.focusNode.hasFocus, isTrue);
      expect(
        harness.controller.selection.baseOffset,
        inInclusiveRange(photoStart, photoEnd),
      );
      expect(find.byKey(inPlacePhotoRingKey), findsOneWidget);
    });

    testWidgets('Backspace after a photo selects it, then removes it',
        (WidgetTester tester) async {
      final _Harness harness = await _pump(tester, note);
      harness.focusNode.requestFocus();
      harness.controller.selection =
          TextSelection.collapsed(offset: twoStart);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(harness.controller.text, note);
      expect(
        harness.controller.selection.baseOffset,
        inInclusiveRange(photoStart, photoEnd),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(harness.controller.text, 'one\ntwo');
      expect(find.byKey(inPlacePhotoKey(0)), findsNothing);
    });

    testWidgets('the arrows cross a photo in one step each way',
        (WidgetTester tester) async {
      final _Harness harness = await _pump(tester, note);
      harness.focusNode.requestFocus();
      harness.controller.selection =
          TextSelection.collapsed(offset: photoStart + 4);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        harness.controller.selection,
        TextSelection.collapsed(offset: twoStart),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(
        harness.controller.selection.baseOffset,
        inInclusiveRange(photoStart, photoEnd),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(
        harness.controller.selection,
        const TextSelection.collapsed(offset: 3),
      );
    });

    testWidgets('Esc deselects a photo', (WidgetTester tester) async {
      final _Harness harness = await _pump(tester, note);
      harness.focusNode.requestFocus();
      harness.controller.selection =
          TextSelection.collapsed(offset: photoStart + 4);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(
        harness.controller.selection,
        TextSelection.collapsed(offset: twoStart),
      );
      expect(find.byKey(inPlacePhotoRingKey), findsNothing);
    });

    testWidgets('typing on a selected photo writes on a new line after it',
        (WidgetTester tester) async {
      final _Harness harness = await _pump(tester, note);
      await tester.showKeyboard(find.byType(EditableText));
      harness.controller.selection =
          TextSelection.collapsed(offset: photoStart + 4);
      await tester.pump();

      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: note.replaceRange(photoStart + 4, photoStart + 4, 'x'),
          selection: TextSelection.collapsed(offset: photoStart + 5),
        ),
      );
      await tester.pump();

      expect(harness.controller.text, 'one\n$a\nx\ntwo');
      expect(find.byKey(inPlacePhotoKey(0)), findsOneWidget);
    });

    testWidgets('undo restores the note after an edit beside a photo',
        (WidgetTester tester) async {
      final _Harness harness = await _pump(tester, note);
      await tester.showKeyboard(find.byType(EditableText));
      harness.controller.selection =
          TextSelection.collapsed(offset: photoStart + 4);
      await tester.pump(const Duration(milliseconds: 600));

      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: note.replaceRange(photoStart + 4, photoStart + 4, 'x'),
          selection: TextSelection.collapsed(offset: photoStart + 5),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(harness.controller.text, 'one\n$a\nx\ntwo');

      harness.undo.undo();
      await tester.pump();

      expect(harness.controller.text, note);
    });
  });
}
