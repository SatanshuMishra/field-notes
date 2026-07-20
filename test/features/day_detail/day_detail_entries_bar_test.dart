import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/day_detail/day_detail_entries_bar.dart';

import 'support/day_detail_harness.dart';

void main() {
  test('pluralises the entry count', () {
    expect(dayDetailEntryCountLabel(0), 'No entries yet');
    expect(dayDetailEntryCountLabel(1), '1 entry');
    expect(dayDetailEntryCountLabel(2), '2 entries');
    expect(dayDetailEntryCountLabel(11), '11 entries');
  });

  testWidgets('renders the count and the add-a-note action',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      dayDetailHarness(
        DayDetailEntriesBar(entryCount: 3, onAddNote: () {}),
      ),
    );

    expect(find.text('3 entries'), findsOneWidget);
    expect(find.text('Add a note'), findsOneWidget);
  });

  testWidgets('tapping add a note invokes the callback',
      (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      dayDetailHarness(
        DayDetailEntriesBar(entryCount: 0, onAddNote: () => taps++),
      ),
    );

    await tester.tap(find.text('Add a note'));
    await tester.pump();

    expect(taps, 1);
    expect(find.text('No entries yet'), findsOneWidget);
  });

  testWidgets('renders no count text when the count is unknown',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      dayDetailHarness(
        DayDetailEntriesBar(entryCount: null, onAddNote: () {}),
      ),
    );

    expect(find.text('No entries yet'), findsNothing);
    expect(find.text('0 entries'), findsNothing);
    expect(find.text('Add a note'), findsOneWidget);
  });
}
