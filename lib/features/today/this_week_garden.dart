import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'today_date.dart';
import 'today_week.dart';

const String thisWeekGardenTitle = "this week's garden";

const double _titleGap = 2;
const double _rangeGap = 11;
const double _gridGap = 8;
const int _gridColumns = 4;
const double _labelGap = 1;
const double _cellPaddingTop = 6;
const double _cellPaddingBottom = 4;

const EdgeInsets _cellContentPadding = EdgeInsets.fromLTRB(
  Shapes.outlineWidth,
  _cellPaddingTop + Shapes.outlineWidth,
  Shapes.outlineWidth,
  _cellPaddingBottom + Shapes.outlineWidth,
);

const BorderRadius _cellBorderRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusCell),
);

const List<String> _shortMonthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const String _rangeSeparator = ' – ';

enum _WeekCellState { today, filled, empty }

String _shortMonthDay(DateTime moment) =>
    '${_shortMonthNames[moment.month - 1]} ${moment.day}';

String? _weekRangeLabel(List<TodayWeekCell> cells) {
  if (cells.isEmpty) {
    return null;
  }
  final DateTime? start = parseDateKey(cells.first.date);
  final DateTime? end = parseDateKey(cells.last.date);
  if (start == null || end == null) {
    return null;
  }
  return '${_shortMonthDay(start)}$_rangeSeparator${_shortMonthDay(end)}';
}

_WeekCellState _stateOf(TodayWeekCell cell) {
  if (cell.isToday) {
    return _WeekCellState.today;
  }
  return cell.mood == null ? _WeekCellState.empty : _WeekCellState.filled;
}

Color _labelColorOf(_WeekCellState state, FieldNotesColors colors) {
  switch (state) {
    case _WeekCellState.today:
      return colors.accentInk;
    case _WeekCellState.filled:
      return colors.muted;
    case _WeekCellState.empty:
      return colors.dashMuted;
  }
}

class ThisWeekGarden extends StatelessWidget {
  const ThisWeekGarden({
    super.key,
    required this.cells,
    this.title = thisWeekGardenTitle,
    this.bloomSize = 27,
  });

  final List<TodayWeekCell> cells;
  final String title;
  final double bloomSize;

  @override
  Widget build(BuildContext context) {
    final String? range = _weekRangeLabel(cells);
    final FieldNotesTextStyles textStyles = context.textStyles;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: textStyles.sectionHeaderAccent),
        const SizedBox(height: _titleGap),
        if (range != null) ...<Widget>[
          Text(range, style: textStyles.caption10Sans),
          const SizedBox(height: _rangeGap),
        ],
        ..._gridRows(),
      ],
    );
  }

  List<Widget> _gridRows() {
    final List<Widget> rows = <Widget>[];
    for (int start = 0; start < cells.length; start += _gridColumns) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: _gridGap));
      }
      rows.add(_gridRow(start));
    }
    return rows;
  }

  Widget _gridRow(int start) {
    final List<Widget> slots = <Widget>[];
    for (int column = 0; column < _gridColumns; column++) {
      if (column > 0) {
        slots.add(const SizedBox(width: _gridGap));
      }
      final int index = start + column;
      slots.add(
        Expanded(
          child: index < cells.length
              ? _WeekCell(cell: cells[index], bloomSize: bloomSize)
              : const SizedBox.shrink(),
        ),
      );
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: slots);
  }
}

class _WeekCell extends ConsumerWidget {
  const _WeekCell({required this.cell, required this.bloomSize});

  final TodayWeekCell cell;
  final double bloomSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Mood? mood = cell.mood;
    void openCalendar() {
      ref
          .read(shellNavigationProvider.notifier)
          .select(ShellDestination.calendar);
    }

    return Semantics(
      button: true,
      onTap: openCalendar,
      label: mood == null
          ? '${cell.weekdayLabel}, no mood'
          : '${cell.weekdayLabel}, ${mood.label}',
      child: FocusRing(
        onPressed: openCalendar,
        borderRadius: _cellBorderRadius,
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: openCalendar,
            child: _tile(context, mood),
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, Mood? mood) {
    final FieldNotesColors colors = context.colors;
    final FieldNotesShadows shadows = context.shadows;
    final _WeekCellState state = _stateOf(cell);
    final Widget content = Padding(
      padding: _cellContentPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox.square(
            dimension: bloomSize,
            child: mood == null
                ? CustomPaint(
                    painter: DashedBorderPainter(
                      color: colors.dashMuted,
                      radius: bloomSize / 2,
                    ),
                  )
                : FlowerBloom.forMood(mood, size: bloomSize),
          ),
          const SizedBox(height: _labelGap),
          Text(
            cell.weekdayLabel,
            textAlign: TextAlign.center,
            style: context.textStyles.caption8Sans.copyWith(
              color: _labelColorOf(state, colors),
            ),
          ),
        ],
      ),
    );

    switch (state) {
      case _WeekCellState.today:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.cardLight,
            border: const Border.fromBorderSide(
              BorderSide(color: Palette.coral, width: Shapes.outlineWidth),
            ),
            borderRadius: _cellBorderRadius,
            boxShadow: Shadows.cellToday,
          ),
          child: content,
        );
      case _WeekCellState.filled:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.cardWarm,
            border: shadows.outline,
            borderRadius: _cellBorderRadius,
            boxShadow: shadows.cellFilled,
          ),
          child: content,
        );
      case _WeekCellState.empty:
        return CustomPaint(
          painter: DashedBorderPainter(
            color: colors.ink35,
            radius: Shapes.radiusCell,
          ),
          child: content,
        );
    }
  }
}
