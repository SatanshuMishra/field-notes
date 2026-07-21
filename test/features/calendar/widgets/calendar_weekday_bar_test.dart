import 'package:field_notes/features/calendar/widgets/calendar_weekday_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders every label once', (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        const CalendarWeekdayBar(
          labels: <String>['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'],
        ),
      ),
    );

    for (final String label in <String>['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
