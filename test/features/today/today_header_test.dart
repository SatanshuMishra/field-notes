import 'package:field_notes/features/today/today_header.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/today_harness.dart';

void main() {
  testWidgets('renders the greeting above the long date',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      const TodayHeader(
        greeting: 'Good evening',
        longDate: 'Sunday, July 19, 2026',
      ),
    );

    expect(find.text('Good evening'), findsOneWidget);
    expect(find.text('Sunday, July 19, 2026'), findsOneWidget);

    final Offset greeting = tester.getTopLeft(find.text('Good evening'));
    final Offset date = tester.getTopLeft(find.text('Sunday, July 19, 2026'));
    expect(greeting.dy, lessThan(date.dy));
  });
}
