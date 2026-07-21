import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/today/today_week.dart';
import 'package:flutter_test/flutter_test.dart';

Day _day({required String date, Mood? mood, int? deletedAt}) => Day(
      id: 'day-$date',
      date: date,
      mood: mood,
      createdAt: 0,
      updatedAt: 0,
      deletedAt: deletedAt,
    );

void main() {
  group('weekDateKeys', () {
    test('starts on Sunday when the week starts on Sunday', () {
      expect(
        weekDateKeys(today: DateTime(2026, 7, 22), weekStart: WeekStart.sunday),
        <String>[
          '2026-07-19',
          '2026-07-20',
          '2026-07-21',
          '2026-07-22',
          '2026-07-23',
          '2026-07-24',
          '2026-07-25',
        ],
      );
    });

    test('starts on Monday when the week starts on Monday', () {
      expect(
        weekDateKeys(today: DateTime(2026, 7, 22), weekStart: WeekStart.monday),
        <String>[
          '2026-07-20',
          '2026-07-21',
          '2026-07-22',
          '2026-07-23',
          '2026-07-24',
          '2026-07-25',
          '2026-07-26',
        ],
      );
    });

    test('crosses a month boundary without skipping a day', () {
      expect(
        weekDateKeys(today: DateTime(2026, 8, 1), weekStart: WeekStart.sunday),
        <String>[
          '2026-07-26',
          '2026-07-27',
          '2026-07-28',
          '2026-07-29',
          '2026-07-30',
          '2026-07-31',
          '2026-08-01',
        ],
      );
    });
  });

  group('buildWeekCells', () {
    test('attaches moods, labels weekdays and marks today', () {
      final List<TodayWeekCell> cells = buildWeekCells(
        today: DateTime(2026, 7, 22, 9),
        weekStart: WeekStart.sunday,
        days: <Day>[
          _day(date: '2026-07-20', mood: Mood.calm),
          _day(date: '2026-07-22', mood: Mood.happy),
          _day(date: '2026-07-23'),
          _day(date: '2026-06-01', mood: Mood.sad),
        ],
      );

      expect(cells.length, 7);
      expect(cells.first.date, '2026-07-19');
      expect(cells.first.weekdayLabel, 'Sun');
      expect(cells.first.mood, isNull);
      expect(cells[1].mood, Mood.calm);
      expect(cells[3].mood, Mood.happy);
      expect(cells[3].isToday, isTrue);
      expect(cells[4].mood, isNull);
      expect(cells.where((TodayWeekCell c) => c.isToday).length, 1);
      expect(
        cells.map((TodayWeekCell c) => c.weekdayLabel).toList(),
        <String>['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
      );
    });

    test('ignores tombstoned days', () {
      final List<TodayWeekCell> cells = buildWeekCells(
        today: DateTime(2026, 7, 22),
        weekStart: WeekStart.sunday,
        days: <Day>[_day(date: '2026-07-21', mood: Mood.angry, deletedAt: 1)],
      );

      expect(cells[2].date, '2026-07-21');
      expect(cells[2].mood, isNull);
    });
  });
}
