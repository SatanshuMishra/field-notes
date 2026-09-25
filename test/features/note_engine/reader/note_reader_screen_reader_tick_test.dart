import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/note_engine/reader/note_reader_view.dart';
import 'package:field_notes/features/notes/render/note_photo_block.dart'
    show NoteMediaScope;

import '../../notes/support/notes_harness.dart';

void main() {
  testWidgets('a checkbox node offers a tap that reaches the task handler', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final List<int> toggled = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: NoteMediaScope(
            resolver: FakeNoteMediaResolver()..memoizeAll(),
            child: NoteReaderView(
              source: '- [ ] call the ferry office',
              onToggleTask: toggled.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final SemanticsNode box = find.semantics
        .byLabel('call the ferry office')
        .evaluate()
        .single;
    expect(box.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    tester.semantics.tap(find.semantics.byLabel('call the ferry office'));
    await tester.pump();

    expect(toggled, <int>[2]);
    handle.dispose();
  });

  testWidgets('a reader without a task handler offers no tap on its checkbox', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: NoteMediaScope(
            resolver: FakeNoteMediaResolver()..memoizeAll(),
            child: const NoteReaderView(source: '- [ ] call the ferry office'),
          ),
        ),
      ),
    );
    await tester.pump();

    final SemanticsNode box = find.semantics
        .byLabel('call the ferry office')
        .evaluate()
        .single;
    expect(box.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    handle.dispose();
  });
}
