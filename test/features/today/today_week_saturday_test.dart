import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/today/today_week.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('weekDateKeys', () {
    test('starts a Saturday week on the most recent Saturday', () {
      expect(
        weekDateKeys(
          today: DateTime(2026, 9, 30),
          weekStart: WeekStart.saturday,
        ),
        <String>[
          '2026-09-26',
          '2026-09-27',
          '2026-09-28',
          '2026-09-29',
          '2026-09-30',
          '2026-10-01',
          '2026-10-02',
        ],
      );

      expect(
        weekDateKeys(
          today: DateTime(2026, 9, 26),
          weekStart: WeekStart.saturday,
        ).first,
        '2026-09-26',
      );
    });
  });

  group('buildWeekCells', () {
    test('with a Saturday start lists Saturday first', () {
      final DateTime today = DateTime(2026, 9, 30);
      final List<TodayWeekCell> cells = buildWeekCells(
        today: today,
        weekStart: WeekStart.saturday,
        days: const <Day>[],
      );

      expect(cells.first.date, '2026-09-26');
      expect(cells.where((TodayWeekCell c) => c.isToday).length, 1);
    });
  });
}
