import 'package:field_notes/data/database/app_database.dart' as db;
import 'package:field_notes/data/journal/journal_mappers.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/note_body.dart';
import 'package:field_notes/features/entry_cards/compact/compact_log_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/entry_cards_harness.dart';

const String _device = 'Galaxy S24 Ultra';
const String _label = 'Conflict copy from Galaxy S24 Ultra';

Entry _note(String text, {String? conflictSourceDevice, String id = 'e1'}) =>
    Entry(
      id: id,
      dayId: 'd1',
      type: EntryType.text,
      textContent: text,
      createdAt: DateTime(2026, 10, 4, 8, 30).millisecondsSinceEpoch,
      updatedAt: DateTime(2026, 10, 4, 8, 30).millisecondsSinceEpoch,
      conflictSourceDevice: conflictSourceDevice,
    );

String _longText() =>
    'The peonies finally opened along the back fence. ${'Petals everywhere. ' * 20}';

Future<void> _pumpCards(WidgetTester tester, List<Entry> entries) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            for (final Entry entry in entries)
              CompactLogCard(
                key: ValueKey<String>(entry.id),
                entry: entry,
                resolver: FakeMediaResolver(),
                density: CompactLogDensity.feed,
                onOpen: () {},
                onEdit: () {},
                onDelete: () {},
              ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _labelIn(String id) => find.descendant(
  of: find.byKey(ValueKey<String>(id)),
  matching: find.text(_label),
);

void main() {
  testWidgets('a conflict copy shows its source device', (
    WidgetTester tester,
  ) async {
    await _pumpCards(tester, <Entry>[
      _note('the harbour at dawn', conflictSourceDevice: _device, id: 'short'),
      _note(_longText(), conflictSourceDevice: _device, id: 'long'),
      _note('the harbour at dusk', id: 'plain'),
    ]);

    expect(_labelIn('short'), findsOneWidget);
    expect(_labelIn('long'), findsOneWidget);
    expect(_labelIn('plain'), findsNothing);
    expect(find.text(_label), findsNWidgets(2));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NoteBody(
            text: 'the harbour at dawn',
            conflictSourceDevice: _device,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_label), findsOneWidget);
  });

  test('the journal carries a conflict copy source device to the entry', () {
    const db.Entry row = db.Entry(
      id: 'e1',
      dayId: 'd1',
      type: 'text',
      textContent: 'the harbour at dawn',
      createdAt: 1,
      updatedAt: 1,
      conflictSourceDevice: _device,
      textVersion: '{}',
      fieldClocks: '{}',
    );
    final Entry entry = toDomainEntry(row);

    expect(entry.conflictSourceDevice, _device);
    expect(
      entry,
      isNot(
        Entry(
          id: entry.id,
          dayId: entry.dayId,
          type: entry.type,
          textContent: entry.textContent,
          createdAt: entry.createdAt,
          updatedAt: entry.updatedAt,
        ),
      ),
    );
    expect(_note('x').conflictSourceDevice, isNull);
  });
}
