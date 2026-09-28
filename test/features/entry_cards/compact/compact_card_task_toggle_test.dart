import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/entry_cards/compact/compact_log_card.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteReaderView;
import 'package:field_notes/features/note_engine/render/render_note_view.dart'
    show NoteViewBody, RenderNoteView;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/entry_cards_harness.dart';

const String _source = '- [ ] call the ferry office';

final class _Card {
  final List<int> toggles = <int>[];
  int opens = 0;
}

Future<_Card> _pumpCard(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _Card card = _Card();
  final int at = DateTime(2025, 7, 2, 8, 30).millisecondsSinceEpoch;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            CompactLogCard(
              entry: Entry(
                id: 'e1',
                dayId: 'd1',
                type: EntryType.text,
                textContent: _source,
                createdAt: at,
                updatedAt: at,
              ),
              resolver: FakeMediaResolver(),
              density: CompactLogDensity.feed,
              onOpen: () => card.opens++,
              onToggleTask: card.toggles.add,
              onEdit: () {},
              onDelete: () {},
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return card;
}

Offset _sourceCenter(WidgetTester tester, int start, int end) {
  final RenderNoteView render = tester.renderObject<RenderNoteView>(
    find.descendant(
      of: find.byType(NoteReaderView),
      matching: find.byType(NoteViewBody),
    ),
  );
  return render.contentToGlobal(
    render.noteLayout.rangeBounds(MdRange(start, end)).center,
  );
}

void main() {
  testWidgets('a tap on a card checkbox ticks it without opening the note', (
    WidgetTester tester,
  ) async {
    final _Card card = await _pumpCard(tester);

    await tester.tapAt(_sourceCenter(tester, 2, 5));
    await tester.pumpAndSettle();

    expect(card.toggles, <int>[2]);
    expect(card.opens, 0);
  });

  testWidgets('a tap on the card text still opens the note', (
    WidgetTester tester,
  ) async {
    final _Card card = await _pumpCard(tester);

    await tester.tapAt(_sourceCenter(tester, 6, _source.length));
    await tester.pumpAndSettle();

    expect(card.opens, 1);
    expect(card.toggles, isEmpty);
  });
}
