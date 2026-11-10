import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/text/composer_footer.dart';
import 'package:field_notes/features/capture/text/editor/format_bar.dart';
import 'package:field_notes/features/capture/text/editor/note_editor.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteEditorController;

import '../../../../support/note_editor_driver.dart';

const Duration _pastUndoThrottle = Duration(milliseconds: 600);

const Duration _hold = Duration(milliseconds: 110);

const double _narrowBar = 340;

const TextEditingValue _helloSelected = TextEditingValue(
  text: 'hello world',
  selection: TextSelection(baseOffset: 0, extentOffset: 5),
);

const List<Key> _everyItem = <Key>[
  formatBoldKey,
  formatItalicKey,
  formatHeadingKey,
  formatStrikethroughKey,
  formatHighlightKey,
  formatCodeKey,
  formatListKey,
  formatNumberedKey,
  formatTaskKey,
  formatQuoteKey,
  formatLinkKey,
  formatTableKey,
  composerAddPhotoKey,
  formatUndoKey,
  formatRedoKey,
];

Future<void> _pumpApp(WidgetTester tester, Widget app) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(app);
}

Future<void> _press(WidgetTester tester, Key key) =>
    NoteEditorDriver(tester).press(find.byKey(key), _hold);

class _Harness {
  _Harness({this.tablesAvailable = true, this.barWidth, this.onAddPhoto})
    : controller = NoteEditorController(),
      undoController = UndoHistoryController(),
      focusNode = FocusNode(),
      scrollController = ScrollController();

  final NoteEditorController controller;
  final UndoHistoryController undoController;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final bool tablesAvailable;
  final double? barWidth;
  final VoidCallback? onAddPhoto;

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
          SizedBox(
            width: barWidth,
            child: FormatBar(
              controller: controller,
              undoController: undoController,
              tablesAvailable: tablesAvailable,
              editorFocusNode: focusNode,
              onAddPhoto: onAddPhoto,
            ),
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
  (key: formatStrikethroughKey, expected: '~~hello~~ world'),
  (key: formatHighlightKey, expected: '==hello== world'),
  (key: formatCodeKey, expected: '`hello` world'),
  (key: formatListKey, expected: '- hello world'),
  (key: formatQuoteKey, expected: '> hello world'),
  (key: formatLinkKey, expected: '[hello]() world'),
];

void main() {
  for (final BarCase barCase in _barCases) {
    testWidgets('${barCase.key} rewrites the buffer at the selection', (
      WidgetTester tester,
    ) async {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);
      await _pumpApp(tester, harness.app);

      harness.controller.value = _helloSelected;
      await tester.pump();

      await _press(tester, barCase.key);
      await tester.pump();

      expect(harness.controller.text, barCase.expected);
    });
  }

