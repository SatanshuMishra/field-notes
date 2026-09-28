import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/compact/compact_log_card.dart';

import '../support/entry_cards_harness.dart';

void main() {
  testWidgets('a to-do on a card is its own node and ticks by screen reader', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final List<int> toggled = <int>[];
    int opens = 0;
    final int at = DateTime(2026, 9, 24, 23, 48).millisecondsSinceEpoch;
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
                  textContent: '- [ ] call the ferry office',
                  createdAt: at,
                  updatedAt: at,
                ),
                resolver: FakeMediaResolver(),
                density: CompactLogDensity.feed,
                onOpen: () => opens++,
                onToggleTask: toggled.add,
                onEdit: () {},
                onDelete: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final SemanticsNode box = find.semantics
        .byLabel('call the ferry office')
        .evaluate()
        .single;
    expect(box.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    tester.semantics.tap(find.semantics.byLabel('call the ferry office'));
    await tester.pump();

    expect(toggled, <int>[2]);
    expect(opens, 0);
    handle.dispose();
  });
}
