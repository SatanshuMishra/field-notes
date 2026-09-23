import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/day_detail/day_detail_header.dart';

import 'support/day_detail_harness.dart';

final DateTime _today = DateTime(2026, 7, 23, 9);

void main() {
  testWidgets('renders the kicker, the day title and a back button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      dayDetailHarness(
        DayDetailHeader(date: '2026-07-19', today: _today, onClose: () {}),
      ),
    );

    expect(find.text('a day in the garden'), findsOneWidget);
    expect(find.text('Sunday, July 19'), findsOneWidget);
    expect(find.text('2026'), findsNothing);
    expect(find.text('Close'), findsNothing);
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    expect(tester.getSize(find.byKey(dayDetailBackKey)), const Size(34, 34));
  });

  testWidgets('today reads as today in your garden',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      dayDetailHarness(
        DayDetailHeader(date: '2026-07-23', today: _today, onClose: () {}),
      ),
    );

    expect(find.text('today · in your garden'), findsOneWidget);
    expect(find.text('Thursday, July 23'), findsOneWidget);
  });

  testWidgets('tapping the back button invokes the callback',
      (WidgetTester tester) async {
    int closes = 0;
    await tester.pumpWidget(
      dayDetailHarness(
        DayDetailHeader(
          date: '2026-07-19',
          today: _today,
          onClose: () => closes++,
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pump();

    expect(closes, 1);
  });
}
