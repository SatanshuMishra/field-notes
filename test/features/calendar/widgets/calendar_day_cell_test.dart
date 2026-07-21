import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/calendar/model/calendar_month.dart';
import 'package:field_notes/features/calendar/widgets/calendar_day_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: SizedBox(width: 56, child: child))),
    );

Day _day(String date, {Mood? mood}) => Day(
      id: 'id-$date',
      date: date,
      mood: mood,
      createdAt: 0,
      updatedAt: 0,
    );

void main() {
  testWidgets('padding cell renders nothing tappable',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(const CalendarDayCell(cell: CalendarCell.padding())),
    );

    expect(find.byType(FlowerBloom), findsNothing);
    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('mood day renders its flower and the day number, and taps',
      (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      _host(
        CalendarDayCell(
          cell: const CalendarCell.day(dayOfMonth: 14, dateKey: '2026-07-14'),
          day: _day('2026-07-14', mood: Mood.happy),
          onTap: () => taps++,
        ),
      ),
    );

    expect(find.byType(FlowerBloom), findsOneWidget);
    expect(find.text('14'), findsOneWidget);

    await tester.tap(find.byType(CalendarDayCell));
    expect(taps, 1);
  });

  testWidgets('journaled but moodless day shows the number, no flower',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        CalendarDayCell(
          cell: const CalendarCell.day(dayOfMonth: 9, dateKey: '2026-07-09'),
          day: _day('2026-07-09'),
          onTap: () {},
        ),
      ),
    );

    expect(find.byType(FlowerBloom), findsNothing);
    expect(find.text('9'), findsOneWidget);
  });

  testWidgets('empty day (no Day row) still shows the number and taps',
      (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      _host(
        CalendarDayCell(
          cell: const CalendarCell.day(dayOfMonth: 20, dateKey: '2026-07-20'),
          onTap: () => taps++,
        ),
      ),
    );

    expect(find.byType(FlowerBloom), findsNothing);
    expect(find.text('20'), findsOneWidget);

    await tester.tap(find.byType(CalendarDayCell));
    expect(taps, 1);
  });
}
