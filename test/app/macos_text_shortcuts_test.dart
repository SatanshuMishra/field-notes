import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_controller.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_view.dart';

import 'support/app_shell_harness.dart';

Future<void> _pumpApp(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: shellOverrides(), child: const FieldNotesApp()),
  );
  await tester.pump();
  unawaited(
    Navigator.of(tester.element(find.byType(AppShell))).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) => Material(child: page),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<TextEditingController> _pumpField(
  WidgetTester tester,
  String text, {
  int caret = 0,
  int? maxLines = 1,
}) async {
  final TextEditingController controller = TextEditingController(text: text);
  final FocusNode focusNode = FocusNode();
  addTearDown(controller.dispose);
  addTearDown(focusNode.dispose);
  await _pumpApp(
    tester,
    TextField(controller: controller, focusNode: focusNode, maxLines: maxLines),
  );
  focusNode.requestFocus();
  await tester.pump();
  controller.selection = TextSelection.collapsed(offset: caret);
  await tester.pump();
  return controller;
}

Future<bool> _control(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
  bool alt = false,
}) async {
  final List<LogicalKeyboardKey> modifiers = <LogicalKeyboardKey>[
    LogicalKeyboardKey.controlLeft,
    if (alt) LogicalKeyboardKey.altLeft,
    if (shift) LogicalKeyboardKey.shiftLeft,
  ];
  for (final LogicalKeyboardKey modifier in modifiers) {
    await tester.sendKeyDownEvent(modifier);
  }
  final bool handled = await tester.sendKeyEvent(key);
  for (final LogicalKeyboardKey modifier in modifiers.reversed) {
    await tester.sendKeyUpEvent(modifier);
  }
  await tester.pump();
  return handled;
}

Future<void> _onMacOS(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  testWidgets('Ctrl+K in a stock field deletes to the line end on macOS', (
    WidgetTester tester,
  ) async {
    await _onMacOS(() async {
      final TextEditingController controller = await _pumpField(
        tester,
        'the quick fox',
        caret: 4,
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(controller.text, 'the ');
      expect(controller.selection, const TextSelection.collapsed(offset: 4));
    });
  });

  testWidgets('Ctrl+K is ignored while composing', (WidgetTester tester) async {
    await _onMacOS(() async {
      final TextEditingController controller = await _pumpField(
        tester,
        'the quick fox',
        caret: 4,
      );
      controller.value = controller.value.copyWith(
        composing: const TextRange(start: 4, end: 9),
      );
      await tester.pump();

      expect(await _control(tester, LogicalKeyboardKey.keyK), isFalse);
      expect(controller.text, 'the quick fox');

      controller.value = controller.value.copyWith(composing: TextRange.empty);
      await tester.pump();

      expect(await _control(tester, LogicalKeyboardKey.keyK), isTrue);
      expect(controller.text, 'the ');
    });
  });

  testWidgets('Ctrl+K at a line end deletes the line break in a stock field', (
    WidgetTester tester,
  ) async {
    await _onMacOS(() async {
      final TextEditingController controller = await _pumpField(
        tester,
        'the\nquick fox',
        caret: 3,
        maxLines: null,
      );

      await _control(tester, LogicalKeyboardKey.keyK);

      expect(controller.text, 'thequick fox');
      expect(controller.selection, const TextSelection.collapsed(offset: 3));
    });
  });

  testWidgets('Ctrl+Y in a stock field inserts what Ctrl+K cut', (
    WidgetTester tester,
  ) async {
    await _onMacOS(() async {
      final TextEditingController controller = await _pumpField(
        tester,
        'the quick fox',
        caret: 4,
      );

      await _control(tester, LogicalKeyboardKey.keyK);
      controller.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();
      await _control(tester, LogicalKeyboardKey.keyY);

      expect(controller.text, 'quick foxthe ');
      expect(controller.selection, const TextSelection.collapsed(offset: 9));
    });
  });

  testWidgets('Ctrl+O opens a line after the caret in a multi-line field', (
    WidgetTester tester,
  ) async {
    await _onMacOS(() async {
      final TextEditingController controller = await _pumpField(
        tester,
        'the quick fox',
        caret: 3,
        maxLines: null,
      );

      expect(await _control(tester, LogicalKeyboardKey.keyO), isTrue);

      expect(controller.text, 'the\n quick fox');
      expect(controller.selection, const TextSelection.collapsed(offset: 3));
    });
  });

  testWidgets('the Emacs selection keys move and extend in a stock field', (
    WidgetTester tester,
  ) async {
    await _onMacOS(() async {
      final TextEditingController controller = await _pumpField(
        tester,
        'the quick fox',
        caret: 4,
      );

      await _control(tester, LogicalKeyboardKey.keyF, shift: true);
      expect(
        controller.selection,
        const TextSelection(baseOffset: 4, extentOffset: 5),
      );

      await _control(tester, LogicalKeyboardKey.keyE, shift: true);
      expect(
        controller.selection,
        const TextSelection(baseOffset: 4, extentOffset: 13),
      );

      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();
      await _control(tester, LogicalKeyboardKey.keyB, shift: true);
      expect(
        controller.selection,
        const TextSelection(baseOffset: 4, extentOffset: 3),
      );

      await _control(tester, LogicalKeyboardKey.keyA, shift: true);
      expect(
        controller.selection,
        const TextSelection(baseOffset: 4, extentOffset: 0),
      );

      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();
      await _control(tester, LogicalKeyboardKey.keyF, alt: true);
      expect(controller.selection, const TextSelection.collapsed(offset: 9));

      await _control(tester, LogicalKeyboardKey.keyB, alt: true);
      expect(controller.selection, const TextSelection.collapsed(offset: 4));

      await _control(tester, LogicalKeyboardKey.keyV);
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.baseOffset, 13);
      expect(controller.text, 'the quick fox');
    });
  });

  testWidgets('the shortcuts are not installed on Android', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = await _pumpField(
      tester,
      'the quick fox',
      caret: 4,
    );

    expect(defaultTargetPlatform, TargetPlatform.android);
    expect(await _control(tester, LogicalKeyboardKey.keyK), isFalse);
    expect(await _control(tester, LogicalKeyboardKey.keyO), isFalse);

    expect(controller.text, 'the quick fox');
    expect(controller.selection, const TextSelection.collapsed(offset: 4));
  });

  testWidgets('the app layer leaves Ctrl+K to the note editor on macOS', (
    WidgetTester tester,
  ) async {
    await _onMacOS(() async {
      final NoteEditorController controller = NoteEditorController(
        text: 'alpha beta',
      );
      final FocusNode focusNode = FocusNode();
      final UndoHistoryController undo = UndoHistoryController();
      final ScrollController scroll = ScrollController();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      addTearDown(undo.dispose);
      addTearDown(scroll.dispose);
      await _pumpApp(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 688,
            height: 600,
            child: NoteEditorView(
              controller: controller,
              focusNode: focusNode,
              undoController: undo,
              scrollController: scroll,
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();
      controller.selection = const TextSelection.collapsed(offset: 3);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final bool handled = await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(handled, isFalse);
    });
  });
}
