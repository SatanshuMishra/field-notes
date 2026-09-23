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
    test(
        'leads with neighbouring-month days and places day 1 after them '
        '(July 2026, Sun start)', () {
      final List<CalendarCell> cells = monthGridCells(const MonthRef(2026, 7));

      expect(cells.length % 7, 0);
      expect(cells.take(3).every((CalendarCell c) => !c.isInMonth), isTrue);
      expect(
        cells.take(3).map((CalendarCell c) => c.dateKey),
        <String>['2026-06-28', '2026-06-29', '2026-06-30'],
      );
      expect(cells[3].isInMonth, isTrue);
      expect(cells[3].dayOfMonth, 1);
      expect(cells[3].dateKey, '2026-07-01');

      final List<CalendarCell> days =
          cells.where((CalendarCell c) => c.isInMonth).toList();
      expect(days.length, 31);
      expect(days.last.dateKey, '2026-07-31');
      expect(cells.last.isInMonth, isFalse);
      expect(cells.last.dateKey, '2026-08-01');
    });

    test('honours a Monday week-start by shifting the leading neighbours', () {
      final List<CalendarCell> sun = monthGridCells(const MonthRef(2026, 7));
      final List<CalendarCell> mon =
          monthGridCells(const MonthRef(2026, 7), firstWeekday: DateTime.monday);

      final int sunLead = sun.indexWhere((CalendarCell c) => c.isInMonth);
      final int monLead = mon.indexWhere((CalendarCell c) => c.isInMonth);
      expect(sunLead, 3);
      expect(monLead, 2);
      expect(mon.first.dateKey, '2026-06-29');
    });

    test('spans as many week rows as the month needs', () {
      expect(monthGridCells(const MonthRef(2026, 2)).length, 28);
      expect(monthGridCells(const MonthRef(2026, 7)).length, 35);
      expect(monthGridCells(const MonthRef(2026, 8)).length, 42);
    });

    test('crosses the year boundary for neighbouring days', () {
      final List<CalendarCell> cells = monthGridCells(const MonthRef(2026, 1));

      expect(cells.first.dateKey, '2025-12-28');
      expect(cells.first.isInMonth, isFalse);
    });

    test('counts leap-February days', () {
      final List<CalendarCell> days = monthGridCells(const MonthRef(2024, 2))
          .where((CalendarCell c) => c.isInMonth)
          .toList();
      expect(days.length, 29);
    });
  });

  group('weekdayHeaders', () {
    test('Sunday start begins with S', () {
      expect(
        weekdayHeaders(),
        <String>['S', 'M', 'T', 'W', 'T', 'F', 'S'],
      );
    });

    test('Monday start begins with M', () {
      expect(
        weekdayHeaders(firstWeekday: DateTime.monday),
        <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'],
      );
    });
  });
}
