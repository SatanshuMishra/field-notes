import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/text/editor/editor.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';

class _EditorHarness {
  _EditorHarness()
      : controller = MarkdownStyleController(),
        undoController = UndoHistoryController(),
        focusNode = FocusNode(),
        scrollController = ScrollController();

  final MarkdownStyleController controller;
  final UndoHistoryController undoController;
  final FocusNode focusNode;
  final ScrollController scrollController;

  Widget get app => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: SizedBox(
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

Future<void> _pumpComposer(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DialogHost(
        child: ComposerShell(
          child: TextComposerSheet(onSave: (String _) {}, onCancel: () {}),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the writing surface is a TextField, not a raw EditableText',
      (WidgetTester tester) async {
    await _pumpComposer(tester);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(EditableText), findsOneWidget);
    expect(find.byType(InPlacePhotoEditor), findsOneWidget);
  });

  testWidgets('the selection overlay survives: handles and a context menu',
      (WidgetTester tester) async {
    await _pumpComposer(tester);

    final EditableText editor = tester.widget<EditableText>(
      find.byType(EditableText),
    );

    expect(editor.selectionControls, isNotNull);
    expect(editor.contextMenuBuilder, isNotNull);
    expect(editor.enableInteractiveSelection, isTrue);
    expect(
      editor.magnifierConfiguration,
      isNot(same(TextMagnifierConfiguration.disabled)),
    );
  });

  testWidgets('a long press paints a real selection',
      (WidgetTester tester) async {
    final _EditorHarness harness = _EditorHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app);

    await tester.enterText(find.byType(EditableText), 'hello there world');
    await tester.pump();

    await tester.longPressAt(
      tester.getTopLeft(find.byType(EditableText)) + const Offset(12, 10),
    );
    await tester.pumpAndSettle();

    expect(harness.controller.selection.isCollapsed, isFalse);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).selectionColor,
      isNotNull,
    );
  });

  testWidgets('spell check and stylus handwriting stay off',
      (WidgetTester tester) async {
    await _pumpComposer(tester);

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.spellCheckConfiguration, isNull);
    expect(field.stylusHandwritingEnabled, isFalse);

    final EditableTextState state = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    expect(state.spellCheckEnabled, isFalse);
  });

  testWidgets('the editor writes in the note body type, not the theme type',
      (WidgetTester tester) async {
    await _pumpComposer(tester);

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style, unmergedFromTheMaterialTextTheme(
      TypographyTokens.noteBody,
    ));

    final EditableText editor = tester.widget<EditableText>(
      find.byType(EditableText),
    );
    expect(editor.style.fontFamily, TypographyTokens.noteBody.fontFamily);
    expect(editor.style.fontSize, TypographyTokens.noteBody.fontSize);
    expect(editor.style.height, TypographyTokens.noteBody.height);
    expect(editor.style.color, TypographyTokens.noteBody.color);
    expect(editor.style.letterSpacing, isNull);
  });

  testWidgets('the mounted editor paints the styled span from the controller',
      (WidgetTester tester) async {
    final _EditorHarness harness = _EditorHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app);

    await tester.enterText(find.byType(EditableText), '**bold** plain');
    await tester.pump();

    final EditableTextState state = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    final InlineSpan painted = state.renderEditable.text!;

    expect(painted.toPlainText(includeSemanticsLabels: false), '**bold** plain');
    expect((painted as TextSpan).children, isNotNull);
  });

  testWidgets('the editor never truncates and enforces no length limit',
      (WidgetTester tester) async {
    final _EditorHarness harness = _EditorHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app);

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLength, isNull);
    expect(
      field.inputFormatters ?? const <TextInputFormatter>[],
      isNot(contains(isA<LengthLimitingTextInputFormatter>())),
    );

    final String long = 'a long note line.\n' * 500;
    await tester.enterText(find.byType(EditableText), long);
    await tester.pump();

    expect(harness.controller.text.length, long.length);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText))
          .controller
          .text
          .length,
      long.length,
    );
  });

  testWidgets('a plain controller handed to the composer is still styled live',
      (WidgetTester tester) async {
    final TextEditingController external = TextEditingController();
    addTearDown(external.dispose);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DialogHost(
          child: ComposerShell(
            child: TextComposerSheet(
              controller: external,
              onSave: (String _) {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(EditableText), '## a heading');
    await tester.pump();

    expect(external.text, '## a heading');

    final EditableTextState state = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    final TextSpan painted = state.renderEditable.text! as TextSpan;

    expect(painted.toPlainText(includeSemanticsLabels: false), '## a heading');
    expect(painted.children, isNotNull);
    expect(painted.children!.first.style?.color, Palette.ink34);
  });

  testWidgets('the hint shows only while the note is empty',
      (WidgetTester tester) async {
    final _EditorHarness harness = _EditorHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app);

    expect(find.text('Start writing…'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'a word');
    await tester.pump();

    expect(find.text('Start writing…'), findsNothing);
  });
}
