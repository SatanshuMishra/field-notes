import 'dart:async';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/focus/keyboard_focus_builder.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_controller.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _deleteKey = ValueKey<String>('delete');
const Key _archiveKey = ValueKey<String>('archive');
const Key _keepKey = ValueKey<String>('keep');
const Key _outlineKey = ValueKey<String>('outline');
const Widget _face = SizedBox(width: 120, height: 48);

final TargetPlatformVariant _desktop = TargetPlatformVariant(<TargetPlatform>{
  TargetPlatform.macOS,
  TargetPlatform.windows,
});

final Finder _anyRing = find.byKey(focusRingKey);
final Finder _outline = find.byKey(_outlineKey);

FocusNode _focusNode(String label) {
  final FocusNode node = FocusNode(debugLabel: label);
  addTearDown(node.dispose);
  return node;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await _settle(tester);
}

Future<void> _click(WidgetTester tester, Finder target) async {
  await tester.tap(target, kind: PointerDeviceKind.mouse);
  await _settle(tester);
}

void _expectOnlyRingOn(Key owner) {
  expect(_anyRing, findsOneWidget);
  expect(
    find.descendant(of: find.byKey(owner), matching: _anyRing),
    findsOneWidget,
  );
}

class _DeleteFlow extends StatelessWidget {
  const _DeleteFlow({required this.keepFocus});

  final FocusNode keepFocus;

  void _confirm(BuildContext context) => unawaited(
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => Center(child: _keep(keepFocus)),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Pressable(
        key: _deleteKey,
        label: 'Delete',
        onPressed: () => _confirm(context),
        child: _face,
      ),
      const SizedBox(height: 24),
      Pressable(
        key: _archiveKey,
        label: 'Archive',
        onPressed: () {},
        child: _face,
      ),
    ],
  );
}

Widget _keep(FocusNode focusNode) => Pressable(
  key: _keepKey,
  label: 'Keep',
  autofocus: true,
  focusNode: focusNode,
  onPressed: () {},
  child: _face,
);

Future<void> _pumpApp(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await _settle(tester);
}

Future<FocusNode> _pumpDeleteFlow(WidgetTester tester) async {
  final FocusNode keepFocus = _focusNode('keep');
  await _pumpApp(tester, _DeleteFlow(keepFocus: keepFocus));
  return keepFocus;
}

Future<void> _pumpFieldBetweenButtons(
  WidgetTester tester,
  FocusNode field,
) async {
  final TextEditingController text = TextEditingController(text: 'abc');
  addTearDown(text.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: <Widget>[
            Pressable(
              key: _archiveKey,
              label: 'Archive',
              onPressed: () {},
              child: _face,
            ),
            KeyboardFocusBuilder(
              focusNode: field,
              builder: (BuildContext context, bool shown) => Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(focusNode: field, controller: text),
                  if (shown) const SizedBox(key: _outlineKey),
                ],
              ),
            ),
            Pressable(
              key: _deleteKey,
              label: 'Delete',
              onPressed: () {},
              child: _face,
            ),
          ],
        ),
      ),
    ),
  );
  await _settle(tester);
}

