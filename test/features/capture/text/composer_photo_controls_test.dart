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
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart';
import 'package:field_notes/features/capture/text/composer_footer.dart';
import 'package:field_notes/features/capture/text/editor/editor.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/notes/notes.dart';
import 'package:field_notes/features/notes/photos/photo_import.dart';
import 'package:field_notes/state/draft_provider.dart';
import 'package:field_notes/state/media_provider.dart';

import '../../notes/support/notes_harness.dart';
import '../core/capture_test_support.dart';
import '../photo/photo_test_support.dart' show FakePhotoPicker;

const Size _landscapePhoneSurface = Size(844, 390);
const double _keyboardInset = 200;
const double _narrowMeasure = 420;
const double _readerMeasure = NoteColumn.measureEm * 16;

class _EditorHarness {
  _EditorHarness(String text, {this.importer})
      : controller = MarkdownStyleController(text: text);

  final MarkdownStyleController controller;
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
              child: InPlacePhotoEditor(
                config: NoteEditorConfig(
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
  double width = _readerMeasure,
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
  await tester.tap(find.byKey(inPlacePhotoKey(ordinal)));
  await tester.pump();
}

Future<void> _openMore(WidgetTester tester) async {
  if (find.byKey(photoToolbarMoveUpKey).evaluate().isNotEmpty) {
    return;
  }
  await tester.tap(find.byKey(photoToolbarMoreKey));
  await tester.pump();
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

Iterable<File> _dartSourcesUnder(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((File file) => file.path.endsWith('.dart'));


void main() {
  final String a = photoLine(photoIdA);
  final String b = photoLine(photoIdB);

  testWidgets('the composer carries no photo rail', (WidgetTester tester) async {
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

  testWidgets('Add memory picks, stores and inserts the photo line at the caret',
      (WidgetTester tester) async {
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

    await tester.tap(find.byKey(composerAddPhotoKey));
    await tester.pump();

    expect(importer.calls, 1);
    expect(controller.text, 'one\n$a\ntwo');
    expect(notePhotoLines(controller.text), hasLength(1));
    expect(notePhotoLines(controller.text).single.reference, prefixOf(photoIdA));
  });

  testWidgets('a refused pick is reported and leaves the note alone',
      (WidgetTester tester) async {
    final TextEditingController controller = await _pumpFooter(
      tester,
      text: 'kept',
      importer: FakePhotoImporter(error: denialError),
    );

    await tester.tap(find.byKey(composerAddPhotoKey));
    await tester.pump();

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

  testWidgets('a storage failure is reported and leaves the note alone',
      (WidgetTester tester) async {
    final TextEditingController controller = await _pumpFooter(
      tester,
      text: 'kept',
      importer: FakePhotoImporter(error: const FileSystemException('full')),
    );

    await tester.tap(find.byKey(composerAddPhotoKey));
    await tester.pump();

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

  testWidgets('Size and Side rewrite only the selected photo',
      (WidgetTester tester) async {
    final String note = 'one\n$a\ntwo\n$b\nthree';
    final _EditorHarness harness = await _pumpEditor(tester, note);

    await _selectPhoto(tester, 1);

    await tester.tap(find.byKey(photoToolbarSizeKey(PhotoSize.large)));
    await tester.pump();
    await tester.tap(find.byKey(photoToolbarSideKey(PhotoSide.left)));
    await tester.pump();

    final String rewritten = photoLine(
      photoIdB,
      side: PhotoSide.left,
      size: PhotoSize.large,
    );
    expect(harness.controller.text, 'one\n$a\ntwo\n$rewritten\nthree');
    expect(notePhotoLines(harness.controller.text)[0].placement.side,
        PhotoSide.right);
    expect(notePhotoLines(harness.controller.text)[0].placement.size,
        PhotoSize.medium);
    expect(notePhotoLines(harness.controller.text)[1].placement.side,
        PhotoSide.left);
    expect(notePhotoLines(harness.controller.text)[1].placement.size,
        PhotoSize.large);
  });

  testWidgets('Side is hidden where the measure cannot float',
      (WidgetTester tester) async {
    await _pumpEditor(tester, 'one\n$a\ntwo', width: _narrowMeasure);

    await _selectPhoto(tester);

    expect(canFloatAt(measure: _narrowMeasure, em: 16), isFalse);
    expect(find.byKey(photoToolbarKey), findsOneWidget);
    for (final PhotoSide side in PhotoSide.values) {
      expect(find.byKey(photoToolbarSideKey(side)), findsNothing);
    }
    for (final PhotoSize size in PhotoSize.values) {
      expect(find.byKey(photoToolbarSizeKey(size)), findsOneWidget);
    }
  });

  testWidgets('Move up, Move down and Replace keep the caption and the '
      'placement', (WidgetTester tester) async {
    final String first = photoLine(
      photoIdA,
      caption: 'porch',
      side: PhotoSide.left,
      size: PhotoSize.small,
    );
    final String second = photoLine(
      photoIdB,
      caption: 'harbour',
      size: PhotoSize.large,
    );
    final String note = 'one\n$first\ntwo\n$second\nthree';
    final FakePhotoImporter importer = FakePhotoImporter(
      results: <List<String>>[
        <String>[prefixOf(photoIdC)],
      ],
    );
    final _EditorHarness harness =
        await _pumpEditor(tester, note, importer: importer);

    await _selectPhoto(tester, 1);
    await _openMore(tester);
    await tester.tap(find.byKey(photoToolbarMoveUpKey));
    await tester.pump();

    expect(harness.controller.text, 'one\n$first\n$second\ntwo\nthree');
    expect(
      photoLineIndexAtCaret(harness.controller.text, harness.controller.selection),
      1,
    );
    expect(notePhotoLines(harness.controller.text)[1].caption, 'harbour');
    expect(notePhotoLines(harness.controller.text)[1].placement.size,
        PhotoSize.large);

    await _openMore(tester);
    await tester.tap(find.byKey(photoToolbarMoveDownKey));
    await tester.pump();

    expect(harness.controller.text, note);
    expect(notePhotoLines(harness.controller.text)[1].caption, 'harbour');

    await _openMore(tester);
    await tester.tap(find.byKey(photoToolbarReplaceKey));
    await tester.pumpAndSettle();

    expect(importer.calls, 1);
    expect(
      harness.controller.text,
      note.replaceFirst(
        second,
        photoLine(photoIdC, caption: 'harbour', size: PhotoSize.large),
      ),
    );
    expect(notePhotoLines(harness.controller.text)[0].caption, 'porch');
    expect(notePhotoLines(harness.controller.text)[0].placement.side,
        PhotoSide.left);
  });

  testWidgets('every photo toolbar control carries the design target',
      (WidgetTester tester) async {
    await _pumpEditor(tester, 'one\n$a\ntwo\n$b\nthree');

    await _selectPhoto(tester);
    await _openMore(tester);

    final List<Finder> controls = <Finder>[
      for (final PhotoSize size in PhotoSize.values)
        find.byKey(photoToolbarSizeKey(size)),
      for (final PhotoSide side in PhotoSide.values)
        find.byKey(photoToolbarSideKey(side)),
      find.byKey(photoToolbarCaptionKey),
      find.byKey(photoToolbarRemoveKey),
      find.byKey(photoToolbarMoreKey),
      find.byKey(photoToolbarMoveUpKey),
      find.byKey(photoToolbarMoveDownKey),
      find.byKey(photoToolbarReplaceKey),
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

  testWidgets('a toolbar tap keeps the writing surface focused, so Cmd-Z '
      'undoes the placement', (WidgetTester tester) async {
    final String note = 'one\n$a\ntwo';
    final _EditorHarness harness = await _pumpEditor(tester, note);
    harness.focusNode.requestFocus();
    await tester.pump();

    await _selectPhoto(tester);
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(
      find.byKey(photoToolbarSizeKey(PhotoSize.large)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(seconds: 1));

    expect(harness.focusNode.hasFocus, isTrue);
    expect(
      harness.controller.text,
      'one\n${photoLine(photoIdA, size: PhotoSize.large)}\ntwo',
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(harness.controller.text, note);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Caption writes the alt slot', (WidgetTester tester) async {
    final String note = 'one\n$a\ntwo\n$b\nthree';
    final _EditorHarness harness = await _pumpEditor(tester, note);

    await _selectPhoto(tester);
    await tester.tap(find.byKey(photoToolbarCaptionKey));
    await tester.pump();

    expect(find.byKey(photoCaptionFieldEditorKey), findsOneWidget);

    await tester.enterText(
      find.byKey(photoCaptionFieldEditorKey),
      'dusk on the porch',
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    final String captioned = photoLine(photoIdA, caption: 'dusk on the porch');
    expect(captioned, contains('![dusk on the porch](photo/'));
    expect(harness.controller.text, 'one\n$captioned\ntwo\n$b\nthree');
    expect(notePhotoLines(harness.controller.text)[0].caption,
        'dusk on the porch');
    expect(notePhotoLines(harness.controller.text), hasLength(2));
    expect(find.byKey(photoCaptionFieldEditorKey), findsNothing);
  });

  testWidgets('Remove offers Undo and Undo restores the line byte for byte',
      (WidgetTester tester) async {
    const String crlf = 'one\r\n';
    final String captioned = photoLine(
      photoIdA,
      caption: 'porch',
      side: PhotoSide.left,
      size: PhotoSize.small,
    );
    final String note = '$crlf$captioned\r\n  \ntwo';
    final _EditorHarness harness = await _pumpEditor(tester, note);

    await _selectPhoto(tester);
    await tester.tap(find.byKey(photoToolbarRemoveKey));
    await tester.pumpAndSettle();

    expect(harness.controller.text, '$crlf  \ntwo');
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

    await tester.tap(find.text(photoRemovedUndoLabel));
    await tester.pumpAndSettle();

    expect(harness.controller.text, note);
    expect(notePhotoLines(harness.controller.text).single.caption, 'porch');
    expect(notePhotoLines(harness.controller.text).single.placement.side,
        PhotoSide.left);
    expect(notePhotoLines(harness.controller.text).single.placement.size,
        PhotoSize.small);
    expect(find.text(photoRemovedMessage), findsNothing);
  });

  test('no drag or reorder API exists anywhere in the photo controls', () {
    final RegExp drag = RegExp(
      r'Draggable|DragTarget|DragGestureRecognizer|ReorderableList|'
      r'onPan[A-Z]|onHorizontalDrag|onVerticalDrag|onScale[A-Z]|'
      r'onLongPressMoveUpdate|ScaleGestureRecognizer',
    );
    final List<File> sources = <File>[
      ..._dartSourcesUnder('lib/features/notes'),
      ..._dartSourcesUnder('lib/features/capture/text'),
    ];
    final List<String> offenders = <String>[
      for (final File file in sources)
        if (drag.hasMatch(file.readAsStringSync())) file.path,
    ];

    expect(sources, isNotEmpty);
    expect(offenders, isEmpty);
  });

  testWidgets('no gesture detector in the photo toolbar listens for a drag',
      (WidgetTester tester) async {
    await _pumpEditor(tester, 'one\n$a\ntwo');

    await _selectPhoto(tester);

    final Iterable<GestureDetector> detectors =
        tester.widgetList<GestureDetector>(
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
      final String source = '${photoLine(photoIdB)}\n'
          '![](photo/${photoIdA.substring(0, 16)})\n'
          '${photoLine(photoIdA)}\n'
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
