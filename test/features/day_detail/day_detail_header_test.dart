import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/day_detail/day_detail_header.dart';

import 'support/day_detail_harness.dart';

void main() {
  testWidgets('renders the formatted day title and year subtitle',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      dayDetailHarness(
        DayDetailHeader(date: '2026-07-19', onClose: () {}),
      ),
    );

    expect(find.text('Sunday, July 19'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('tapping close invokes the callback',
      (WidgetTester tester) async {
    int closes = 0;
    await tester.pumpWidget(
      dayDetailHarness(
        DayDetailHeader(date: '2026-07-19', onClose: () => closes++),
      ),
    );

    await tester.tap(find.text('Close'));
    await tester.pump();

    expect(closes, 1);
  });
}
