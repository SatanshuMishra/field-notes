import 'package:field_notes/features/calendar/model/calendar_month.dart';
import 'package:field_notes/features/calendar/widgets/calendar_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('shows the explore eyebrow and the month title',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        CalendarHeader(
          month: const MonthRef(2026, 7),
          onPreviousMonth: () {},
          onNextMonth: () {},
        ),
      ),
    );

    expect(find.text('explore'), findsOneWidget);
    expect(find.text('July 2026'), findsOneWidget);
  });

  testWidgets('chevrons invoke the month callbacks',
      (WidgetTester tester) async {
    int prev = 0;
    int next = 0;
    await tester.pumpWidget(
      _host(
        CalendarHeader(
          month: const MonthRef(2026, 7),
          onPreviousMonth: () => prev++,
          onNextMonth: () => next++,
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Previous month'));
    await tester.tap(find.bySemanticsLabel('Next month'));

    expect(prev, 1);
    expect(next, 1);
  });
}
