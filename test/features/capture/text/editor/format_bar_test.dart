import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/text/editor/format_bar.dart';
import 'package:field_notes/features/capture/text/editor/note_editor.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteEditorController;

import '../../../../support/note_editor_driver.dart';

const Duration _pastUndoThrottle = Duration(milliseconds: 600);

const Duration _hold = Duration(milliseconds: 110);

const TextEditingValue _helloSelected = TextEditingValue(
  text: 'hello world',
  selection: TextSelection(baseOffset: 0, extentOffset: 5),
);

Future<void> _pumpApp(WidgetTester tester, Widget app) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(app);
}

Future<void> _press(WidgetTester tester, Key key) =>
    NoteEditorDriver(tester).press(find.byKey(key), _hold);


class _Harness {
  _Harness({this.tablesAvailable = true})
      : controller = NoteEditorController(),
        undoController = UndoHistoryController(),
        focusNode = FocusNode(),
        scrollController = ScrollController();

  final NoteEditorController controller;
  final UndoHistoryController undoController;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final bool tablesAvailable;

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
                tablesAvailable: tablesAvailable,
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
  (key: formatItalicKey, expected: '*hello* world'),
  (key: formatHeadingKey, expected: '# hello world'),
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
      await _pumpApp(tester, harness.app);

      harness.controller.value = const TextEditingValue(
        text: 'hello world',
        selection: TextSelection(baseOffset: 0, extentOffset: 5),
      );
      await tester.pump();

      await _press(tester, barCase.key);
      await tester.pump();

