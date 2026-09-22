import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/notes/notes.dart';

import '../support/notes_harness.dart';

final Finder _rail = find.byKey(photoRailKey);

bool _thumbSelected(WidgetTester tester, int ordinal) {
  final Semantics semantics = tester.widget<Semantics>(
    find
        .ancestor(
          of: find.byKey(photoRailThumbKey(ordinal)),
          matching: find.byType(Semantics),
        )
        .first,
  );
  return semantics.properties.selected ?? false;
}

Color? _thumbBorder(WidgetTester tester, int ordinal) {
  final DecoratedBox frame = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byKey(photoRailThumbKey(ordinal)),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  final BoxDecoration decoration = frame.decoration as BoxDecoration;
  return (decoration.border as Border?)?.top.color;
}

List<Finder> _everyControl() => <Finder>[
      for (final PhotoSize size in PhotoSize.values)
        find.byKey(photoSizeKey(size)),
      for (final PhotoSide side in PhotoSide.values)
        find.byKey(photoSideKey(side)),
      find.byKey(photoMoveUpKey),
      find.byKey(photoMoveDownKey),
      find.byKey(photoReplaceKey),
      find.byKey(photoRemoveKey),
      find.byKey(photoCaptionKey),
    ];

class _PendingMediaResolver implements MediaResolver {
  final Completer<ResolvedMedia> pending = Completer<ResolvedMedia>();

  @override
  ResolvedMedia? resolved(String? mediaId) => null;

  @override
  Future<ResolvedMedia> resolve(String? mediaId) => pending.future;
}

