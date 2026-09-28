import 'package:field_notes/features/note_engine/reader/note_reader_view.dart';
import 'package:field_notes/features/notes/render/note_photo_block.dart'
    show NoteMediaScope;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../notes/support/notes_harness.dart';

void main() {
  testWidgets('a to-do in a numbered list leaves no stray number', (
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
            child: NoteReaderView(
              source:
                  'Errands\n\n1. post the letters\n2. [ ] call the ferry office\n',
              onToggleTask: (int _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final List<String> labels = <String>[
      for (final SemanticsNode node
          in find.semantics
              .byPredicate((SemanticsNode node) => node.label.isNotEmpty)
              .evaluate())
        node.label,
    ];
    final List<String> lines = <String>[
      for (final String label in labels) ...label.split('\n'),
    ];
    expect(
      lines.where((String line) => RegExp(r'^\s*\d+\.\s*$').hasMatch(line)),
      isEmpty,
      reason: '$labels',
    );
    expect(
      labels.where((String label) => label.contains('call the ferry office')),
      hasLength(1),
      reason: '$labels',
    );
    expect(
      labels.where((String label) => label.contains('post the letters')),
      hasLength(1),
      reason: '$labels',
    );
    handle.dispose();
  });
}
