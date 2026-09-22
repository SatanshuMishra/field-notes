import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/text/editor/editor.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';

const Duration _pastUndoThrottle = Duration(milliseconds: 600);

class _Harness {
  _Harness()
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
              FormatBar(
                controller: controller,
                undoController: undoController,
              ),
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

typedef BarCase = ({Key key, String expected});

const List<BarCase> _barCases = <BarCase>[
  (key: formatBoldKey, expected: '**hello** world'),
  (key: formatItalicKey, expected: '_hello_ world'),
  (key: formatHeadingKey, expected: '## hello world'),
  (key: formatListKey, expected: '- hello world'),
  (key: formatQuoteKey, expected: '> hello world'),
  (key: formatLinkKey, expected: '[hello]() world'),
];

void main() {
  for (final BarCase barCase in _barCases) {
    testWidgets('${barCase.key} rewrites the buffer at the selection',
        (WidgetTester tester) async {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.app);

      harness.controller.value = const TextEditingValue(
        text: 'hello world',
        selection: TextSelection(baseOffset: 0, extentOffset: 5),
      );
      await tester.pump();

      await tester.tap(find.byKey(barCase.key));
      await tester.pump();

      expect(harness.controller.text, barCase.expected);
    });
  }

  testWidgets('a second tap on the same control removes the markers again',
      (WidgetTester tester) async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app);

    harness.controller.value = const TextEditingValue(
      text: 'hello world',
      selection: TextSelection(baseOffset: 0, extentOffset: 5),
    );
    await tester.pump();

    await tester.tap(find.byKey(formatBoldKey));
    await tester.pump();
    expect(harness.controller.text, '**hello** world');

    await tester.tap(find.byKey(formatBoldKey));
    await tester.pump();
    expect(harness.controller.text, 'hello world');
  });

  testWidgets('the undo control restores the previous value with no keyboard',
      (WidgetTester tester) async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app);

    await tester.enterText(find.byType(EditableText), 'hello world');
    await tester.pump(_pastUndoThrottle);

    harness.controller.value = const TextEditingValue(
      text: 'hello world',
      selection: TextSelection(baseOffset: 0, extentOffset: 5),
    );
    await tester.pump();
    await tester.tap(find.byKey(formatBoldKey));
    await tester.pump(_pastUndoThrottle);
    expect(harness.controller.text, '**hello** world');

    await tester.tap(find.byKey(formatUndoKey));
    await tester.pump();

    expect(harness.controller.text, 'hello world');
  });

  testWidgets('the undo control is disabled until there is history',
      (WidgetTester tester) async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app);
    await tester.pump(_pastUndoThrottle);

    expect(harness.undoController.value.canUndo, isFalse);
    final Semantics disabled = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byKey(formatUndoKey),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(disabled.properties.enabled, isFalse);

    await tester.enterText(find.byType(EditableText), 'something');
    await tester.pump(_pastUndoThrottle);
    await tester.enterText(find.byType(EditableText), 'something more');
    await tester.pump(_pastUndoThrottle);

    expect(harness.undoController.value.canUndo, isTrue);
    final Semantics enabled = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byKey(formatUndoKey),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(enabled.properties.enabled, isTrue);
  });

  testWidgets('a bar tap keeps the editor focused and the selection intact',
      (WidgetTester tester) async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app);

    harness.focusNode.requestFocus();
    await tester.pump();
    harness.controller.value = const TextEditingValue(
      text: 'hello world',
      selection: TextSelection(baseOffset: 0, extentOffset: 5),
    );
    await tester.pump();
    expect(harness.focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(formatBoldKey));
    await tester.pump();

    expect(harness.focusNode.hasFocus, isTrue);
    expect(harness.controller.selection.isCollapsed, isFalse);
    expect(harness.controller.selection.start, 2);
    expect(harness.controller.selection.end, 7);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('the bar exposes a trailing slot for later capture affordances',
      (WidgetTester tester) async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormatBar(
            controller: harness.controller,
            undoController: harness.undoController,
            trailing: const SizedBox.square(
              dimension: 30,
              key: ValueKey<String>('trailing-slot'),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('trailing-slot')), findsOneWidget);
  });

  testWidgets(
      'a bar narrower than its toggles scrolls them while Undo and the '
      'trailing slot stay put', (WidgetTester tester) async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    const Key trailingKey = ValueKey<String>('trailing-slot');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 160,
              child: FormatBar(
                controller: harness.controller,
                undoController: harness.undoController,
                trailing: const SizedBox.square(
                  dimension: 30,
                  key: trailingKey,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final Rect bar = tester.getRect(find.byType(FormatBar));
    final Rect undo = tester.getRect(find.byKey(formatUndoKey));
    final Rect trailing = tester.getRect(find.byKey(trailingKey));
    expect(bar.intersect(undo), undo);
    expect(bar.intersect(trailing), trailing);
    expect(
      tester.getRect(find.byKey(formatLinkKey)).left,
      greaterThan(trailing.left),
    );

    harness.controller.value = const TextEditingValue(
      text: 'hello world',
      selection: TextSelection(baseOffset: 0, extentOffset: 5),
    );
    await tester.drag(find.byKey(formatBoldKey), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(formatLinkKey)).right,
      lessThanOrEqualTo(trailing.left),
    );
    expect(tester.getRect(find.byKey(formatUndoKey)), undo);
    expect(tester.getRect(find.byKey(trailingKey)), trailing);

    await tester.tap(find.byKey(formatLinkKey));
    await tester.pump();
    expect(harness.controller.text, '[hello]() world');
  });

  group('where the composer mounts the bar', () {
    Future<void> pumpComposer(
      WidgetTester tester, {
      required Size surface,
      double keyboardInset = 0,
    }) async {
      tester.view.physicalSize = surface;
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
      addTearDown(tester.view.reset);
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

    testWidgets('the compact shell puts it on the keyboard side of the paper',
        (WidgetTester tester) async {
      await pumpComposer(tester, surface: const Size(360, 640));

      expect(find.byType(FormatBar), findsOneWidget);
      expect(
        tester.getRect(find.byType(FormatBar)).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(RawScrollbar)).bottom),
      );
    });

    testWidgets(
      'the desktop shell puts it in the composer header',
      (WidgetTester tester) async {
        await pumpComposer(tester, surface: const Size(1280, 900));

        expect(find.byType(FormatBar), findsOneWidget);
        expect(
          tester.getRect(find.byType(FormatBar)).bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(RawScrollbar)).top),
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
        'a panel too short for the bar row moves the bar into the header and keeps Undo',
        (WidgetTester tester) async {
      await pumpComposer(
        tester,
        surface: const Size(844, 390),
        keyboardInset: 200,
      );

      expect(find.byType(FormatBar), findsOneWidget);
      final Rect bar = tester.getRect(find.byType(FormatBar));
      expect(
        bar.bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(RawScrollbar)).top),
      );
      expect(find.byKey(formatUndoKey), findsOneWidget);
      final Rect undo = tester.getRect(find.byKey(formatUndoKey));
      expect(bar.intersect(undo), undo);
      expect(find.text('Write a note'), findsNothing);
      expect(find.byType(EditableText), findsOneWidget);
    });
  });
}
