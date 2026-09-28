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
import 'package:field_notes/features/search/search_field.dart';

import '../support/note_editor_driver.dart';
import 'support/app_shell_harness.dart';

final class _Menus {
  _Menus(this.tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.menu,
      (MethodCall call) async {
        if (call.method == 'Menu.setMenus') {
          payloads.add(call.arguments! as Map<Object?, Object?>);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.menu,
        null,
      ),
    );
  }

  final WidgetTester tester;
  final List<Map<Object?, Object?>> payloads = <Map<Object?, Object?>>[];

  static List<Map<Object?, Object?>> _entries(Object? list) =>
      <Map<Object?, Object?>>[
        for (final Object? entry in list as List<Object?>? ?? const <Object?>[])
          entry! as Map<Object?, Object?>,
      ];

  List<Map<Object?, Object?>> get topLevel => _entries(payloads.last['0']);

  List<int?> providedIn(String menu) => <int?>[
    for (final Map<Object?, Object?> entry in _entries(item(menu)['children']))
      if (entry['isDivider'] != true) entry['platformProvidedMenu'] as int?,
  ];

  Map<Object?, Object?> item(String label) {
    Map<Object?, Object?>? search(List<Map<Object?, Object?>> entries) {
      for (final Map<Object?, Object?> entry in entries) {
        if (entry['label'] == label) {
          return entry;
        }
        final Map<Object?, Object?>? found = search(
          _entries(entry['children']),
        );
        if (found != null) {
          return found;
        }
      }
      return null;
    }

    return search(topLevel) ??
        (throw StateError('The menu bar has no item labelled $label'));
  }

  bool enabled(String label) => item(label)['enabled']! as bool;

  Future<void> select(String label) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.menu.name,
      SystemChannels.menu.codec.encodeMethodCall(
        MethodCall('Menu.selectedCallback', item(label)['id']),
      ),
      (ByteData? _) {},
    );
    await tester.pump();
    await tester.pump();
  }
}

void _clipboardHolds(WidgetTester tester, String text) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async => switch (call.method) {
      'Clipboard.getData' => <String, Object?>{'text': text},
      'Clipboard.hasStrings' => <String, Object?>{'value': true},
      _ => null,
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

final class _Editor {
  _Editor(String text)
    : controller = NoteEditorController(text: text),
      focusNode = FocusNode(),
      undo = UndoHistoryController(),
      scroll = ScrollController();

  final NoteEditorController controller;
  final FocusNode focusNode;
  final UndoHistoryController undo;
  final ScrollController scroll;

  Widget get view => Align(
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
  );

  void dispose() {
    scroll.dispose();
    undo.dispose();
    focusNode.dispose();
    controller.dispose();
  }
}

Future<void> _pumpApp(WidgetTester tester, {Widget? page}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: shellOverrides(), child: const FieldNotesApp()),
  );
  await tester.pump();
  if (page != null) {
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
  }
  await tester.pump();
  await tester.pump();
}

Future<_Editor> _pumpEditor(WidgetTester tester, String text) async {
  final _Editor editor = _Editor(text);
  addTearDown(editor.dispose);
  await _pumpApp(tester, page: editor.view);
  return editor;
}