  testWidgets('a second tap on the same control removes the markers again', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    await _pumpApp(tester, harness.app);

    harness.controller.value = _helloSelected;
    await tester.pump();

    await _press(tester, formatBoldKey);
    await tester.pump();
    expect(harness.controller.text, '**hello** world');

    await _press(tester, formatBoldKey);
    await tester.pump();
    expect(harness.controller.text, 'hello world');
  });

  testWidgets('the undo control restores the previous value with no keyboard', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    await _pumpApp(tester, harness.app);

    await NoteEditorDriver(tester).enterText('hello world');
    await tester.pump(_pastUndoThrottle);

    harness.controller.value = _helloSelected;
    await tester.pump();
    await _press(tester, formatBoldKey);
    await tester.pump(_pastUndoThrottle);
    expect(harness.controller.text, '**hello** world');

    await _press(tester, formatUndoKey);
    await tester.pump();

    expect(harness.controller.text, 'hello world');
  });

  testWidgets('the undo control is disabled until there is history', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    await _pumpApp(tester, harness.app);
    await tester.pump(_pastUndoThrottle);

    expect(harness.undoController.value.canUndo, isFalse);
    expect(
      tester.getSemantics(find.byKey(formatUndoKey)),
      isSemantics(isEnabled: false),
    );

    await NoteEditorDriver(tester).enterText('something');
    await tester.pump(_pastUndoThrottle);
    await NoteEditorDriver(tester).enterText('something more');
    await tester.pump(_pastUndoThrottle);

    expect(harness.undoController.value.canUndo, isTrue);
    expect(
      tester.getSemantics(find.byKey(formatUndoKey)),
      isSemantics(isEnabled: true),
    );
  });

  testWidgets('a bar tap keeps the editor focused and the selection intact', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    await _pumpApp(tester, harness.app);

    harness.focusNode.requestFocus();
    await tester.pump();
    harness.controller.value = _helloSelected;
    await tester.pump();
    expect(harness.focusNode.hasFocus, isTrue);

    await NoteEditorDriver(tester)
        .press(find.byKey(formatBoldKey), _hold, kind: PointerDeviceKind.mouse);
    await tester.pump();

    expect(harness.focusNode.hasFocus, isTrue);
    expect(harness.controller.selection.isCollapsed, isFalse);
    expect(harness.controller.selection.start, 2);
    expect(harness.controller.selection.end, 7);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('every item sits in the row at a wide width, in order, with '
      'separators and no More', (WidgetTester tester) async {
    final _Harness harness = _Harness(onAddPhoto: () {});
    addTearDown(harness.dispose);
    await _pumpApp(tester, harness.app);

    expect(find.byKey(formatMoreKey), findsNothing);
    expect(find.byKey(formatBarSeparatorKey), findsNWidgets(3));
    double previous = 0;
    for (final Key key in _everyItem) {
      expect(find.byKey(key), findsOneWidget, reason: '$key');
      final double left = tester.getTopLeft(find.byKey(key)).dx;
      expect(left, greaterThan(previous), reason: '$key');
      previous = left;
    }
  });

  testWidgets('a bar that fits only without separators drops them first', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness(
      onAddPhoto: () {},
      barWidth: _everyItem.length * 48,
    );
    addTearDown(harness.dispose);
    await _pumpApp(tester, harness.app);

    expect(find.byKey(formatMoreKey), findsNothing);
    expect(find.byKey(formatBarSeparatorKey), findsNothing);
    for (final Key key in _everyItem) {
      expect(find.byKey(key), findsOneWidget, reason: '$key');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow bar moves only what does not fit into More, in order', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness(onAddPhoto: () {}, barWidth: _narrowBar);
    addTearDown(harness.dispose);
    await _pumpApp(tester, harness.app);

    expect(tester.takeException(), isNull);
    const int shown = 6;
    for (final Key key in _everyItem.take(shown)) {
      expect(find.byKey(key), findsOneWidget, reason: '$key');
    }
    for (final Key key in _everyItem.skip(shown)) {
      expect(find.byKey(key), findsNothing, reason: '$key');
    }

    await _press(tester, formatMoreKey);
    await tester.pump();

    double previous = 0;
    for (final Key key in _everyItem.skip(shown)) {
      expect(find.byKey(key), findsOneWidget, reason: '$key');
      final double top = tester.getTopLeft(find.byKey(key)).dy;
      expect(top, greaterThan(previous), reason: '$key');
      previous = top;
    }
  });

  testWidgets('the fit follows the width the bar is given, not the window', (
    WidgetTester tester,
  ) async {
    for (final ({double width, bool fits}) size
        in <({double width, bool fits})>[
          (width: 900, fits: true),
          (width: 700, fits: false),
        ]) {
      final _Harness harness = _Harness(
        onAddPhoto: () {},
        barWidth: size.width,
      );
      addTearDown(harness.dispose);
      await _pumpApp(tester, harness.app);

      expect(
        find.byKey(formatMoreKey),
        size.fits ? findsNothing : findsOneWidget,
        reason: '${size.width}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('a format chosen from More runs and closes the menu', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness(barWidth: _narrowBar);
    addTearDown(harness.dispose);
    await _pumpApp(tester, harness.app);
    harness.focusNode.requestFocus();
    await tester.pump();

    harness.controller.value = _helloSelected;
    await tester.pump();
    await _press(tester, formatMoreKey);
    await tester.pump();
    expect(find.byKey(formatQuoteKey), findsOneWidget);
    expect(harness.focusNode.hasFocus, isTrue);

    await _press(tester, formatQuoteKey);
    await tester.pump();

    expect(harness.controller.text, '> hello world');
    expect(find.byKey(formatQuoteKey), findsNothing);
    expect(harness.focusNode.hasFocus, isTrue);
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
    expect(
      table.controller.selection,
      const TextSelection.collapsed(offset: 2),
    );
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
      formatStrikethroughKey,
      formatHighlightKey,
      formatCodeKey,
      formatListKey,
      formatNumberedKey,
      formatTaskKey,
      formatQuoteKey,
      formatLinkKey,
      formatTableKey,
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
    final _Harness harness = _Harness(barWidth: _narrowBar);
    addTearDown(harness.dispose);
    await _pumpApp(tester, harness.app);
    harness.controller.value = _helloSelected;
    await tester.pump();

    await _press(tester, formatMoreKey);
    await tester.pumpAndSettle();
    expect(find.byKey(formatQuoteKey), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);

    final TestGesture outside = await tester.startGesture(
      const Offset(600, 1500),
    );
    await tester.pump(_hold);
    await outside.up();
    await tester.pumpAndSettle();

    expect(find.byKey(formatQuoteKey), findsNothing);
    expect(harness.controller.text, 'hello world');

    await _press(tester, formatMoreKey);
    expect(find.byKey(formatQuoteKey), findsOneWidget);
    await _press(tester, formatMoreKey);
    expect(find.byKey(formatQuoteKey), findsNothing);
    expect(harness.controller.text, 'hello world');
  });

  testWidgets('each control meets the platform target', (
    WidgetTester tester,
  ) async {
    for (final ({TargetPlatform platform, double extent}) target
        in <({TargetPlatform platform, double extent})>[
          (platform: TargetPlatform.macOS, extent: 32),
          (platform: TargetPlatform.windows, extent: 40),
          (platform: TargetPlatform.android, extent: 48),
        ]) {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: target.platform),
          home: Scaffold(
            body: FormatBar(
              controller: harness.controller,
              undoController: harness.undoController,
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byKey(formatBoldKey)),
        Size.square(target.extent),
        reason: '${target.platform}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  group('where the composer mounts the bar', () {
    Future<void> pumpComposer(
      WidgetTester tester, {
      required Size surface,
      double keyboardInset = 0,
      TargetPlatform platform = TargetPlatform.android,
    }) async {
      tester.view.physicalSize = surface;
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(platform: platform),
          home: DialogHost(
            child: ComposerShell(
              responsive: true,
              child: TextComposerSheet(onSave: (String _) {}, onCancel: () {}),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('it heads the page in the room', (WidgetTester tester) async {
      await pumpComposer(
        tester,
        surface: const Size(1280, 900),
        platform: TargetPlatform.macOS,
      );

      expect(find.byType(FormatBar), findsOneWidget);
      expect(
        tester.getRect(find.byType(FormatBar)).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(RawScrollbar)).top),
      );
      expect(find.byKey(formatMoreKey), findsNothing);
    });

    testWidgets('a phone width tucks the rest into More', (
      WidgetTester tester,
    ) async {
      await pumpComposer(tester, surface: const Size(390, 844));

      expect(find.byKey(formatBoldKey), findsOneWidget);
      expect(find.byKey(formatCodeKey), findsOneWidget);
      expect(find.byKey(formatMoreKey), findsOneWidget);
    });

    testWidgets('a strip layout keeps the bar above the page', (
      WidgetTester tester,
    ) async {
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
      expect(find.byKey(formatMoreKey), findsOneWidget);
      expect(NoteEditorDriver(tester).find, findsOneWidget);
    });
  });
}
