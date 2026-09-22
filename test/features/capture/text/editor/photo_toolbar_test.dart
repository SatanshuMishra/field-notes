import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/widgets/widgets.dart';
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
    MediaResolver? resolver,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: ComposerMediaScope(
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

class _PendingMediaResolver implements MediaResolver {
  final Completer<ResolvedMedia> pending = Completer<ResolvedMedia>();

  @override
  ResolvedMedia? resolved(String? mediaId) => null;

  @override
  Future<ResolvedMedia> resolve(String? mediaId) => pending.future;
}

Future<_Harness> _pump(
  WidgetTester tester,
  String text, {
  double width = 560,
  double height = 700,
  MediaResolver? resolver,
}) async {
  tester.view.physicalSize = const Size(1600, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _Harness harness = _Harness(text);
  addTearDown(harness.dispose);
  await tester.pumpWidget(
    harness.app(width: width, height: height, resolver: resolver),
  );
  await tester.pump();
  return harness;
}

Rect _figure(WidgetTester tester, [int ordinal = 0]) =>
    tester.getRect(find.byKey(inPlacePhotoKey(ordinal)));

Rect _bar(WidgetTester tester) => tester.getRect(find.byKey(photoToolbarKey));

bool _hasPrimaryFocus(WidgetTester tester, Key key) =>
    Focus.of(tester.element(find.byKey(key))).hasPrimaryFocus;

String _prose(int words) =>
    List<String>.generate(words, (int i) => 'word${i % 7}').join(' ');

String _lines(int count) =>
    List<String>.generate(count, (int i) => 'line $i').join('\n');

Future<void> _selectPhoto(WidgetTester tester, [int ordinal = 0]) async {
  await tester.tap(find.byKey(inPlacePhotoKey(ordinal)));
  await tester.pump();
}

void main() {
  final String a = photoLine(photoIdA);
  final String b = photoLine(photoIdB);

  testWidgets('it shows only while a photo is selected',
      (WidgetTester tester) async {
    final String note = 'one\n$a\ntwo';
    final _Harness harness = await _pump(tester, note);
    harness.focusNode.requestFocus();
    harness.controller.selection = const TextSelection.collapsed(offset: 1);
    await tester.pump();

    expect(find.byKey(photoToolbarKey), findsNothing);

    await _selectPhoto(tester);

    expect(find.byKey(photoToolbarKey), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.byKey(photoToolbarKey), findsNothing);
    expect(harness.focusNode.hasFocus, isTrue);
  });

  testWidgets('Size and Side rewrite only the selected photo',
      (WidgetTester tester) async {
    final String note = 'one\n$a\ntwo\n$b\nthree';
    final _Harness harness = await _pump(tester, note);

    await _selectPhoto(tester, 1);
    expect(find.byKey(photoToolbarKey), findsOneWidget);

    await tester.tap(find.byKey(photoToolbarSizeKey(PhotoSize.large)));
    await tester.pump();
    await tester.tap(find.byKey(photoToolbarSideKey(PhotoSide.left)));
    await tester.pump();

    final String rewritten = photoLine(
      photoIdB,
      side: PhotoSide.left,
      size: PhotoSize.large,
    );
    expect(rewritten, contains('"left large"'));
    expect(harness.controller.text, 'one\n$a\ntwo\n$rewritten\nthree');
  });

  testWidgets('the More menu reaches Move up, Move down and Replace',
      (WidgetTester tester) async {
    final String note = 'one\n$a\ntwo\n$b\nthree';
    final _Harness harness = await _pump(tester, note);

    await _selectPhoto(tester, 1);
    expect(find.byKey(photoToolbarMoveUpKey), findsNothing);

    await tester.tap(find.byKey(photoToolbarMoreKey));
    await tester.pump();

    expect(find.byKey(photoToolbarMoveUpKey), findsOneWidget);
    expect(find.byKey(photoToolbarMoveDownKey), findsOneWidget);
    expect(find.byKey(photoToolbarReplaceKey), findsOneWidget);

    await tester.tap(find.byKey(photoToolbarMoveUpKey));
    await tester.pump();

    expect(harness.controller.text, 'one\n$a\n$b\ntwo\nthree');
  });

  testWidgets('it flips below the photo when there is no room above',
      (WidgetTester tester) async {
    await _pump(tester, 'one\n$a');
    await _selectPhoto(tester);

    expect(
      _bar(tester).top,
      greaterThanOrEqualTo(_figure(tester).bottom - _tolerance),
    );

    await _pump(tester, '${_lines(10)}\n$a');
    await _selectPhoto(tester);

    expect(
      _bar(tester).bottom,
      lessThanOrEqualTo(_figure(tester).top + _tolerance),
    );
  });

  testWidgets('it stays inside the writing surface and hides when the photo '
      'scrolls away', (WidgetTester tester) async {
    final String photo = photoLine(photoIdA, size: PhotoSize.full);
    final _Harness harness = await _pump(tester, '$photo\n${_prose(400)}');

    await _selectPhoto(tester);

    final Rect surface = tester.getRect(find.byType(InPlacePhotoEditor));
    final Rect bar = _bar(tester);
    expect(bar.left, greaterThanOrEqualTo(surface.left - _tolerance));
    expect(bar.right, lessThanOrEqualTo(surface.right + _tolerance));
    expect(bar.top, greaterThanOrEqualTo(surface.top - _tolerance));
    expect(bar.bottom, lessThanOrEqualTo(surface.bottom + _tolerance));

    harness.scroll.jumpTo(harness.scroll.position.maxScrollExtent);
    await tester.pump();

    expect(find.byKey(photoToolbarKey), findsNothing);
  });

  testWidgets('Tab walks its controls and Esc returns to the writing surface',
      (WidgetTester tester) async {
    final _Harness harness = await _pump(tester, '${_lines(10)}\n$a');

    await _selectPhoto(tester);
    expect(harness.focusNode.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(
      _hasPrimaryFocus(tester, photoToolbarSizeKey(PhotoSize.small)),
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(
      _hasPrimaryFocus(tester, photoToolbarSizeKey(PhotoSize.medium)),
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.byKey(photoToolbarKey), findsNothing);
    expect(harness.focusNode.hasPrimaryFocus, isTrue);
  });

  testWidgets('the mini-diagram predicts the reader, not the editor',
      (WidgetTester tester) async {
    final _PendingMediaResolver resolver = _PendingMediaResolver();
    await _pump(tester, 'one\n$a\n${_prose(60)}', width: 720, resolver: resolver);

    await _selectPhoto(tester);

    final PhotoPlan editorPlan = planFloat(
      measure: 720,
      em: 16,
      side: PhotoSide.right,
      size: PhotoSize.medium,
      aspect: inPlacePhotoFallbackAspect,
      nextIsParagraph: true,
    );
    expect(editorPlan.isStacked, isFalse);
    expect(_figure(tester).width, closeTo(editorPlan.width, _tolerance));

    final PhotoPlan readerPlan = planFloat(
      measure: NoteColumn.measureEm * 16,
      em: 16,
      side: PhotoSide.right,
      size: PhotoSize.medium,
      nextIsParagraph: true,
    );
    expect(readerPlan.isStacked, isTrue);

    final PhotoPlacementDiagram diagram = tester.widget<PhotoPlacementDiagram>(
      find.descendant(
        of: find.byKey(photoToolbarDiagramKey),
        matching: find.byType(PhotoPlacementDiagram),
      ),
    );
    expect(diagram.plan, readerPlan);
    expect(
      find.text('Right · Medium — on this screen, text sits above and below'),
      findsOneWidget,
    );
    expect(find.byKey(photoToolbarSideKey(PhotoSide.left)), findsOneWidget);
  });
}
