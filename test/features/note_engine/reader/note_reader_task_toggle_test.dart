import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/reader/note_reader_view.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';
import 'package:field_notes/features/notes/render/note_photo_block.dart'
    show NoteMediaScope;

import '../../notes/support/notes_harness.dart';

Future<RenderNoteView> _pumpReader(
  WidgetTester tester,
  String source,
  ValueChanged<int>? onToggleTask,
) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: NoteMediaScope(
          resolver: FakeNoteMediaResolver()..memoizeAll(),
          child: NoteReaderView(source: source, onToggleTask: onToggleTask),
        ),
      ),
    ),
  );
  await tester.pump();
  return tester.renderObject<RenderNoteView>(
    find.descendant(
      of: find.byType(NoteReaderView),
      matching: find.byType(NoteViewBody),
    ),
  );
}

Offset _boxCenter(RenderNoteView render) => render.contentToGlobal(
  render.noteLayout.rangeBounds(const MdRange(2, 5)).center,
);

void main() {
  testWidgets(
    'a press on a checkbox reports its offset to the toggle handler',
    (WidgetTester tester) async {
      const String source = '- [ ] call the ferry office';
      final List<int> toggled = <int>[];
      final RenderNoteView render = await _pumpReader(
        tester,
        source,
        toggled.add,
      );
      await tester.tapAt(_boxCenter(render));
      await tester.pump();

      expect(toggled, <int>[2]);
      expect(render.selection, isNull);
      expect(render.source, source);
    },
  );

  testWidgets(
    'a click on a checkbox reports its offset and selects nothing',
    (WidgetTester tester) async {
      final List<int> toggled = <int>[];
      final RenderNoteView render = await _pumpReader(
        tester,
        '- [x] call the ferry office\nand the harbour master',
        toggled.add,
      );
      final TestGesture mouse = await tester.startGesture(
        _boxCenter(render),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 60));
      await mouse.up();
      await tester.pump();

      expect(toggled, <int>[2]);
      expect(render.selection, isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('a press on the text beside a checkbox reports nothing', (
    WidgetTester tester,
  ) async {
    final List<int> toggled = <int>[];
    final RenderNoteView render = await _pumpReader(
      tester,
      '- [ ] call the ferry office',
      toggled.add,
    );
    await tester.tapAt(
      render.contentToGlobal(
        render.noteLayout.rangeBounds(const MdRange(15, 20)).center,
      ),
    );
    await tester.pump();

    expect(toggled, isEmpty);
  });
}