Iterable<File> _dartSourcesUnder(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((File file) => file.path.endsWith('.dart'));

void main() {
  final String a = photoLine(photoIdA);
  final String b = photoLine(photoIdB);
  final String twoPhotos = 'one\n$a\nmiddle\n$b\ntwo';

  group('Add photo tile', () {
    testWidgets('is present as the first cell on a blank note',
        (WidgetTester tester) async {
      await pumpPhotoRail(tester);

      expect(find.byKey(photoRailAddKey), findsOneWidget);
      expect(find.text(photoRailAddLabel), findsOneWidget);
      expect(find.byKey(photoRailThumbKey(0)), findsNothing);
      expect(find.byKey(photoRailControlsKey), findsNothing);
      expectTargetAtLeast48(tester, find.byKey(photoRailAddKey));
    });

    testWidgets('stays first once the note has photos',
        (WidgetTester tester) async {
      await pumpPhotoRail(tester, text: twoPhotos);

      final double add = tester.getTopLeft(find.byKey(photoRailAddKey)).dx;
      expect(add, lessThan(tester.getTopLeft(find.byKey(photoRailThumbKey(0))).dx));
      expect(add, lessThan(tester.getTopLeft(find.byKey(photoRailThumbKey(1))).dx));
    });

    testWidgets('a tap picks, stores and inserts the photo line at the caret',
        (WidgetTester tester) async {
      final FakePhotoImporter importer = FakePhotoImporter(
        results: <List<String>>[
          <String>[prefixOf(photoIdA)],
        ],
      );
      final TextEditingController controller = await pumpPhotoRail(
        tester,
        text: 'one\ntwo',
        selection: caretAt(3),
        importer: importer,
      );

      await tester.tap(find.byKey(photoRailAddKey));
      await tester.pump();

      expect(importer.calls, 1);
      expect(controller.text, 'one\n$a\ntwo');
      expect(find.byKey(photoRailThumbKey(0)), findsOneWidget);
    });

    testWidgets('is reachable with Tab and operable with Enter, then hands '
        'focus back to the writing surface', (WidgetTester tester) async {
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
              PhotoRail(
                controller: controller,
                onPickPhotos: importer.call,
                measure: 560,
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
        photoRailAddLabel,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(importer.calls, 1);
      expect(controller.text, '$a\n');
      expect(editor.hasFocus, isTrue);
    });

    testWidgets(
        'on desktop a rail tap keeps the writing surface focused, so Cmd-Z '
        'undoes the placement', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final String source = 'one\n$a';
      final TextEditingController controller =
          TextEditingController(text: source);
      final FocusNode editor = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(editor.dispose);
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
              PhotoRail(
                controller: controller,
                onPickPhotos: FakePhotoImporter().call,
                measure: 560,
                editorFocusNode: editor,
              ),
            ],
          ),
        ),
      );
      editor.requestFocus();
      await tester.pump();
      controller.selection = caretAt(source.length);
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(
        find.byKey(photoSizeKey(PhotoSize.large)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(seconds: 1));

      expect(editor.hasFocus, isTrue);
      expect(controller.text, 'one\n${photoLine(photoIdA, size: PhotoSize.large)}');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(controller.text, source);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a refused pick explains why inline and leaves the note alone',
        (WidgetTester tester) async {
      final TextEditingController controller = await pumpPhotoRail(
        tester,
        text: 'kept',
        importer: FakePhotoImporter(error: denialError),
      );

      await tester.tap(find.byKey(photoRailAddKey));
      await tester.pump();

      expect(find.text(photoLibraryErrorMessage), findsOneWidget);
      expect(controller.text, 'kept');

      await tester.pump(photoErrorNoticeLifetime);
      expect(find.text(photoLibraryErrorMessage), findsNothing);
    });

    testWidgets('a storage failure is reported, not swallowed',
        (WidgetTester tester) async {
      final TextEditingController controller = await pumpPhotoRail(
        tester,
        text: 'kept',
        importer: FakePhotoImporter(error: const FileSystemException('full')),
      );

      await tester.tap(find.byKey(photoRailAddKey));
      await tester.pump();

      expect(find.text(photoAddFailedMessage), findsOneWidget);
      expect(controller.text, 'kept');
      await tester.pump(photoErrorNoticeLifetime);
    });
  });

  group('caret-following highlight', () {
    testWidgets('highlights the thumbnail whose source line holds the caret',
        (WidgetTester tester) async {
      final TextEditingController controller = await pumpPhotoRail(
        tester,
        text: twoPhotos,
        selection: caretAt(twoPhotos.indexOf(b) + 4),
      );

      expect(_thumbSelected(tester, 0), isFalse);
      expect(_thumbSelected(tester, 1), isTrue);
      expect(_thumbBorder(tester, 1), Palette.coral);

      controller.selection = caretAt(twoPhotos.indexOf(a));
      await tester.pump();

      expect(_thumbSelected(tester, 0), isTrue);
      expect(_thumbSelected(tester, 1), isFalse);
      expect(_thumbBorder(tester, 0), Palette.coral);

      controller.selection = caretAt(twoPhotos.indexOf('middle'));
      await tester.pump();

      expect(_thumbSelected(tester, 0), isFalse);
      expect(_thumbSelected(tester, 1), isFalse);
      expect(find.text(photoRailHint), findsOneWidget);
    });

    testWidgets('at composer width a thumbnail tap moves the caret onto it',
        (WidgetTester tester) async {
      final TextEditingController controller = await pumpPhotoRail(
        tester,
        text: twoPhotos,
        selection: caretAt(0),
      );

      await tester.tap(find.byKey(photoRailThumbKey(1)));
      await tester.pump();

      expect(photoLineIndexAtCaret(controller.text, controller.selection), 1);
      expect(_thumbSelected(tester, 1), isTrue);
      expect(controller.text, twoPhotos);
      expect(find.byKey(photoOptionsSheetKey), findsNothing);
    });
  });

  group('presentation by width', () {
    testWidgets('is thumbnails only on a 360dp phone', (WidgetTester tester) async {
      await pumpPhotoRail(
        tester,
        text: twoPhotos,
        selection: caretAt(twoPhotos.indexOf(a)),
        width: 360,
        measure: 284,
      );

      expect(find.byKey(photoRailThumbKey(0)), findsOneWidget);
      expect(find.byKey(photoRailThumbKey(1)), findsOneWidget);
      expect(find.byKey(photoRailControlsKey), findsNothing);
      for (final Finder control in _everyControl()) {
        expect(control, findsNothing);
      }
      expect(tester.getSize(_rail).height, photoRailCompactHeight);
      expectTargetAtLeast48(tester, find.byKey(photoRailThumbKey(0)));
    });

    testWidgets('carries every control at 48dp or more at composer width',
        (WidgetTester tester) async {
      await pumpPhotoRail(
        tester,
        text: twoPhotos,
        selection: caretAt(twoPhotos.indexOf(a)),
      );

      expect(find.byKey(photoRailControlsKey), findsOneWidget);
      for (final Finder control in _everyControl()) {
        expect(control, findsOneWidget);
        expectTargetAtLeast48(tester, control);
      }
      expect(
        tester.getRect(find.byKey(photoRailControlsKey)).right,
        lessThanOrEqualTo(600),
      );
      expect(tester.getSize(_rail).height, photoRailFullHeight);
    });

    testWidgets('the full row fits exactly the width the compact cut assumes',
        (WidgetTester tester) async {
      await pumpPhotoRail(
        tester,
        text: twoPhotos,
        selection: caretAt(twoPhotos.indexOf(a)),
        width: photoRailFullMinWidth,
      );

      expect(
        tester.getSize(find.byKey(photoRailControlsKey)).width,
        lessThanOrEqualTo(photoRailFullMinWidth),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('drops to thumbnails when the composer is short of height',
        (WidgetTester tester) async {
      await pumpPhotoRail(
        tester,
        text: twoPhotos,
        maxHeight: photoRailFullHeight - 1,
      );

      expect(find.byKey(photoRailControlsKey), findsNothing);
      expect(find.byKey(photoRailThumbKey(0)), findsOneWidget);
    });

    testWidgets('keeps a slim Add photo tile when there is no room for thumbnails',
        (WidgetTester tester) async {
      final FakePhotoImporter importer = FakePhotoImporter(
        results: <List<String>>[
          <String>[prefixOf(photoIdC)],
        ],
      );
      final TextEditingController controller = await pumpPhotoRail(
        tester,
        text: twoPhotos,
        maxHeight: photoRailCompactHeight - 1,
        importer: importer,
      );

      expect(find.byKey(photoRailAddKey), findsOneWidget);
      expect(
        tester.getSize(find.byKey(photoRailAddKey)),
        const Size(photoRailSlimHeight, photoRailSlimHeight),
      );
      expect(find.byKey(photoRailThumbKey(0)), findsNothing);
      expect(find.byKey(photoRailControlsKey), findsNothing);

      await tester.tap(find.byKey(photoRailAddKey));
      await tester.pump();

      expect(importer.calls, 1);
      expect(controller.text, contains(photoLine(photoIdC)));
      expect(notePhotoLines(controller.text), hasLength(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a slim tile reports a failed pick in a toast with a close glyph',
        (WidgetTester tester) async {
      await pumpPhotoRail(
        tester,
        text: twoPhotos,
        maxHeight: photoRailCompactHeight - 1,
        importer: FakePhotoImporter(error: denialError),
      );

      await tester.tap(find.byKey(photoRailAddKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(denialError.message), findsOneWidget);
      expect(
        tester
            .widget<IconStickerGlyphIcon>(find.byType(IconStickerGlyphIcon))
            .glyph,
        IconStickerGlyph.close,
      );

      await tester.pump(kToastLifetime);
    });

    testWidgets('controls are disabled with nothing selected until a photo is',
        (WidgetTester tester) async {
      await pumpPhotoRail(tester, text: twoPhotos, selection: caretAt(0));

      final Semantics remove = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(photoRemoveKey),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(remove.properties.enabled, isFalse);
      final Semantics medium = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byKey(photoSizeKey(PhotoSize.medium)),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(medium.properties.selected, isFalse);
    });
  });

  group('Side control', () {
    testWidgets('is hidden entirely when planFloat says the measure cannot float',
        (WidgetTester tester) async {
      await pumpPhotoRail(
        tester,
        text: twoPhotos,
        selection: caretAt(twoPhotos.indexOf(a)),
        measure: 420,
      );

      expect(canFloatAt(measure: 420, em: 16), isFalse);
      expect(find.byKey(photoSideControlKey), findsNothing);
      expect(find.byKey(photoSizeControlKey), findsOneWidget);
    });

    testWidgets('writes the side into the title slot where it can float',
        (WidgetTester tester) async {
      final TextEditingController controller = await pumpPhotoRail(
        tester,
        text: twoPhotos,
        selection: caretAt(twoPhotos.indexOf(a)),
      );

      await tester.tap(find.byKey(photoSideKey(PhotoSide.left)));
      await tester.pump();

      expect(notePhotoLines(controller.text)[0].placement.side, PhotoSide.left);
      expect(notePhotoLines(controller.text)[1].placement.side, PhotoSide.right);
    });
  });

  group('tap controls', () {
    testWidgets('Size rewrites only the active photo', (WidgetTester tester) async {
      final TextEditingController controller = await pumpPhotoRail(
        tester,
        text: twoPhotos,
        selection: caretAt(twoPhotos.indexOf(b)),
      );

      await tester.tap(find.byKey(photoSizeKey(PhotoSize.large)));
      await tester.pump();

      expect(
        controller.text,
        twoPhotos.replaceFirst(b, photoLine(photoIdB, size: PhotoSize.large)),
      );
      expect(_thumbSelected(tester, 1), isTrue);
    });

    testWidgets('Move up and Move down carry the highlight with the photo',
        (WidgetTester tester) async {
      final TextEditingController controller = await pumpPhotoRail(
        tester,
        text: twoPhotos,
        selection: caretAt(twoPhotos.indexOf(b)),
      );

      await tester.tap(find.byKey(photoMoveUpKey));
      await tester.pump();

      expect(controller.text, 'one\n$a\n$b\nmiddle\ntwo');
      expect(photoLineIndexAtCaret(controller.text, controller.selection), 1);

      await tester.tap(find.byKey(photoMoveUpKey));
      await tester.pump();

      expect(controller.text, 'one\n$b\n$a\nmiddle\ntwo');
      expect(photoLineIndexAtCaret(controller.text, controller.selection), 0);

      await tester.tap(find.byKey(photoMoveDownKey));
      await tester.pump();
      await tester.tap(find.byKey(photoMoveDownKey));
      await tester.pump();

      expect(controller.text, twoPhotos);
    });

    testWidgets('Replace swaps the photo and keeps caption and placement',
        (WidgetTester tester) async {
      final String captioned =
          photoLine(photoIdA, caption: 'porch', size: PhotoSize.small);
      final TextEditingController controller = await pumpPhotoRail(
        tester,
        text: captioned,
        selection: caretAt(0),
        importer: FakePhotoImporter(
          results: <List<String>>[
            <String>[prefixOf(photoIdC)],
          ],
        ),
      );

      await tester.tap(find.byKey(photoReplaceKey));
      await tester.pump();

      expect(
        controller.text,
        photoLine(photoIdC, caption: 'porch', size: PhotoSize.small),
      );
    });

    testWidgets('Caption opens the caption editor and writes the alt slot',
        (WidgetTester tester) async {
      final TextEditingController controller = await pumpPhotoRail(
        tester,
        text: 'one\n$a',
        selection: caretAt(5),
      );

      await tester.tap(find.byKey(photoCaptionKey));
      await tester.pumpAndSettle();

      expect(find.text(photoCaptionTitle), findsOneWidget);
      expect(find.text(photoCaptionHelp), findsOneWidget);
      await tester.enterText(find.byKey(photoCaptionFieldKey), 'the old porch');
      await tester.tap(find.byKey(photoCaptionSaveKey));
      await tester.pumpAndSettle();

      expect(controller.text, 'one\n${photoLine(photoIdA, caption: 'the old porch')}');
      expect(find.byKey(photoCaptionFieldKey), findsNothing);
    });

    testWidgets('Remove emits Photo removed · Undo, and Undo restores the line '
        'byte for byte', (WidgetTester tester) async {
      const String crlf = 'one\r\n';
      final String source = '$crlf$a\r\n  \ntwo';
      final TextSelection caret = caretAt(source.indexOf(a) + 7);
      final TextEditingController controller = await pumpPhotoRail(
        tester,
        text: source,
        selection: caret,
      );

      await tester.tap(find.byKey(photoRemoveKey));
      await tester.pump();

      expect(controller.text, '$crlf  \ntwo');
      expect(find.text(photoRemovedMessage), findsOneWidget);
      expect(find.text(photoRemovedUndoLabel), findsOneWidget);
      expectTargetAtLeast48(
        tester,
        find.ancestor(
          of: find.text(photoRemovedUndoLabel),
          matching: find.byType(GestureDetector),
        ).first,
      );

      await tester.tap(find.text(photoRemovedUndoLabel));
      await tester.pump();

      expect(controller.text, source);
      expect(controller.selection, caret);
      expect(find.text(photoRemovedMessage), findsNothing);
    });

    testWidgets('the removal notice leaves on its own',
        (WidgetTester tester) async {
      await pumpPhotoRail(tester, text: a, selection: caretAt(0));

      await tester.tap(find.byKey(photoRemoveKey));
      await tester.pump();
      expect(find.text(photoRemovedMessage), findsOneWidget);

      await tester.pump(photoRemovedNoticeLifetime);
      expect(find.text(photoRemovedMessage), findsNothing);
    });
  });

  group('mini-diagram', () {
    testWidgets('is driven by the same planFloat the renderer calls',
        (WidgetTester tester) async {
      final FakeNoteMediaResolver resolver = FakeNoteMediaResolver(
        <String, ResolvedMedia>{
          prefixOf(photoIdA): availablePhoto(photoIdA, width: 1200, height: 900),
        },
      )..memoizeAll();
      await pumpPhotoRail(
        tester,
        text: twoPhotos,
        selection: caretAt(twoPhotos.indexOf(a)),
        resolver: resolver,
      );

      final PhotoPlacementDiagram diagram =
          tester.widget<PhotoPlacementDiagram>(
        find.byType(PhotoPlacementDiagram),
      );
      final PhotoPlan expected = planFloat(
        measure: 560,
        em: 16,
        side: PhotoSide.right,
        size: PhotoSize.medium,
        aspect: 1200 / 900,
        nextIsParagraph: true,
      );
      expect(expected.isStacked, isFalse);
      expect(diagram.plan, expected);
      expect(
        find.text('Right · Medium — on this screen, text wraps beside it'),
        findsOneWidget,
      );
    });

    testWidgets('the diagram re-plans once the photo resolves',
        (WidgetTester tester) async {
      final _PendingMediaResolver resolver = _PendingMediaResolver();
      await pumpPhotoRail(
        tester,
        text: twoPhotos,
        selection: caretAt(twoPhotos.indexOf(a)),
        resolver: resolver,
      );

      expect(
        find.text('Right · Medium — on this screen, text sits above and below'),
        findsOneWidget,
      );

      resolver.pending.complete(
        availablePhoto(photoIdA, width: 1200, height: 900),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Right · Medium — on this screen, text wraps beside it'),
        findsOneWidget,
      );
    });

    testWidgets('the diagram stacks a photo whose next block is not a paragraph',
        (WidgetTester tester) async {
      final String adjacent = 'one\n$a\n$b\ntwo';
      final FakeNoteMediaResolver resolver = FakeNoteMediaResolver(
        <String, ResolvedMedia>{
          prefixOf(photoIdA): availablePhoto(photoIdA, width: 1200, height: 900),
        },
      )..memoizeAll();
      await pumpPhotoRail(
        tester,
        text: adjacent,
        selection: caretAt(adjacent.indexOf(a)),
        resolver: resolver,
      );

      expect(
        find.text('Right · Medium — on this screen, text sits above and below'),
        findsOneWidget,
      );
    });

    testWidgets('names no side on a measure that cannot float',
        (WidgetTester tester) async {
      await pumpPhotoRail(
        tester,
        text: twoPhotos,
        selection: caretAt(twoPhotos.indexOf(a)),
        measure: 420,
      );

      expect(
        find.text('Medium — on this screen, text sits above and below'),
        findsOneWidget,
      );
    });
  });

  group('no drag anywhere', () {
    test('no drag or reorder API appears in the unit source', () {
      final RegExp drag = RegExp(
        r'Draggable|DragTarget|DragGestureRecognizer|ReorderableList|'
        r'onPan[A-Z]|onHorizontalDrag|onVerticalDrag|onScale[A-Z]|'
        r'onLongPressMoveUpdate|ScaleGestureRecognizer',
      );
      final List<String> offenders = <String>[
        for (final File file in _dartSourcesUnder('lib/features/notes'))
          if (drag.hasMatch(file.readAsStringSync())) file.path,
      ];

      expect(_dartSourcesUnder('lib/features/notes'), isNotEmpty);
      expect(offenders, isEmpty);
    });

    testWidgets('no gesture detector in the rail listens for a drag',
        (WidgetTester tester) async {
      await pumpPhotoRail(
        tester,
        text: twoPhotos,
        selection: caretAt(twoPhotos.indexOf(a)),
      );

      final Iterable<GestureDetector> detectors =
          tester.widgetList<GestureDetector>(
        find.descendant(of: _rail, matching: find.byType(GestureDetector)),
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
