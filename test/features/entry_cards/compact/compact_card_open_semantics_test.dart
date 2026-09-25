import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/compact/compact_log_card.dart';

import '../support/entry_cards_harness.dart';

final class _Counts {
  int opens = 0;
  int edits = 0;
  int deletes = 0;
}

Future<_Counts> _pumpCard(WidgetTester tester, Entry entry) async {
  final _Counts counts = _Counts();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          children: <Widget>[
            CompactLogCard(
              entry: entry,
              resolver: FakeMediaResolver(),
              density: CompactLogDensity.feed,
              onOpen: () => counts.opens++,
              onEdit: () => counts.edits++,
              onDelete: () => counts.deletes++,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  return counts;
}

Entry _entry(EntryType type, {String? textContent, int? durationMs}) {
  final int at = DateTime(2026, 9, 23, 23, 45).millisecondsSinceEpoch;
  return Entry(
    id: 'e1',
    dayId: 'd1',
    type: type,
    textContent: textContent,
    durationMs: durationMs,
    createdAt: at,
    updatedAt: at,
  );
}

bool _tappable(SemanticsNode node) =>
    node.getSemanticsData().hasAction(SemanticsAction.tap);

int _count(String haystack, String needle) =>
    RegExp(RegExp.escape(needle)).allMatches(haystack).length;

FinderBase<SemanticsNode> _unlabelledTappable() => find.semantics.byPredicate(
  (SemanticsNode node) => _tappable(node) && node.label.isEmpty,
);

FinderBase<SemanticsNode> _openButton() => find.semantics.byPredicate(
  (SemanticsNode node) => _tappable(node) && node.label.contains('23:45'),
);

void main() {
  testWidgets('a note card has one open button that reads its header once', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final _Counts counts = await _pumpCard(
      tester,
      _entry(EntryType.text, textContent: 'Harbour walk\nThe boats were in.'),
    );

    expect(_unlabelledTappable(), findsNothing);
    expect(_openButton(), findsOne);
    final String label = _openButton().evaluate().single.label;
    expect(_count(label, '23:45'), 1);
    expect(label, isNot(contains('Harbour walk')));
    expect(find.semantics.byLabel(RegExp('Harbour walk')), findsOne);
    tester.semantics.tap(_openButton());
    await tester.pump();
    expect(counts.opens, 1);
    handle.dispose();
  });

  testWidgets('a video card reads its header, length and Watch in one open button', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final _Counts counts = await _pumpCard(
      tester,
      _entry(EntryType.video, durationMs: 16000),
    );

    expect(_unlabelledTappable(), findsNothing);
    expect(_openButton(), findsOne);
    final String label = _openButton().evaluate().single.label;
    expect(_count(label, '23:45'), 1);
    expect(label, contains('0:16'));
    expect(label, contains('Watch'));
    tester.semantics.tap(_openButton());
    await tester.pump();
    expect(counts.opens, 1);
    handle.dispose();
  });

  testWidgets('a card keeps its long press and its Edit and Delete actions', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final _Counts counts = await _pumpCard(
      tester,
      _entry(EntryType.text, textContent: 'Harbour walk\nThe boats were in.'),
    );

    final FinderBase<SemanticsNode> reveal = find.semantics.byPredicate(
      (SemanticsNode node) =>
          node.getSemanticsData().hasAction(SemanticsAction.customAction) &&
          node.getSemanticsData().hasAction(SemanticsAction.longPress),
    );
    expect(reveal, findsOne);
    tester.semantics.customAction(
      reveal,
      const CustomSemanticsAction(label: 'Edit note'),
    );
    await tester.pump();
    tester.semantics.customAction(
      reveal,
      const CustomSemanticsAction(label: 'Delete entry'),
    );
    await tester.pump();
    expect(counts.edits, 1);
    expect(counts.deletes, 1);
    expect(counts.opens, 0);
    handle.dispose();
  });
}