Future<void> _focus(WidgetTester tester, _Editor editor) async {
  editor.focusNode.requestFocus();
  await tester.pump();
  await tester.pump();
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
  testWidgets('the Edit menu pastes into the focused note editor', (
    WidgetTester tester,
  ) async {
    await _onMacOS(() async {
      final _Menus menus = _Menus(tester);
      _clipboardHolds(tester, 'pasted');
      await _pumpEditor(tester, '');
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await driver.enterText('fog ');

      expect(menus.enabled('Paste'), isTrue);
      await menus.select('Paste');

      expect(driver.source, contains('pasted'));
      expect(driver.source, 'fog pasted');
    });
  });

  testWidgets('Undo is disabled with no history and enabled after an edit', (
    WidgetTester tester,
  ) async {
    await _onMacOS(() async {
      final _Menus menus = _Menus(tester);
      final _Editor editor = await _pumpEditor(tester, 'fog');
      await _focus(tester, editor);

      expect(menus.enabled('Undo'), isFalse);
      expect(menus.enabled('Redo'), isFalse);

      await NoteEditorDriver(tester).typeText('s');

      expect(editor.controller.text, 'fogs');
      expect(menus.enabled('Undo'), isTrue);
      expect(menus.enabled('Redo'), isFalse);

      await menus.select('Undo');

      expect(editor.controller.text, 'fog');
      expect(menus.enabled('Undo'), isFalse);
      expect(menus.enabled('Redo'), isTrue);

      await menus.select('Redo');

      expect(editor.controller.text, 'fogs');
    });
  });

  testWidgets("Select All selects the focused search field's text", (
    WidgetTester tester,
  ) async {
    await _onMacOS(() async {
      final _Menus menus = _Menus(tester);
      await _pumpApp(tester, page: const SearchField());
      await tester.enterText(find.byType(SearchField), 'rain');
      await tester.pump();

      final TextEditingController controller = tester
          .widget<EditableText>(
            find.descendant(
              of: find.byType(SearchField),
              matching: find.byType(EditableText),
            ),
          )
          .controller;
      expect(controller.selection, const TextSelection.collapsed(offset: 4));
      expect(menus.enabled('Select All'), isTrue);
      expect(menus.enabled('Copy'), isFalse);

      await menus.select('Select All');

      expect(controller.text, 'rain');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 4),
      );
      expect(menus.enabled('Copy'), isTrue);
    });
  });

  testWidgets('Copy is enabled when the note editor has a selection', (
    WidgetTester tester,
  ) async {
    await _onMacOS(() async {
      final _Menus menus = _Menus(tester);
      final _Editor editor = await _pumpEditor(tester, 'fog lifted');
      await _focus(tester, editor);
      final NoteEditorDriver driver = NoteEditorDriver(tester);

      await driver.setSelection(
        const TextSelection(baseOffset: 0, extentOffset: 3),
      );
      await tester.pump();

      expect(menus.enabled('Copy'), isTrue);
      expect(menus.enabled('Cut'), isTrue);

      await driver.setSelection(const TextSelection.collapsed(offset: 3));
      await tester.pump();

      expect(menus.enabled('Copy'), isFalse);
      expect(menus.enabled('Cut'), isFalse);
      expect(menus.enabled('Paste'), isTrue);
    });
  });

  testWidgets('every Edit item is disabled when no text field has focus', (
    WidgetTester tester,
  ) async {
    await _onMacOS(() async {
      final _Menus menus = _Menus(tester);
      final _Editor editor = await _pumpEditor(tester, 'fog');
      await _focus(tester, editor);
      expect(menus.enabled('Select All'), isTrue);

      editor.focusNode.unfocus();
      await tester.pump();
      await tester.pump();

      for (final String label in <String>[
        'Undo',
        'Redo',
        'Cut',
        'Copy',
        'Paste',
        'Select All',
      ]) {
        expect(menus.enabled(label), isFalse, reason: label);
      }
    });
  });

  testWidgets('the menu bar keeps the application, Edit and Window menus', (
    WidgetTester tester,
  ) async {
    await _onMacOS(() async {
      final _Menus menus = _Menus(tester);
      await _pumpApp(tester);

      expect(find.byType(PlatformMenuBar), findsOneWidget);
      expect(
        menus.topLevel.map((Map<Object?, Object?> menu) => menu['label']),
        <String>['Field Notes', 'Edit', 'Window'],
      );
      expect(menus.providedIn('Field Notes'), <int>[
        PlatformProvidedMenuItemType.about.index,
        PlatformProvidedMenuItemType.servicesSubmenu.index,
        PlatformProvidedMenuItemType.hide.index,
        PlatformProvidedMenuItemType.hideOtherApplications.index,
        PlatformProvidedMenuItemType.showAllApplications.index,
        PlatformProvidedMenuItemType.quit.index,
      ]);
      expect(menus.providedIn('Window'), <int>[
        PlatformProvidedMenuItemType.minimizeWindow.index,
        PlatformProvidedMenuItemType.zoomWindow.index,
        PlatformProvidedMenuItemType.arrangeWindowsInFront.index,
      ]);
      expect(
        _Menus._entries(menus.item('Edit')['children'])
            .where((Map<Object?, Object?> entry) => entry['isDivider'] != true)
            .map((Map<Object?, Object?> entry) => entry['label']),
        <String>['Undo', 'Redo', 'Cut', 'Copy', 'Paste', 'Select All'],
      );
    });
  });

  testWidgets('the menu bar survives the app being mounted again', (
    WidgetTester tester,
  ) async {
    await _onMacOS(() async {
      final _Menus menus = _Menus(tester);
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final int scope in <int>[1, 2]) {
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey<int>(scope),
            overrides: shellOverrides(),
            child: const FieldNotesApp(),
          ),
        );
        await tester.pump();
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
      expect(find.byType(PlatformMenuBar), findsOneWidget);
      expect(
        menus.topLevel.map((Map<Object?, Object?> menu) => menu['label']),
        <String>['Field Notes', 'Edit', 'Window'],
      );
    });
  });

  testWidgets('no menu bar is installed on Android', (
    WidgetTester tester,
  ) async {
    final _Menus menus = _Menus(tester);
    await _pumpApp(tester, page: const SearchField());

    expect(defaultTargetPlatform, TargetPlatform.android);
    expect(find.byType(PlatformMenuBar), findsNothing);
    expect(menus.payloads, isEmpty);
  });
}
