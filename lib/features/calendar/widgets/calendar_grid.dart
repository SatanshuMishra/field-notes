import 'package:flutter/widgets.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';

import '../model/calendar_month.dart';
import 'calendar_day_cell.dart';
import 'calendar_weekday_bar.dart';

const double _weekRowGap = 4;
const double _weekRowRadius = 15;
const EdgeInsets _dayTapReach = EdgeInsets.symmetric(
  horizontal: calendarColumnGap / 2,
);

class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.month,
    required this.daysByDate,
    this.firstWeekday = DateTime.sunday,
    this.todayKey,
    this.journaledDates = const <String>{},
    required this.onSelectDay,
  });

  final MonthRef month;
  final Map<String, Day> daysByDate;
  final int firstWeekday;
  final String? todayKey;
  final Set<String> journaledDates;
  final void Function(String dateKey) onSelectDay;

  @override
  Widget build(BuildContext context) {
    final List<CalendarCell> cells = monthGridCells(
      month,
      firstWeekday: firstWeekday,
    );
    final List<String> headers = weekdayHeaders(firstWeekday: firstWeekday);
    final int rowCount = cells.length ~/ 7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CalendarWeekdayBar(
          labels: headers,
          names: weekdayNames(firstWeekday: firstWeekday),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int row = 0; row < rowCount; row++) ...<Widget>[
                if (row > 0) const SizedBox(height: _weekRowGap),
                Expanded(child: _weekRow(cells.sublist(row * 7, row * 7 + 7))),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _weekRow(List<CalendarCell> week) {
    return _CalendarWeekRow(
      isCurrentWeek: week.any((CalendarCell cell) => cell.dateKey == todayKey),
      children: <Widget>[for (final CalendarCell cell in week) _cell(cell)],
    );
  }

  Widget _cell(CalendarCell cell) {
    final String dateKey = cell.dateKey;
    final String? today = todayKey;
    final bool isFuture = today != null && dateKey.compareTo(today) > 0;
    return CalendarDayCell(
      key: ValueKey<String>('day-$dateKey'),
      cell: cell,
      day: cell.isInMonth ? daysByDate[dateKey] : null,
      isToday: dateKey == today,
      isFuture: isFuture,
      hasEntries: cell.isInMonth && journaledDates.contains(dateKey),
      onTap: isFuture ? null : () => onSelectDay(dateKey),
      tapReach: _dayTapReach,
    );
  }
}

class _CalendarWeekRow extends StatelessWidget {
  const _CalendarWeekRow({required this.isCurrentWeek, required this.children});

  final bool isCurrentWeek;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(vertical: calendarRowPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(width: calendarRowPadding),
          for (int index = 0; index < children.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: calendarColumnGap),
            Expanded(child: children[index]),
          ],
          const SizedBox(width: calendarRowPadding),
        ],
      ),
    );
    if (!isCurrentWeek) {
      return row;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.coral.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(_weekRowRadius),
      ),
      child: CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: Palette.coral.withValues(alpha: 0.45),
          radius: _weekRowRadius,
        ),
        child: row,
      ),
    );
  }
}
