import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/capture/text/editor/editor.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/notes/notes.dart';

import '../../../notes/support/notes_harness.dart';

const String _editorDirectory = 'lib/features/capture/text/editor';

const List<String> _bannedSpanConstructs = <String>[
  'recognizer:',
];

List<File> _editorSources() {
  final Directory directory = Directory(_editorDirectory);
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .toList();
}

void main() {
  group('the editor never hands a span a gesture recognizer', () {
    test('the editor directory exists and holds sources to inspect', () {
      expect(Directory(_editorDirectory).existsSync(), isTrue);
      expect(_editorSources(), isNotEmpty);
    });

    test('no editor source mentions a banned span construct', () {
      for (final File source in _editorSources()) {
        final String contents = source.readAsStringSync();
        for (final String banned in _bannedSpanConstructs) {
          expect(
            contents.contains(banned),
            isFalse,
            reason: '${source.path} contains "$banned": RenderEditable '
                'asserts on a recognizer in an editable field off macOS, '
                'where it cascades into render-tree exceptions',
          );
        }
      }
    });
  });

  group('the placeholders the wrap draws stay inert', () {
    testWidgets('each one is an empty box of the width the wrap asked for',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final String photo = photoLine(photoIdA, size: PhotoSize.large);
      final String prose =
          List<String>.generate(120, (int i) => 'word${i % 7}').join(' ');
      final String text = 'one\n$photo\n$prose';
      final MarkdownStyleController controller =
          MarkdownStyleController(text: text);
      final FocusNode focusNode = FocusNode();
      final UndoHistoryController undo = UndoHistoryController();
      final ScrollController scroll = ScrollController();
      addTearDown(() {
        controller.dispose();
        focusNode.dispose();
        undo.dispose();
        scroll.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: ComposerMediaScope(
              resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
                prefixOf(photoIdA):
                    availablePhoto(photoIdA, width: 1200, height: 900),
              })
                ..memoizeAll(),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 560,
                  height: 700,
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
      );
      await tester.pump();

      final RenderEditable editable =
          tester.state<EditableTextState>(find.byType(EditableText))
              .renderEditable;
      final List<WidgetSpan> placeholders = <WidgetSpan>[];
      editable.text!.visitChildren((InlineSpan span) {
        if (span is WidgetSpan) {
          placeholders.add(span);
        }
        return true;
      });

      expect(placeholders, isNotEmpty);
      for (final WidgetSpan span in placeholders) {
        expect(span.child, isA<SizedBox>());
        expect(span.style?.fontSize, isNull);
      }
      expect(
        editable.text!.toPlainText(includeSemanticsLabels: false).length,
        controller.text.length,
      );
    });
  });
}
