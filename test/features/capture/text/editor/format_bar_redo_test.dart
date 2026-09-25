import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/capture/text/editor/format_bar.dart';
import 'package:field_notes/features/capture/text/editor/note_editor.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteEditorController;

import '../../../../support/note_editor_driver.dart';

const Duration _pastUndoThrottle = Duration(milliseconds: 600);

const Duration _hold = Duration(milliseconds: 110);

class _Harness {
  _Harness()
    : controller = NoteEditorController(),
      undoController = UndoHistoryController(),
      focusNode = FocusNode(),
      scrollController = ScrollController();

  final NoteEditorController controller;
  final UndoHistoryController undoController;
  final FocusNode focusNode;
  final ScrollController scrollController;

  Widget get app => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 180,
            width: 320,
            child: noteEditorFor(
              NoteEditorConfig(
                controller: controller,
                focusNode: focusNode,
                undoController: undoController,
                scrollController: scrollController,
                hintText: 'Start writing…',
              ),
            ),
          ),
          FormatBar(controller: controller, undoController: undoController),
        ],
      ),
    ),
  );

  void dispose() {
    controller.dispose();
    undoController.dispose();
    focusNode.dispose();
    scrollController.dispose();
  }
}

Future<_Harness> _mount(WidgetTester tester) async {
  final _Harness harness = _Harness();
  addTearDown(harness.dispose);
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(harness.app);
  return harness;
}

Future<void> _press(WidgetTester tester, Key key) =>
    NoteEditorDriver(tester).press(find.byKey(key), _hold);

SemanticsProperties _redoSemantics(WidgetTester tester) => tester
    .widget<Semantics>(
      find
          .descendant(
            of: find.byKey(formatRedoKey),
            matching: find.byType(Semantics),
          )
          .first,
    )
    .properties;

void main() {
  testWidgets('redo is disabled until something is undone', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _mount(tester);

    await NoteEditorDriver(tester).enterText('sea');
    await tester.pump(_pastUndoThrottle);

    expect(harness.undoController.value.canUndo, isTrue);
    final SemanticsProperties redo = _redoSemantics(tester);
    expect(redo.button, isTrue);
    expect(redo.label, 'Redo');
    expect(redo.enabled, isFalse);
  });

  testWidgets('redo restores the undone edit with no keyboard', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _mount(tester);

    await NoteEditorDriver(tester).enterText('sea');
    await tester.pump(_pastUndoThrottle);

    await _press(tester, formatUndoKey);
    await tester.pump();
    expect(harness.controller.text, isEmpty);
    expect(_redoSemantics(tester).enabled, isTrue);

    await _press(tester, formatRedoKey);
    await tester.pump();

    expect(harness.controller.text, 'sea');
    expect(_redoSemantics(tester).enabled, isFalse);
  });
}
