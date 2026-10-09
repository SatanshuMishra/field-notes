import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/editor/composer_media_scope.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_controller.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_view.dart';
import 'package:field_notes/features/note_engine/platform/file_drop.dart';

import '../../notes/support/notes_harness.dart';

const String _reference = 'a1b2c3d4e5f6';
const String _note = 'A\n\nB';

final class _Drop {
  const _Drop({required this.imported, required this.source});

  final List<CaptureMedia> imported;
  final String source;
}

Future<File> _writePng(WidgetTester tester) async {
  final File? file = await tester.runAsync(() async {
    final Directory folder = await Directory.systemTemp.createTemp(
      'field_notes_file_drop_',
    );
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 4, 3),
      ui.Paint()..color = const ui.Color(0xFF336699),
    );
    final ui.Image image = await recorder.endRecording().toImage(4, 3);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    return File('${folder.path}/tide.png')
        .writeAsBytes(data!.buffer.asUint8List());
  });
  addTearDown(() => file!.parent.deleteSync(recursive: true));
  return file!;
}

Future<void> _deliverDrop(Offset position, List<String> paths) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          fileDropChannelName,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('drop', <String, Object?>{
              'x': position.dx,
              'y': position.dy,
              'paths': paths,
            }),
          ),
          (ByteData? _) {},
        );

Future<_Drop> _dropOnEditor(
  WidgetTester tester,
  TargetPlatform platform,
  String path,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    final NoteEditorController controller = NoteEditorController(text: _note);
    final FocusNode focusNode = FocusNode();
    final UndoHistoryController undo = UndoHistoryController();
    final ScrollController scroll = ScrollController();
    final List<CaptureMedia> imported = <CaptureMedia>[];
    await tester.pumpWidget(
      MaterialApp(
        key: ValueKey<TargetPlatform>(platform),
        home: Material(
          child: ComposerMediaScope(
            resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
              _reference: availablePhoto(photoIdA),
            })..memoizeAll(),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 688,
                height: 600,
                child: NoteEditorView(
                  controller: controller,
                  focusNode: focusNode,
                  undoController: undo,
                  scrollController: scroll,
                  photoMediaImporter: (CaptureMedia photo) async {
                    imported.add(photo);
                    return _reference;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Rect bounds = tester.getRect(find.byType(NoteEditorView));
    await _deliverDrop(bounds.topLeft + const Offset(40, 30), <String>[path]);
    for (
      int attempt = 0;
      attempt < 200 && !controller.state.source.contains(_reference);
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    final _Drop drop = _Drop(
      imported: List<CaptureMedia>.unmodifiable(imported),
      source: controller.state.source,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
    scroll.dispose();
    undo.dispose();
    focusNode.dispose();
    controller.dispose();
    return drop;
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  testWidgets(
    'a Windows editor imports photos dropped through the file drop channel',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final File photo = await _writePng(tester);

      final _Drop windows = await _dropOnEditor(
        tester,
        TargetPlatform.windows,
        photo.path,
      );
      expect(windows.imported, hasLength(1));
      final CaptureMedia capture = windows.imported.single;
      expect(capture, isA<CaptureFile>());
      expect((capture as CaptureFile).file.path, photo.path);
      expect(capture.mime, 'image/png');
      expect(
        RegExp('photo/$_reference').allMatches(windows.source),
        hasLength(1),
      );

      final _Drop android = await _dropOnEditor(
        tester,
        TargetPlatform.android,
        photo.path,
      );
      expect(android.imported, isEmpty);
      expect(android.source, _note);
    },
  );
}