      expect(harness.controller.text, barCase.expected);
    });
  }

  testWidgets('a second tap on the same control removes the markers again',
      (WidgetTester tester) async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    await _pumpApp(tester, harness.app);

    harness.controller.value = const TextEditingValue(
      text: 'hello world',
      selection: TextSelection(baseOffset: 0, extentOffset: 5),
    );
    await tester.pump();

    await _press(tester, formatBoldKey);
    await tester.pump();
    expect(harness.controller.text, '**hello** world');

    await _press(tester, formatBoldKey);
    await tester.pump();
    expect(harness.controller.text, 'hello world');
  });

  testWidgets('the undo control restores the previous value with no keyboard',
      (WidgetTester tester) async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    await _pumpApp(tester, harness.app);

    await NoteEditorDriver(tester).enterText('hello world');
    await tester.pump(_pastUndoThrottle);

    harness.controller.value = const TextEditingValue(
      text: 'hello world',
      selection: TextSelection(baseOffset: 0, extentOffset: 5),
    );
    await tester.pump();
    await _press(tester, formatBoldKey);
    await tester.pump(_pastUndoThrottle);
    expect(harness.controller.text, '**hello** world');

    await _press(tester, formatUndoKey);
    await tester.pump();

    expect(harness.controller.text, 'hello world');
  });

  testWidgets('the undo control is disabled until there is history',
      (WidgetTester tester) async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    await _pumpApp(tester, harness.app);
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

    await NoteEditorDriver(tester).enterText('something');
    await tester.pump(_pastUndoThrottle);
    await NoteEditorDriver(tester).enterText('something more');
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
    await _pumpApp(tester, harness.app);

    harness.focusNode.requestFocus();
    await tester.pump();
    harness.controller.value = const TextEditingValue(
      text: 'hello world',
      selection: TextSelection(baseOffset: 0, extentOffset: 5),
    );
    await tester.pump();
    expect(harness.focusNode.hasFocus, isTrue);

    await NoteEditorDriver(tester).press(
      find.byKey(formatBoldKey),
      _hold,
      kind: PointerDeviceKind.mouse,
    );
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
            tablesAvailable: true,
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
              width: 340,
              child: FormatBar(
                controller: harness.controller,
                undoController: harness.undoController,
                tablesAvailable: true,
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
    await tester.drag(find.byKey(formatBoldKey), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(formatLinkKey)).right,
      lessThanOrEqualTo(trailing.left),
    );
    expect(tester.getRect(find.byKey(formatUndoKey)), undo);
    expect(tester.getRect(find.byKey(trailingKey)), trailing);

    await _press(tester, formatLinkKey);
    await tester.pump();
    expect(harness.controller.text, '[hello]() world');
  });

  testWidgets('italic wraps with single stars', (WidgetTester tester) async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    await _pumpApp(tester, harness.app);
    harness.controller.value = _helloSelected;
    await tester.pump();

    await _press(tester, formatItalicKey);

    expect(harness.controller.text, '*hello* world');
    expect(
      harness.controller.selection,
      const TextSelection(baseOffset: 1, extentOffset: 6),
    );
  });

  testWidgets('the bar offers numbered list, task list and table buttons', (
    WidgetTester tester,
  ) async {
    const TextEditingValue caretAtStart = TextEditingValue(
      text: 'hello world',
      selection: TextSelection.collapsed(offset: 0),
    );
    final _Harness numbered = _Harness();
    addTearDown(numbered.dispose);
    await _pumpApp(tester, numbered.app);

    expect(find.byKey(formatNumberedKey), findsOneWidget);
    expect(find.byKey(formatTaskKey), findsOneWidget);
    expect(find.byKey(formatTableKey), findsOneWidget);
    expect(find.bySemanticsLabel('Numbered list'), findsOneWidget);
    expect(find.bySemanticsLabel('Task list'), findsOneWidget);
    expect(find.bySemanticsLabel('Table'), findsOneWidget);

    numbered.controller.value = caretAtStart;
    await tester.pump();
    await _press(tester, formatNumberedKey);
    expect(numbered.controller.text, '1. hello world');

    final _Harness task = _Harness();
    addTearDown(task.dispose);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpApp(tester, task.app);
    task.controller.value = caretAtStart;
    await tester.pump();
    await _press(tester, formatTaskKey);
    expect(task.controller.text, '- [ ] hello world');

    final _Harness table = _Harness();
    addTearDown(table.dispose);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpApp(tester, table.app);
    await _press(tester, formatTableKey);
    expect(
      table.controller.text,
      '|  |  |  |\n| --- | --- | --- |\n|  |  |  |',
    );
    expect(table.controller.selection, const TextSelection.collapsed(offset: 2));
  });

  testWidgets('more formats holds strikethrough, highlight and inline code', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    await _pumpApp(tester, harness.app);
    harness.focusNode.requestFocus();
    await tester.pump();

    const List<({Key key, String expected})> items =
        <({Key key, String expected})>[
          (key: formatStrikethroughKey, expected: '~~hello~~ world'),
          (key: formatHighlightKey, expected: '==hello== world'),
          (key: formatCodeKey, expected: '`hello` world'),
        ];
    for (final ({Key key, String expected}) item in items) {
      harness.controller.value = _helloSelected;
      await tester.pump();
      await _press(tester, formatMoreKey);
      expect(find.byKey(formatStrikethroughKey), findsOneWidget);
      expect(find.byKey(formatHighlightKey), findsOneWidget);
      expect(find.byKey(formatCodeKey), findsOneWidget);
      expect(harness.focusNode.hasFocus, isTrue);

      await _press(tester, item.key);

      expect(harness.controller.text, item.expected);
      expect(find.byKey(formatStrikethroughKey), findsNothing);
      expect(find.byKey(formatHighlightKey), findsNothing);
      expect(find.byKey(formatCodeKey), findsNothing);
      expect(harness.focusNode.hasFocus, isTrue);
    }
  });

  testWidgets('the table button is absent when tables are unavailable', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness(tablesAvailable: false);
    addTearDown(harness.dispose);
    await _pumpApp(tester, harness.app);

    expect(find.byKey(formatTableKey), findsNothing);
    for (final Key key in <Key>[
      formatBoldKey,
      formatItalicKey,
      formatHeadingKey,
      formatListKey,
      formatNumberedKey,
      formatTaskKey,
      formatQuoteKey,
      formatLinkKey,
      formatMoreKey,
      formatUndoKey,
    ]) {
      expect(find.byKey(key), findsOneWidget);
    }
  });

  testWidgets('the heading control cycles one to three and back to plain', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    await _pumpApp(tester, harness.app);
    harness.controller.value = const TextEditingValue(
      text: 'hello',
      selection: TextSelection.collapsed(offset: 0),
    );
    await tester.pump();

    for (final String expected in <String>[
      '# hello',
      '## hello',
      '### hello',
      'hello',
    ]) {
      await _press(tester, formatHeadingKey);
      expect(harness.controller.text, expected);
    }

    harness.controller.value = const TextEditingValue(
      text: '#### x',
      selection: TextSelection.collapsed(offset: 5),
    );
    await tester.pump();
    await _press(tester, formatHeadingKey);
    expect(harness.controller.text, 'x');
  });

  testWidgets('a bar on a plain controller disables every format control', (
    WidgetTester tester,
  ) async {
    final TextEditingController plain = TextEditingController(text: 'hello');
    final UndoHistoryController undo = UndoHistoryController();
    addTearDown(plain.dispose);
    addTearDown(undo.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormatBar(
            controller: plain,
            undoController: undo,
            tablesAvailable: true,
          ),
        ),
      ),
    );

    for (final Key key in <Key>[
      formatBoldKey,
      formatItalicKey,
      formatHeadingKey,
      formatListKey,
      formatNumberedKey,
      formatTaskKey,
      formatQuoteKey,
      formatLinkKey,
      formatTableKey,
      formatMoreKey,
    ]) {
      expect(
        tester.getSemantics(find.byKey(key)),
        isSemantics(isEnabled: false),
        reason: '$key',
      );
    }

    await _press(tester, formatBoldKey);

    expect(plain.text, 'hello');
  });

  testWidgets('a press outside the open menu closes it and changes nothing', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    await _pumpApp(tester, harness.app);
    harness.controller.value = _helloSelected;
    await tester.pump();

    await _press(tester, formatMoreKey);
    await tester.pumpAndSettle();
    expect(find.byKey(formatHighlightKey), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);

    final TestGesture outside = await tester.startGesture(
      const Offset(600, 1500),
    );
    await tester.pump(_hold);
    await outside.up();
    await tester.pumpAndSettle();

    expect(find.byKey(formatHighlightKey), findsNothing);
    expect(harness.controller.text, 'hello world');

    await _press(tester, formatMoreKey);
    expect(find.byKey(formatHighlightKey), findsOneWidget);
    await _press(tester, formatMoreKey);
    expect(find.byKey(formatHighlightKey), findsNothing);
    expect(harness.controller.text, 'hello world');
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
      expect(NoteEditorDriver(tester).find, findsOneWidget);
    });
  });
}
