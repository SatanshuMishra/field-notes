import 'package:field_notes/features/calendar/model/calendar_month.dart';
import 'package:field_notes/features/calendar/widgets/calendar_day_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Scaffold(
    body: Center(child: SizedBox(width: 56, child: child)),
  ),
);

void main() {
  testWidgets('a day with entries says so', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        CalendarDayCell(
          cell: const CalendarCell.day(dayOfMonth: 23, dateKey: '2026-07-23'),
          hasEntries: true,
          onTap: () {},
        ),
      ),
    );

    expect(find.bySemanticsLabel('Day 23, has entries'), findsOneWidget);
    expect(find.bySemanticsLabel('23'), findsNothing);
    handle.dispose();
  });
}
