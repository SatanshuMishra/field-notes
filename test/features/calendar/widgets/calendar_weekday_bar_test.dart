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
          labels: <String>['S', 'M', 'T', 'W', 'T', 'F', 'S'],
        ),
      ),
    );

    expect(find.text('S'), findsNWidgets(2));
    expect(find.text('M'), findsOneWidget);
    expect(find.text('T'), findsNWidgets(2));
    expect(find.text('W'), findsOneWidget);
    expect(find.text('F'), findsOneWidget);
  });
}
