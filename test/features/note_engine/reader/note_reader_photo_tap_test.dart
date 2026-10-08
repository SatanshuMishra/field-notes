import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart'
    show PhotoRect;
import 'package:field_notes/features/note_engine/reader/note_reader_view.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';
import 'package:field_notes/features/notes/render/note_photo_block.dart'
    show NoteMediaScope;

import '../../../support/photo_line_fixture.dart';
import '../../notes/support/notes_harness.dart'
    show
        FakeNoteMediaResolver,
        availablePhoto,
        photoIdA,
        photoIdB,
        photoIdC,
        prefixOf;

const String _intro = 'Low tide walk';
const Size _phone = Size(384, 832);

final String _note = <String>[
  _intro,
  mdPhotoLine(photoIdA, caption: 'The harbour wall', size: MdPhotoSize.small),
  'Out past the ferry office.',
  mdPhotoLine(photoIdB, caption: 'Gulls', size: MdPhotoSize.small),
  'Home before the rain.',
  mdPhotoLine(photoIdC, size: MdPhotoSize.small),
].join('\n\n');

Future<RenderNoteView> _pumpReader(
  WidgetTester tester,
  ValueChanged<int> onOpenPhoto,
) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 34, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 34, bottom: 24);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 50, 16, 0),
          child: NoteMediaScope(
            resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
              prefixOf(photoIdA): availablePhoto(
                photoIdA,
                width: 1600,
                height: 600,
              ),
              prefixOf(photoIdB): availablePhoto(
                photoIdB,
                width: 1600,
                height: 600,
              ),
              prefixOf(photoIdC): availablePhoto(
                photoIdC,
                width: 1600,
                height: 600,
              ),
            })..memoizeAll(),
            child: NoteReaderView(source: _note, onOpenPhoto: onOpenPhoto),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return tester.renderObject<RenderNoteView>(
    find.descendant(
      of: find.byType(NoteReaderView),
      matching: find.byType(NoteViewBody),
    ),
  );
}

Rect _imageOf(RenderNoteView render, String id) {
  final Rect image = render.noteLayout.photoRects
      .singleWhere((PhotoRect photo) => photo.reference == prefixOf(id))
      .imageRect;
  return render.contentToGlobal(image.topLeft) & image.size;
}

void main() {
  testWidgets('tapping a photo reports its index', (WidgetTester tester) async {
    final List<int> opened = <int>[];
    final RenderNoteView render = await _pumpReader(tester, opened.add);
    expect(render.noteLayout.photoRects, hasLength(3));
    final Rect screen = Offset.zero & _phone;
    final List<Rect> images = <Rect>[
      for (final String id in <String>[photoIdA, photoIdB, photoIdC])
        _imageOf(render, id),
    ];
    for (final Rect image in images) {
      expect(screen.contains(image.center), isTrue, reason: '$image');
    }

    await tester.tapAt(images[1].center);
    await tester.pump(const Duration(milliseconds: 400));
    expect(opened, <int>[1]);
    expect(render.selection, isNull);

    final int introAt = _note.indexOf(_intro);
    final Rect introBox = render.noteLayout.rangeBounds(
      MdRange(introAt, introAt + _intro.length),
    );
    final Offset text = render.contentToGlobal(introBox.center);
    expect(images.where((Rect image) => image.contains(text)), isEmpty);
    await tester.tapAt(text);
    await tester.pump(const Duration(milliseconds: 400));
    expect(opened, <int>[1]);

    final TestGesture mouse = await tester.startGesture(
      images[2].center,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(opened, <int>[1, 2]);
    expect(render.selection, isNull);

    final TestGesture textClick = await tester.startGesture(
      text,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 60));
    await textClick.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(opened, <int>[1, 2]);
    expect(render.selection, isNotNull);
  });
}
