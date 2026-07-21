import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/calendar/model/calendar_month.dart';
import 'package:field_notes/features/calendar/widgets/calendar_grid.dart';
import 'package:field_notes/features/calendar/widgets/calendar_weekday_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: SizedBox(width: 420, height: 520, child: child)),
    );

Day _day(String date, {Mood? mood}) => Day(
      id: 'id-$date',
      date: date,
      mood: mood,
      createdAt: 0,
      updatedAt: 0,
    );

void main() {
  testWidgets('renders the weekday bar and a flower for a mood day',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        CalendarGrid(
          month: const MonthRef(2026, 7),
          daysByDate: <String, Day>{
            '2026-07-14': _day('2026-07-14', mood: Mood.happy),
          },
          onSelectDay: (_) {},
        ),
      ),
    );

    expect(find.byType(CalendarWeekdayBar), findsOneWidget);
    expect(find.byType(FlowerBloom), findsOneWidget);
  });

  testWidgets('tapping a day fires onSelectDay with that date key',
      (WidgetTester tester) async {
    final List<String> selected = <String>[];
    await tester.pumpWidget(
      _host(
        CalendarGrid(
          month: const MonthRef(2026, 7),
          daysByDate: const <String, Day>{},
          onSelectDay: selected.add,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('day-2026-07-15')));
    expect(selected, <String>['2026-07-15']);
  });
}
