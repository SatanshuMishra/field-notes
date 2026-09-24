import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart';
import 'package:field_notes/features/capture/text/composer_footer.dart';
import 'package:field_notes/features/capture/text/editor/note_editor.dart';
import 'package:field_notes/features/capture/text/editor/photo_caption_field.dart';
import 'package:field_notes/features/capture/text/editor/photo_toolbar.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/layout/photo_planner.dart'
    show isDesktopColumn;
import 'package:field_notes/features/note_engine/note_engine.dart'
    show ComposerMediaScope, NoteEditorController;
import 'package:field_notes/features/note_engine/photos/photo_import_flow.dart'
    show photoAddedToastMessage;
import 'package:field_notes/features/notes/notes_providers.dart';
import 'package:field_notes/features/notes/photos/photo_import.dart';
import 'package:field_notes/state/draft_provider.dart';
import 'package:field_notes/state/media_provider.dart';

import '../../../support/note_editor_driver.dart';
import '../../../support/photo_line_fixture.dart';
import '../../notes/support/notes_harness.dart';
import '../core/capture_test_support.dart';
import '../photo/photo_test_support.dart' show FakePhotoPicker;

const Size _landscapePhoneSurface = Size(844, 390);
const double _keyboardInset = 200;
const double _narrowMeasure = 420;
const double _desktopColumn = 688;
const Duration _hold = Duration(milliseconds: 110);

class _EditorHarness {
  _EditorHarness(String text, {this.importer})
    : controller = NoteEditorController(text: text);

  final NoteEditorController controller;
  final FakePhotoImporter? importer;
  final FocusNode focusNode = FocusNode();
  final UndoHistoryController undo = UndoHistoryController();
  final ScrollController scroll = ScrollController();

