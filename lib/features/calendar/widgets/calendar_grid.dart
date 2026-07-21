import 'package:flutter/widgets.dart';

import 'package:field_notes/domain/models/models.dart';

import '../model/calendar_month.dart';
import 'calendar_day_cell.dart';
import 'calendar_weekday_bar.dart';

class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.month,
    required this.daysByDate,
    this.firstWeekday = DateTime.sunday,
    this.todayKey,
    required this.onSelectDay,
  });

  final MonthRef month;
  final Map<String, Day> daysByDate;
  final int firstWeekday;
  final String? todayKey;
  final void Function(String dateKey) onSelectDay;

  @override
  Widget build(BuildContext context) {
    final List<CalendarCell> cells =
        monthGridCells(month, firstWeekday: firstWeekday);
    final List<String> headers = weekdayHeaders(firstWeekday: firstWeekday);
    final int rowCount = cells.length ~/ 7;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CalendarWeekdayBar(labels: headers),
        const SizedBox(height: 6),
        for (int row = 0; row < rowCount; row++) ...<Widget>[
          if (row > 0) const SizedBox(height: 6),
          Row(
            children: <Widget>[
              for (int col = 0; col < 7; col++)
                Expanded(child: _cell(cells[row * 7 + col])),
            ],
          ),
        ],
      ],
    );
  }

  Widget _cell(CalendarCell cell) {
    if (cell.isPadding) {
      return const SizedBox.shrink();
    }
    final String dateKey = cell.dateKey!;
    return CalendarDayCell(
      key: ValueKey<String>('day-$dateKey'),
      cell: cell,
      day: daysByDate[dateKey],
      isToday: todayKey != null && dateKey == todayKey,
      onTap: () => onSelectDay(dateKey),
    );
  }
}
