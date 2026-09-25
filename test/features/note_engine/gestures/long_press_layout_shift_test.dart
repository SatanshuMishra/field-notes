import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/editor/composer_media_scope.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_controller.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_view.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';

import '../../notes/support/notes_harness.dart';

const String _groceries = 'fresh bread\ncoffee\ncall the ferry office';

final class _Editor {
  _Editor(this.controller)
    : focusNode = FocusNode(),
      undo = UndoHistoryController(),
      scroll = ScrollController(),
      top = ValueNotifier<double>(40);

  final NoteEditorController controller;
  final FocusNode focusNode;
  final UndoHistoryController undo;
  final ScrollController scroll;
  final ValueNotifier<double> top;

  void dispose() {
    top.dispose();
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
  final MediaResolver resolver = FakeNoteMediaResolver()..memoizeAll();
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
              child: ValueListenableBuilder<double>(
                valueListenable: editor.top,
                builder: (BuildContext context, double top, Widget? child) =>
                    Padding(
                      padding: EdgeInsets.only(top: top),
                      child: child,
                    ),
                child: NoteEditorView(
                  controller: editor.controller,
                  focusNode: editor.focusNode,
                  undoController: editor.undo,
                  scrollController: editor.scroll,
                  hintText: '',
                  bottomInset: 0,
                  spellCheckEnabled: false,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return editor;
}

RenderNoteView _renderView(WidgetTester tester) =>
    tester.renderObject<RenderNoteView>(find.byType(NoteViewBody));

void main() {
  testWidgets('a layout shift under a held long press keeps the pressed word', (
    WidgetTester tester,
  ) async {
    final _Editor editor = await _pump(tester, _groceries);
    final int start = _groceries.indexOf('coffee');
    final MdRange coffee = MdRange(start, start + 'coffee'.length);
    final RenderNoteView view = _renderView(tester);
    final Rect bounds = view.noteLayout.rangeBounds(coffee);
    final Offset point = view.contentToGlobal(bounds.center);

    final TestGesture gesture = await tester.startGesture(
      point,
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pump();

    editor.top.value = 0;
    await tester.pump();
    await tester.pump();

    await gesture.moveBy(const Offset(0, 2));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      editor.controller.selection,
      TextSelection(baseOffset: coffee.start, extentOffset: coffee.end),
    );
  });
}