  Widget app({
    required double width,
    required double height,
    required MediaResolver resolver,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: ComposerMediaScope(
          resolver: resolver,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: height,
              child: noteEditorFor(
                NoteEditorConfig(
                  controller: controller,
                  focusNode: focusNode,
                  undoController: undo,
                  scrollController: scroll,
                  photoImporter: importer?.call,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void dispose() {
    controller.dispose();
    focusNode.dispose();
    undo.dispose();
    scroll.dispose();
  }
}

FakeNoteMediaResolver _resolvedPhotos() => FakeNoteMediaResolver(
  <String, ResolvedMedia>{
    prefixOf(photoIdA): availablePhoto(photoIdA, width: 1200, height: 900),
    prefixOf(photoIdB): availablePhoto(photoIdB, width: 1200, height: 900),
    prefixOf(photoIdC): availablePhoto(photoIdC, width: 1200, height: 900),
  },
)..memoizeAll();

Future<_EditorHarness> _pumpEditor(
  WidgetTester tester,
  String text, {
  double width = _desktopColumn,
  double height = 700,
  MediaResolver? resolver,
  FakePhotoImporter? importer,
}) async {
  tester.view.physicalSize = const Size(1600, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _EditorHarness harness = _EditorHarness(text, importer: importer);
  addTearDown(harness.dispose);
  await tester.pumpWidget(
    harness.app(
      width: width,
      height: height,
      resolver: resolver ?? _resolvedPhotos(),
    ),
  );
  await tester.pump();
  return harness;
}

Future<void> _selectPhoto(WidgetTester tester, [int ordinal = 0]) async {
  final NoteEditorDriver driver = NoteEditorDriver(tester);
  await driver.press(driver.photoFinder(ordinal), _hold);
  await tester.pump();
}

Future<void> _press(WidgetTester tester, Finder finder) async {
  await NoteEditorDriver(tester).press(finder, _hold);
  await tester.pump();
}

Future<void> _pressControl(WidgetTester tester, Key key) async {
  final bool inMenu =
      key == photoToolbarMoveUpKey ||
      key == photoToolbarMoveDownKey ||
      key == photoToolbarReplaceKey;
  if (inMenu && find.byKey(key).evaluate().isEmpty) {
    await _press(tester, find.byKey(photoToolbarMoreKey));
  }
  await _press(tester, find.byKey(key));
}

List<MdPhotoLine> _photos(String source) {
  final MdTree tree = parseNoteTree(source);
  return <MdPhotoLine>[
    for (final MdBlock block in tree.blocks)
      if (block.kind == MdBlockKind.photoLine)
        MdPhotoLine.ofBlock(block, source),
  ];
}

Future<TextEditingController> _pumpFooter(
  WidgetTester tester, {
  String text = '',
  TextSelection? selection,
  FakePhotoImporter? importer,
}) async {
  final TextEditingController controller = TextEditingController(text: text);
  if (selection != null) {
    controller.selection = selection;
  }
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    notesHarness(
      ComposerFooter(
        controller: controller,
        onAddPhoto: (importer ?? FakePhotoImporter()).call,
      ),
    ),
  );
  await tester.pump();
  return controller;
}

class _Composing {
  _Composing(String text) : controller = NoteEditorController(text: text);

  final NoteEditorController controller;
  final FocusNode focusNode = FocusNode();
  final UndoHistoryController undo = UndoHistoryController();
  final ScrollController scroll = ScrollController();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
    undo.dispose();
    scroll.dispose();
  }
}

Future<_Composing> _pumpComposing(
  WidgetTester tester,
  String text,
  PhotoImporter importer,
) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _Composing composing = _Composing(text);
  addTearDown(composing.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ComposerMediaScope(
          resolver: _resolvedPhotos(),
          child: Align(
            alignment: Alignment.topLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 688,
                  height: 500,
                  child: noteEditorFor(
                    NoteEditorConfig(
                      controller: composing.controller,
                      focusNode: composing.focusNode,
                      undoController: composing.undo,
                      scrollController: composing.scroll,
                      photoImporter: importer,
                    ),
                  ),
                ),
                SizedBox(
                  width: 688,
                  child: ComposerFooter(
                    controller: composing.controller,
                    onAddPhoto: importer,
                    editorFocusNode: composing.focusNode,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return composing;
}

Future<void> _addMemory(WidgetTester tester) async {
  await NoteEditorDriver(tester).press(find.byKey(composerAddPhotoKey), _hold);
  await tester.pump();
  await tester.pump();
}

Widget _composerApp({
  required NoteWriter writer,
  required MediaStore store,
  required PhotoPicker picker,
}) {
  return ProviderScope(
    overrides: <Override>[
      noteWriterProvider.overrideWith((Ref ref) => writer),
      draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
      mediaStoreProvider.overrideWith((Ref ref) async => store),
      notePhotoPickerProvider.overrideWithValue(picker),
    ],
    child: captureHarness(
      Builder(
        builder: (BuildContext context) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(showTextComposer(context, '2026-09-22')),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

Iterable<String> _keysStartingWith(WidgetTester tester, String prefix) {
  return tester.allWidgets
      .map((Widget widget) => widget.key)
      .whereType<ValueKey<String>>()
      .map((ValueKey<String> key) => key.value)
      .where((String value) => value.startsWith(prefix));
}

void main() {
  final String a = mdPhotoLine(photoIdA);
  final String b = mdPhotoLine(photoIdB);

  testWidgets('the composer carries no photo rail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _composerApp(
        writer: FakeNoteWriter(),
        store: FakeNoteMediaStore(),
        picker: FakePhotoPicker(),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(TextComposerSheet), findsOneWidget);
    expect(find.byKey(composerAddPhotoKey), findsOneWidget);
    expect(tester.allWidgets, isNotEmpty);
    expect(_keysStartingWith(tester, 'photo-rail'), isEmpty);
  });

  testWidgets('add memory inserts the photo after the caret block and '
      'selects it', (WidgetTester tester) async {
    final FakePhotoImporter importer = FakePhotoImporter(
      results: <List<String>>[
        <String>[prefixOf(photoIdA)],
      ],
    );
    final _Composing composing = await _pumpComposing(
      tester,
      'A\n\nB\n\nC',
      importer.call,
    );
    final NoteEditorDriver driver = NoteEditorDriver(tester);
    await driver.setSelection(const TextSelection.collapsed(offset: 1));

    await _addMemory(tester);

    expect(importer.calls, 1);
    expect(
      composing.controller.text,
      'A\n![](photo/a1b2c3d4e5f6 "right medium")\n\nB\n\nC',
    );
    expect(composing.controller.selection.start, 2);
    expect(composing.controller.selection.end, 40);
    expect(driver.photoFinder(0), findsOneWidget);
    expect(find.text(photoAddedToastMessage), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3900));
    expect(find.text(photoAddedToastMessage), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.text(photoAddedToastMessage), findsNothing);
  });

  testWidgets('add memory after a paragraph keeps the paragraph whole', (
    WidgetTester tester,
  ) async {
    final Map<String, (int, String)> cases = <String, (int, String)>{
      'one two\n\nthree': (3, 'one two\n$a\n\nthree'),
      'A\n\n\nB': (2, 'A\n$a\n\nB'),
    };
    for (final MapEntry<String, (int, String)> entry in cases.entries) {
      final _Composing composing = await _pumpComposing(
        tester,
        entry.key,
        FakePhotoImporter(
          results: <List<String>>[
            <String>[prefixOf(photoIdA)],
          ],
        ).call,
      );
      await NoteEditorDriver(
        tester,
      ).setSelection(TextSelection.collapsed(offset: entry.value.$1));

      await _addMemory(tester);

      expect(composing.controller.text, entry.value.$2, reason: entry.key);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('two photos land in order with the last one selected', (
    WidgetTester tester,
  ) async {
    final _Composing composing = await _pumpComposing(
      tester,
      'A',
      FakePhotoImporter(
        results: <List<String>>[
          <String>[prefixOf(photoIdA), prefixOf(photoIdB)],
        ],
      ).call,
    );
    await NoteEditorDriver(
      tester,
    ).setSelection(const TextSelection.collapsed(offset: 1));

    await _addMemory(tester);

    expect(composing.controller.text, 'A\n$a\n$b\n');
    expect(composing.controller.selection.start, 41);
    expect(composing.controller.selection.end, 79);
  });

  testWidgets('typing goes on while an import is pending', (
    WidgetTester tester,
  ) async {
    final Completer<List<String>> pick = Completer<List<String>>();
    final _Composing composing = await _pumpComposing(
      tester,
      'A\n\nB\n\nC',
      () => pick.future,
    );
    final NoteEditorDriver driver = NoteEditorDriver(tester);
    await driver.setSelection(const TextSelection.collapsed(offset: 1));

    await _addMemory(tester);

    expect(composing.controller.text, 'A\n\nB\n\nC');

    composing.focusNode.requestFocus();
    await tester.pump();
    await driver.setSelection(const TextSelection.collapsed(offset: 0));
    await driver.typeText('xyz');

    expect(composing.controller.text, 'xyzA\n\nB\n\nC');

    pick.complete(<String>[prefixOf(photoIdA)]);
    await tester.pump();
    await tester.pump();

    expect(composing.controller.text, 'xyzA\n$a\n\nB\n\nC');
  });

  testWidgets('a failed import leaves the note and its history alone', (
    WidgetTester tester,
  ) async {
    final _Composing composing = await _pumpComposing(
      tester,
      'A\n\nB\n\nC',
      FakePhotoImporter(error: const FileSystemException('full')).call,
    );

    await _addMemory(tester);

    expect(composing.controller.text, 'A\n\nB\n\nC');
    expect(composing.undo.value.canUndo, isFalse);
    expect(find.text(composerPhotoFailedMessage), findsOneWidget);

    await tester.pump(kToastLifetime);
    await tester.pump();
  });

  testWidgets(
    'one undo takes back an added photo',
    (WidgetTester tester) async {
      final _Composing composing = await _pumpComposing(
        tester,
        'A\n\nB\n\nC',
        FakePhotoImporter(
          results: <List<String>>[
            <String>[prefixOf(photoIdA)],
          ],
        ).call,
      );
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      composing.focusNode.requestFocus();
      await tester.pump();
      await driver.setSelection(const TextSelection.collapsed(offset: 1));

      await _addMemory(tester);
      expect(composing.controller.text, 'A\n$a\n\nB\n\nC');

      await driver.pressKey(LogicalKeyboardKey.keyZ, meta: true);

      expect(composing.controller.text, 'A\n\nB\n\nC');
      await tester.pump(const Duration(seconds: 5));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('a plain controller with no selection gets the photo at the end', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = await _pumpFooter(
      tester,
      text: 'kept',
      importer: FakePhotoImporter(
        results: <List<String>>[
          <String>[prefixOf(photoIdA)],
        ],
      ),
    );

    await _press(tester, find.byKey(composerAddPhotoKey));

    expect(controller.text, 'kept\n$a\n');
  });

  testWidgets('Add memory picks, stores and inserts the photo line at the caret', (
    WidgetTester tester,
  ) async {
    final FakePhotoImporter importer = FakePhotoImporter(
      results: <List<String>>[
        <String>[prefixOf(photoIdA)],
      ],
    );
    final TextEditingController controller = await _pumpFooter(
      tester,
      text: 'one\ntwo',
      selection: caretAt(3),
      importer: importer,
    );

    await _press(tester, find.byKey(composerAddPhotoKey));

    expect(importer.calls, 1);
    expect(controller.text, 'one\ntwo\n$a\n');
    expect(_photos(controller.text), hasLength(1));
    expect(_photos(controller.text).single.reference, prefixOf(photoIdA));
  });

  testWidgets('a refused pick is reported and leaves the note alone', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = await _pumpFooter(
      tester,
      text: 'kept',
      importer: FakePhotoImporter(error: denialError),
    );

    await _press(tester, find.byKey(composerAddPhotoKey));

    expect(find.text(photoLibraryErrorMessage), findsOneWidget);
    expect(
      tester
          .widget<IconStickerGlyphIcon>(find.byType(IconStickerGlyphIcon))
          .glyph,
      IconStickerGlyph.close,
    );
    expect(controller.text, 'kept');

    await tester.pump(kToastLifetime);
    await tester.pump();

    expect(find.text(photoLibraryErrorMessage), findsNothing);
  });

  testWidgets('a storage failure is reported and leaves the note alone', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = await _pumpFooter(
      tester,
      text: 'kept',
      importer: FakePhotoImporter(error: const FileSystemException('full')),
    );

    await _press(tester, find.byKey(composerAddPhotoKey));

    expect(find.text(composerPhotoFailedMessage), findsOneWidget);
    expect(controller.text, 'kept');

    await tester.pump(kToastLifetime);
    await tester.pump();

    expect(find.text(composerPhotoFailedMessage), findsNothing);
  });

  testWidgets('Add memory is reachable with Tab, operable with Enter, and '
      'hands focus back to the writing surface', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final TextEditingController controller = TextEditingController();
    final FocusNode editor = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(editor.dispose);
    final FakePhotoImporter importer = FakePhotoImporter(
      results: <List<String>>[
        <String>[prefixOf(photoIdA)],
      ],
    );
    await tester.pumpWidget(
      notesHarness(
        Column(
          children: <Widget>[
            SizedBox(
              height: 120,
              child: TextField(
                controller: controller,
                focusNode: editor,
                maxLines: null,
                expands: true,
              ),
            ),
            ComposerFooter(
              controller: controller,
              onAddPhoto: importer.call,
              editorFocusNode: editor,
            ),
          ],
        ),
      ),
    );
    editor.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      composerAddPhotoLabel,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(importer.calls, 1);
    expect(controller.text, '$a\n');
    expect(editor.hasFocus, isTrue);
  });

  testWidgets('Add memory survives a short screen', (WidgetTester tester) async {
    tester.view.physicalSize = _landscapePhoneSurface;
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: _keyboardInset);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DialogHost(
          child: ComposerShell(
            responsive: true,
            child: TextComposerSheet(
              onSave: (String _) {},
              onCancel: () {},
              onAddPhoto: FakePhotoImporter().call,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(composerAddPhotoKey).hitTestable(), findsOneWidget);
    expect(find.text(composerAddPhotoLabel), findsOneWidget);
  });

  testWidgets('Size and Side rewrite only the selected photo', (
    WidgetTester tester,
  ) async {
    final String note = 'one\n$a\ntwo\n$b\nthree';
    final _EditorHarness harness = await _pumpEditor(tester, note);

    await _selectPhoto(tester, 1);

    await _press(tester, find.byKey(photoToolbarSizeKey(MdPhotoSize.large)));
    await _press(tester, find.byKey(photoToolbarSideKey(MdPhotoSide.left)));

    final String rewritten = mdPhotoLine(
      photoIdB,
      side: MdPhotoSide.left,
      size: MdPhotoSize.large,
    );
    expect(harness.controller.text, 'one\n$a\ntwo\n$rewritten\nthree');
    final List<MdPhotoLine> photos = _photos(harness.controller.text);
    expect(photos[0].placement.side, MdPhotoSide.right);
    expect(photos[0].placement.size, MdPhotoSize.medium);
    expect(photos[1].placement.side, MdPhotoSide.left);
    expect(photos[1].placement.size, MdPhotoSize.large);
  });

  testWidgets('Side is hidden where the measure cannot float', (
    WidgetTester tester,
  ) async {
    await _pumpEditor(tester, 'one\n$a\ntwo', width: _narrowMeasure);

    await _selectPhoto(tester);

    expect(isDesktopColumn(columnWidth: _narrowMeasure, em: 16), isFalse);
    expect(find.byKey(photoToolbarKey), findsOneWidget);
    for (final MdPhotoSide side in MdPhotoSide.values) {
      expect(find.byKey(photoToolbarSideKey(side)), findsNothing);
    }
    for (final MdPhotoSize size in MdPhotoSize.values) {
      expect(find.byKey(photoToolbarSizeKey(size)), findsNothing);
    }
    expect(find.byKey(photoToolbarCaptionKey), findsOneWidget);
    expect(find.byKey(photoToolbarRemoveKey), findsOneWidget);
  });

  testWidgets('Move up, Move down and Replace keep the caption and the '
      'placement', (WidgetTester tester) async {
    final String first = mdPhotoLine(
      photoIdA,
      caption: 'porch',
      side: MdPhotoSide.left,
      size: MdPhotoSize.small,
    );
    final String second = mdPhotoLine(
      photoIdB,
      caption: 'harbour',
      size: MdPhotoSize.large,
    );
    final String note = 'one\n$first\ntwo\n$second\nthree';
    final FakePhotoImporter importer = FakePhotoImporter(
      results: <List<String>>[
        <String>[prefixOf(photoIdC)],
      ],
    );
    final _EditorHarness harness = await _pumpEditor(
      tester,
      note,
      importer: importer,
    );

    await _selectPhoto(tester, 1);
    await _pressControl(tester, photoToolbarMoveUpKey);

    expect(harness.controller.text, 'one\n$first\n$second\ntwo\n\nthree');
    final int moved = harness.controller.text.indexOf(second);
    expect(harness.controller.selection.start, moved);
    expect(_photos(harness.controller.text)[1].caption, 'harbour');
    expect(
      _photos(harness.controller.text)[1].placement.size,
      MdPhotoSize.large,
    );

    await _pressControl(tester, photoToolbarMoveDownKey);

    final String down = 'one\n$first\n\ntwo\n$second\n\nthree';
    expect(harness.controller.text, down);
    expect(_photos(harness.controller.text)[1].caption, 'harbour');

    await _pressControl(tester, photoToolbarReplaceKey);
    await tester.pump();
    await tester.pump();

    expect(importer.calls, 1);
    expect(
      harness.controller.text,
      down.replaceFirst(
        second,
        mdPhotoLine(photoIdC, caption: 'harbour', size: MdPhotoSize.large),
      ),
    );
    expect(_photos(harness.controller.text)[0].caption, 'porch');
    expect(
      _photos(harness.controller.text)[0].placement.side,
      MdPhotoSide.left,
    );
    expect(
      _photos(harness.controller.text)[0].placement.size,
      MdPhotoSize.small,
    );
  });

  testWidgets('every photo toolbar control carries the design target', (
    WidgetTester tester,
  ) async {
    await _pumpEditor(tester, 'one\n$a\ntwo\n$b\nthree');

    await _selectPhoto(tester);

    final bool moves = find.byKey(photoToolbarMoveUpKey).evaluate().isNotEmpty;
    final List<Finder> controls = <Finder>[
      for (final MdPhotoSize size in MdPhotoSize.values)
        find.byKey(photoToolbarSizeKey(size)),
      for (final MdPhotoSide side in MdPhotoSide.values)
        find.byKey(photoToolbarSideKey(side)),
      find.byKey(photoToolbarCaptionKey),
      find.byKey(photoToolbarRemoveKey),
      if (moves) ...<Finder>[
        find.byKey(photoToolbarMoveUpKey),
        find.byKey(photoToolbarMoveDownKey),
        find.byKey(photoToolbarReplaceKey),
      ] else
        find.byKey(photoToolbarMoreKey),
    ];
    for (final Finder control in controls) {
      expect(control, findsOneWidget);
      final Size target = tester.getSize(control);
      expect(
        target.height,
        greaterThanOrEqualTo(photoToolbarTarget),
        reason: '$control is shorter than the toolbar target',
      );
      expect(
        target.width,
        greaterThanOrEqualTo(photoToolbarTarget),
        reason: '$control is narrower than the toolbar target',
      );
    }
  });

  testWidgets(
    'a toolbar tap keeps the writing surface focused, so Cmd-Z undoes the '
    'placement',
    (WidgetTester tester) async {
      final String note = 'one\n$a\ntwo';
      final _EditorHarness harness = await _pumpEditor(tester, note);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      harness.focusNode.requestFocus();
      await tester.pump();

      await driver.press(
        driver.photoFinder(0),
        _hold,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(seconds: 1));

      await driver.press(
        find.byKey(photoToolbarSizeKey(MdPhotoSize.large)),
        _hold,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(seconds: 1));

      expect(harness.focusNode.hasFocus, isTrue);
      expect(
        harness.controller.text,
        'one\n${mdPhotoLine(photoIdA, size: MdPhotoSize.large)}\ntwo',
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(harness.controller.text, note);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('Caption writes the alt slot', (WidgetTester tester) async {
    final String note = 'one\n$a\ntwo\n$b\nthree';
    final _EditorHarness harness = await _pumpEditor(tester, note);

    await _selectPhoto(tester);
    await _press(tester, find.byKey(photoToolbarCaptionKey));

    expect(find.byKey(photoCaptionFieldEditorKey), findsOneWidget);

    await tester.enterText(
      find.byKey(photoCaptionFieldEditorKey),
      'dusk on the porch',
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    final String captioned = mdPhotoLine(
      photoIdA,
      caption: 'dusk on the porch',
    );
    expect(captioned, contains('![dusk on the porch](photo/'));
    expect(harness.controller.text, 'one\n$captioned\ntwo\n$b\nthree');
    expect(_photos(harness.controller.text)[0].caption, 'dusk on the porch');
    expect(_photos(harness.controller.text), hasLength(2));
    expect(find.byKey(photoCaptionFieldEditorKey), findsNothing);
  });

  testWidgets('Remove offers Undo and Undo restores the line byte for byte', (
    WidgetTester tester,
  ) async {
    final String captioned = mdPhotoLine(
      photoIdA,
      caption: 'porch',
      side: MdPhotoSide.left,
      size: MdPhotoSize.small,
    );
    final String note = 'one\r\n$captioned\r\n  \ntwo';
    final _EditorHarness harness = await _pumpEditor(tester, note);

    await _selectPhoto(tester);
    await _press(tester, find.byKey(photoToolbarRemoveKey));
    await tester.pumpAndSettle();

    expect(harness.controller.text, 'one\r\n  \ntwo');
    expect(find.text(photoRemovedMessage), findsOneWidget);
    expect(find.text(photoRemovedUndoLabel), findsOneWidget);
    expectTargetAtLeast48(
      tester,
      find
          .ancestor(
            of: find.text(photoRemovedUndoLabel),
            matching: find.byType(GestureDetector),
          )
          .first,
    );

    await _press(tester, find.text(photoRemovedUndoLabel));
    await tester.pumpAndSettle();

    expect(harness.controller.text, note);
    final MdPhotoLine restored = _photos(harness.controller.text).single;
    expect(restored.caption, 'porch');
    expect(restored.placement.side, MdPhotoSide.left);
    expect(restored.placement.size, MdPhotoSize.small);
    expect(find.text(photoRemovedMessage), findsNothing);
  });

  test('no drag or reorder api exists in the photo toolbar, caption field, '
      'footer or table toolbar', () {
    final RegExp drag = RegExp(
      r'Draggable|DragTarget|DragGestureRecognizer|ReorderableList|'
      r'onPan[A-Z]|onHorizontalDrag|onVerticalDrag|onScale[A-Z]|'
      r'onLongPressMoveUpdate|ScaleGestureRecognizer',
    );
    const List<String> paths = <String>[
      'lib/features/capture/text/editor/photo_toolbar.dart',
      'lib/features/capture/text/editor/photo_caption_field.dart',
      'lib/features/capture/text/composer_footer.dart',
      'lib/features/note_engine/toolbars/table_toolbar.dart',
    ];
    for (final String path in paths) {
      final File file = File(path);
      expect(file.existsSync(), isTrue, reason: path);
      expect(drag.hasMatch(file.readAsStringSync()), isFalse, reason: path);
    }
  });

  testWidgets('no gesture detector in the photo toolbar listens for a drag', (
    WidgetTester tester,
  ) async {
    await _pumpEditor(tester, 'one\n$a\ntwo');

    await _selectPhoto(tester);

    final Iterable<GestureDetector> detectors = tester
        .widgetList<GestureDetector>(
          find.descendant(
            of: find.byKey(photoToolbarKey),
            matching: find.byType(GestureDetector),
          ),
        );
    expect(detectors, isNotEmpty);
    for (final GestureDetector detector in detectors) {
      expect(detector.onPanStart, isNull);
      expect(detector.onPanUpdate, isNull);
      expect(detector.onHorizontalDragUpdate, isNull);
      expect(detector.onVerticalDragUpdate, isNull);
      expect(detector.onScaleUpdate, isNull);
      expect(detector.onLongPressMoveUpdate, isNull);
    }
    expect(find.byType(Draggable<Object>), findsNothing);
    expect(find.byType(LongPressDraggable<Object>), findsNothing);
  });

  group('NotePhotoStore', () {
    test('stores a pick with its dimensions and answers a 12-hex reference',
        () async {
      final FakeNoteMediaStore media =
          FakeNoteMediaStore(assignIds: <String>[photoIdA]);

      final String reference = await NotePhotoStore(media).importPhoto(
        const CaptureBytes(
          bytes: <int>[1, 2, 3],
          mime: 'image/png',
          width: 640,
          height: 480,
        ),
      );

      expect(reference, prefixOf(photoIdA));
      expect(media.blobs.single.width, 640);
      expect(media.blobs.single.height, 480);
    });

    test('stores a file pick with its dimensions', () async {
      final FakeNoteMediaStore media =
          FakeNoteMediaStore(assignIds: <String>[photoIdA]);

      final String reference = await NotePhotoStore(media).importPhoto(
        CaptureFile(
          file: File('unused.jpg'),
          mime: 'image/jpeg',
          width: 1536,
          height: 2048,
        ),
      );

      expect(reference, prefixOf(photoIdA));
      expect(media.blobs.single.width, 1536);
      expect(media.blobs.single.height, 2048);
    });

    test('extends the reference when a stored neighbour shares its prefix',
        () async {
      final String twin = '${prefixOf(photoIdA)}${'f' * 52}';
      final FakeNoteMediaStore media =
          FakeNoteMediaStore(assignIds: <String>[photoIdA])
            ..register(photoBlob(twin));

      final String reference = await NotePhotoStore(media).importPhoto(
        CaptureFile(file: File('unused.jpg'), mime: 'image/jpeg'),
      );

      expect(reference, photoIdA.substring(0, 16));
    });

    test('resolves references to full ids once each, in first-seen order, '
        'skipping any it cannot resolve', () async {
      final FakeNoteMediaStore media = FakeNoteMediaStore()
        ..register(photoBlob(photoIdA))
        ..register(photoBlob(photoIdB));
      final String source = '${mdPhotoLine(photoIdB)}\n'
          '![](photo/${photoIdA.substring(0, 16)})\n'
          '${mdPhotoLine(photoIdA)}\n'
          '![](photo/0123456789ab)';

      expect(
        await NotePhotoStore(media).mediaIdsReferencedBy(source),
        <String>[photoIdB, photoIdA],
      );
    });

    test('a source with no reference never opens the store', () async {
      int opened = 0;
      final List<String> ids = await notePhotoMediaIds(
        '# words only\n\nno photos here',
        () async {
          opened++;
          return NotePhotoStore(FakeNoteMediaStore());
        },
      );

      expect(ids, isEmpty);
      expect(opened, 0);
    });
  });
}
