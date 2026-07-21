import 'package:field_notes/features/calendar/model/calendar_month.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MonthRef', () {
    test('title renders the English month name and year', () {
      expect(const MonthRef(2026, 7).title, 'July 2026');
      expect(const MonthRef(2026, 1).title, 'January 2026');
      expect(const MonthRef(2026, 12).title, 'December 2026');
    });

    test('dateKey zero-pads to YYYY-MM-DD', () {
      expect(const MonthRef(2026, 7).dateKey(5), '2026-07-05');
      expect(const MonthRef(2026, 12).dateKey(31), '2026-12-31');
    });

    test('previous and next roll the year over at the boundary', () {
      expect(const MonthRef(2026, 1).previous, const MonthRef(2025, 12));
      expect(const MonthRef(2026, 12).next, const MonthRef(2027, 1));
      expect(const MonthRef(2026, 7).next, const MonthRef(2026, 8));
      expect(const MonthRef(2026, 7).previous, const MonthRef(2026, 6));
    });

    test('forDate captures the year and month of the date', () {
      expect(MonthRef.forDate(DateTime(2026, 7, 15)), const MonthRef(2026, 7));
    });
  });

  group('monthGridCells', () {
    test('pads leading days and places day 1 after them (July 2026, Sun start)',
        () {
      final List<CalendarCell> cells = monthGridCells(const MonthRef(2026, 7));

      expect(cells.length % 7, 0);
      expect(cells.take(3).every((CalendarCell c) => c.isPadding), isTrue);
      expect(cells[3].isPadding, isFalse);
      expect(cells[3].dayOfMonth, 1);
      expect(cells[3].dateKey, '2026-07-01');

      final List<CalendarCell> days =
          cells.where((CalendarCell c) => !c.isPadding).toList();
      expect(days.length, 31);
      expect(days.last.dateKey, '2026-07-31');
    });

    test('honours a Monday week-start by shifting the leading padding', () {
      final List<CalendarCell> sun = monthGridCells(const MonthRef(2026, 7));
      final List<CalendarCell> mon =
          monthGridCells(const MonthRef(2026, 7), firstWeekday: DateTime.monday);

      final int sunLead = sun.indexWhere((CalendarCell c) => !c.isPadding);
      final int monLead = mon.indexWhere((CalendarCell c) => !c.isPadding);
      expect(sunLead, 3);
      expect(monLead, 2);
    });

    test('counts leap-February days', () {
      final List<CalendarCell> days = monthGridCells(const MonthRef(2024, 2))
          .where((CalendarCell c) => !c.isPadding)
          .toList();
      expect(days.length, 29);
    });
  });

  group('weekdayHeaders', () {
    test('Sunday start begins with Su', () {
      expect(
        weekdayHeaders(),
        <String>['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'],
      );
    });

    test('Monday start begins with Mo', () {
      expect(
        weekdayHeaders(firstWeekday: DateTime.monday),
        <String>['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'],
      );
    });
  });
}
