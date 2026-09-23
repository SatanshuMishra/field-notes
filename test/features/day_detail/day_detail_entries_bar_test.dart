import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/day_detail/day_detail_entries_bar.dart';

import 'support/day_detail_harness.dart';

void main() {
  test('pluralises the log count', () {
    expect(dayDetailEntryCountLabel(0), '0 logs that day');
    expect(dayDetailEntryCountLabel(1), '1 log that day');
    expect(dayDetailEntryCountLabel(2), '2 logs that day');
    expect(dayDetailEntryCountLabel(11), '11 logs that day');
  });

  testWidgets('renders the count and the add-a-note action',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      dayDetailHarness(
        DayDetailEntriesBar(entryCount: 3, onAddNote: () {}),
      ),
    );

    expect(find.text('3 logs that day'), findsOneWidget);
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
    expect(find.text('0 logs that day'), findsOneWidget);
  });

  testWidgets('renders no count text when the count is unknown',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      dayDetailHarness(
        DayDetailEntriesBar(entryCount: null, onAddNote: () {}),
      ),
    );

    expect(find.text('0 logs that day'), findsNothing);
    expect(find.text('Add a note'), findsOneWidget);
  });
}