void main() {
  group('a ring around a button', () {
    testWidgets('never appears on an autofocused button opened by a click', (
      WidgetTester tester,
    ) async {
      final FocusNode keepFocus = await _pumpDeleteFlow(tester);

      await _click(tester, find.byKey(_deleteKey));
      await tester.pumpAndSettle();

      expect(keepFocus.hasPrimaryFocus, isTrue);
      expect(_anyRing, findsNothing);
    }, variant: _desktop);

    testWidgets('never appears on a button autofocused as a screen opens', (
      WidgetTester tester,
    ) async {
      final FocusNode keepFocus = _focusNode('keep');
      await _pumpApp(tester, _keep(keepFocus));

      expect(keepFocus.hasPrimaryFocus, isTrue);
      expect(_anyRing, findsNothing);
    }, variant: _desktop);

    testWidgets('appears exactly once under Tab and follows Shift+Tab back', (
      WidgetTester tester,
    ) async {
      await _pumpDeleteFlow(tester);

      await _press(tester, LogicalKeyboardKey.tab);
      _expectOnlyRingOn(_deleteKey);

      await _press(tester, LogicalKeyboardKey.tab);
      _expectOnlyRingOn(_archiveKey);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await _press(tester, LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await _settle(tester);
      _expectOnlyRingOn(_deleteKey);
    }, variant: _desktop);

    testWidgets('goes away when a letter is typed and returns on Tab', (
      WidgetTester tester,
    ) async {
      await _pumpDeleteFlow(tester);
      await _press(tester, LogicalKeyboardKey.tab);
      _expectOnlyRingOn(_deleteKey);

      await _press(tester, LogicalKeyboardKey.keyA);
      expect(_anyRing, findsNothing);

      await _press(tester, LogicalKeyboardKey.tab);
      _expectOnlyRingOn(_archiveKey);
    }, variant: _desktop);

    testWidgets('lands on the safe button after Enter on Delete', (
      WidgetTester tester,
    ) async {
      final FocusNode keepFocus = await _pumpDeleteFlow(tester);
      await _press(tester, LogicalKeyboardKey.tab);
      _expectOnlyRingOn(_deleteKey);

      await _press(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(keepFocus.hasPrimaryFocus, isTrue);
      _expectOnlyRingOn(_keepKey);
    }, variant: _desktop);

    testWidgets('stays through Space and Escape', (WidgetTester tester) async {
      await _pumpDeleteFlow(tester);
      await _press(tester, LogicalKeyboardKey.tab);
      await _press(tester, LogicalKeyboardKey.tab);
      _expectOnlyRingOn(_archiveKey);

      await _press(tester, LogicalKeyboardKey.space);
      _expectOnlyRingOn(_archiveKey);

      await _press(tester, LogicalKeyboardKey.escape);
      _expectOnlyRingOn(_archiveKey);
    }, variant: _desktop);

    testWidgets('goes away on a mouse press', (WidgetTester tester) async {
      await _pumpDeleteFlow(tester);
      await _press(tester, LogicalKeyboardKey.tab);
      _expectOnlyRingOn(_deleteKey);

      await _click(tester, find.byKey(_archiveKey));

      expect(_anyRing, findsNothing);
    }, variant: _desktop);

    testWidgets('stays when the mouse only moves', (WidgetTester tester) async {
      await _pumpDeleteFlow(tester);
      await _press(tester, LogicalKeyboardKey.tab);
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);

      await mouse.moveTo(tester.getCenter(find.byKey(_archiveKey)));
      await _settle(tester);

      _expectOnlyRingOn(_deleteKey);
    }, variant: _desktop);

    testWidgets('appears when an arrow key follows a click that opened it', (
      WidgetTester tester,
    ) async {
      await _pumpDeleteFlow(tester);
      await _click(tester, find.byKey(_deleteKey));
      await tester.pumpAndSettle();
      expect(_anyRing, findsNothing);

      await _press(tester, LogicalKeyboardKey.arrowUp);

      _expectOnlyRingOn(_keepKey);
    }, variant: _desktop);

    testWidgets('stays through a keyboard shortcut', (
      WidgetTester tester,
    ) async {
      await _pumpDeleteFlow(tester);
      await _press(tester, LogicalKeyboardKey.tab);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await _press(tester, LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await _settle(tester);

      _expectOnlyRingOn(_deleteKey);
    }, variant: _desktop);
  });

  group('the keyboard focus outline', () {
    testWidgets('stays off a clicked field while the caret moves', (
      WidgetTester tester,
    ) async {
      final FocusNode field = _focusNode('field');
      await _pumpFieldBetweenButtons(tester, field);

      await _click(tester, find.byType(TextField));
      expect(field.hasPrimaryFocus, isTrue);
      expect(_outline, findsNothing);

      await _press(tester, LogicalKeyboardKey.arrowLeft);

      expect(field.hasPrimaryFocus, isTrue);
      expect(_outline, findsNothing);
    }, variant: _desktop);

    testWidgets('appears when Tab reaches a field and goes as letters land', (
      WidgetTester tester,
    ) async {
      final FocusNode field = _focusNode('field');
      await _pumpFieldBetweenButtons(tester, field);

      await _press(tester, LogicalKeyboardKey.tab);
      _expectOnlyRingOn(_archiveKey);
      expect(_outline, findsNothing);

      await _press(tester, LogicalKeyboardKey.tab);
      expect(field.hasPrimaryFocus, isTrue);
      expect(_anyRing, findsNothing);
      expect(_outline, findsOneWidget);

      await _press(tester, LogicalKeyboardKey.keyA);
      expect(_outline, findsNothing);
    }, variant: _desktop);

    testWidgets('gives way to a ring when Tab leaves a clicked field', (
      WidgetTester tester,
    ) async {
      final FocusNode field = _focusNode('field');
      await _pumpFieldBetweenButtons(tester, field);
      await _click(tester, find.byType(TextField));

      await _press(tester, LogicalKeyboardKey.tab);

      expect(field.hasFocus, isFalse);
      expect(_outline, findsNothing);
      _expectOnlyRingOn(_deleteKey);
    }, variant: _desktop);

    testWidgets(
      'stays off the note editor while arrows move the caret and Tab indents',
      (WidgetTester tester) async {
        const String listNote = '- a\n- b';
        final FocusNode focus = _focusNode('note');
        final NoteEditorController controller = NoteEditorController(
          text: listNote,
        );
        final UndoHistoryController undo = UndoHistoryController();
        final ScrollController scroll = ScrollController();
        addTearDown(controller.dispose);
        addTearDown(undo.dispose);
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 688,
                  height: 600,
                  child: KeyboardFocusBuilder(
                    focusNode: focus,
                    builder: (BuildContext context, bool shown) => Stack(
                      children: <Widget>[
                        NoteEditorView(
                          controller: controller,
                          focusNode: focus,
                          undoController: undo,
                          scrollController: scroll,
                        ),
                        if (shown) const SizedBox(key: _outlineKey),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        focus.requestFocus();
        await _settle(tester);
        controller.selection = const TextSelection.collapsed(
          offset: listNote.length,
        );
        await _settle(tester);
        expect(focus.hasPrimaryFocus, isTrue);
        expect(_outline, findsNothing);

        await _press(tester, LogicalKeyboardKey.arrowLeft);
        expect(_outline, findsNothing);

        await _press(tester, LogicalKeyboardKey.tab);
        expect(controller.text, '- a\n  - b');
        expect(focus.hasPrimaryFocus, isTrue);
        expect(_outline, findsNothing);
      },
      variant: _desktop,
    );
  });
}
