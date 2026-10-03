import 'package:flutter/material.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';

import '../model/calendar_month.dart';
import 'calendar_chevron_button.dart';
import 'phone_flower_month.dart';

const String monthYearPreviousLabel = 'Previous year';
const String monthYearNextLabel = 'Next year';
const String monthYearBackLabel = 'Back to this month';

const Key monthYearPreviousKey = ValueKey<String>('month-year-previous');
const Key monthYearNextKey = ValueKey<String>('month-year-next');
const Key monthYearTitleKey = ValueKey<String>('month-year-title');
const Key monthYearBackKey = ValueKey<String>('month-year-back');

Key monthYearMonthKey(int month) => ValueKey<String>('month-year-$month');

const double monthYearCellHeight = 48;
const double monthYearCellRadius = Shapes.radiusControl;

const EdgeInsets _yearRowPadding = EdgeInsets.fromLTRB(12, 8, 12, 4);
const EdgeInsets _gridPadding = EdgeInsets.fromLTRB(12, 10, 12, 4);
const double _gridGap = 8;
const int _columns = 3;
const int _rows = 12 ~/ _columns;
const double _yearChevronSize = 15;

const TextStyle _yearStyle = TextStyle(
  fontFamily: TypographyTokens.serif,
  fontSize: 22,
  fontWeight: FontWeight.w500,
);

const TextStyle _monthStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 14,
  fontWeight: FontWeight.w600,
);

const TextStyle _backStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 13,
  fontWeight: FontWeight.w600,
);

const BorderRadius _cellRadius = BorderRadius.all(
  Radius.circular(monthYearCellRadius),
);

const BorderRadius _backRadius = BorderRadius.all(
  Radius.circular(phoneMonthControlRadius),
);

class MonthYearSheet extends StatefulWidget {
  const MonthYearSheet({
    super.key,
    required this.displayedMonth,
    required this.currentMonth,
    required this.onPick,
  });

  final MonthRef displayedMonth;
  final MonthRef currentMonth;
  final ValueChanged<MonthRef> onPick;

  @override
  State<MonthYearSheet> createState() => _MonthYearSheetState();
}

class _MonthYearSheetState extends State<MonthYearSheet> {
  late int _year = widget.displayedMonth.year;

  void _stepYear(int delta) => setState(() => _year += delta);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[_yearRow(context), _grid()],
    );
  }

  Widget _yearRow(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Padding(
      padding: _yearRowPadding,
      child: Row(
        children: <Widget>[
          PhoneCalendarButton(
            key: monthYearPreviousKey,
            label: monthYearPreviousLabel,
            fill: colors.cardLight,
            width: phoneMonthControlHeight,
            onPressed: () => _stepYear(-1),
            child: const CalendarChevronGlyph(
              direction: ChevronDirection.previous,
              size: _yearChevronSize,
            ),
          ),
          Expanded(
            child: Text(
              '$_year',
              key: monthYearTitleKey,
              textAlign: TextAlign.center,
              style: _yearStyle.copyWith(color: colors.ink),
            ),
          ),
          PhoneCalendarButton(
            key: monthYearNextKey,
            label: monthYearNextLabel,
            fill: colors.cardLight,
            width: phoneMonthControlHeight,
            onPressed: () => _stepYear(1),
            child: const CalendarChevronGlyph(
              direction: ChevronDirection.next,
              size: _yearChevronSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid() {
    return Padding(
      padding: _gridPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int row = 0; row < _rows; row++) ...<Widget>[
            if (row > 0) const SizedBox(height: _gridGap),
            Row(
              children: <Widget>[
                for (int column = 0; column < _columns; column++) ...<Widget>[
                  if (column > 0) const SizedBox(width: _gridGap),
                  Expanded(
                    child: _cell(MonthRef(_year, row * _columns + column + 1)),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(MonthRef month) {
    return _MonthCell(
      key: monthYearMonthKey(month.month),
      month: month,
      isDisplayed: month == widget.displayedMonth,
      isCurrent: month == widget.currentMonth,
      onPressed: () => widget.onPick(month),
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    super.key,
    required this.month,
    required this.isDisplayed,
    required this.isCurrent,
    required this.onPressed,
  });

  final MonthRef month;
  final bool isDisplayed;
  final bool isCurrent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final Widget label = SizedBox(
      height: monthYearCellHeight,
      child: Center(
        child: Text(
          monthAbbreviation(month.month),
          style: _monthStyle.copyWith(
            color: isDisplayed
                ? Palette.onAccent
                : (isCurrent ? colors.accentInk : colors.ink),
          ),
        ),
      ),
    );
    final Widget face = isDisplayed
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: Palette.coral,
              border: context.shadows.outline,
              borderRadius: _cellRadius,
              boxShadow: context.shadows.control,
            ),
            child: label,
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: colors.cardLight,
              border: isCurrent
                  ? null
                  : Border.all(color: colors.ink18, width: Shapes.outlineWidth),
              borderRadius: _cellRadius,
            ),
            child: isCurrent
                ? CustomPaint(
                    foregroundPainter: const DashedBorderPainter(
                      color: Palette.coral,
                      radius: monthYearCellRadius,
                    ),
                    child: label,
                  )
                : label,
          );
    return Semantics(
      button: true,
      selected: isDisplayed,
      label: '${monthName(month.month)} ${month.year}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: FocusRing(
            onPressed: onPressed,
            borderRadius: _cellRadius,
            child: ExcludeSemantics(child: face),
          ),
        ),
      ),
    );
  }
}

class MonthYearBackButton extends StatelessWidget {
  const MonthYearBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: monthYearBackLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: monthYearBackKey,
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: FocusRing(
            onPressed: onPressed,
            borderRadius: _backRadius,
            child: ExcludeSemantics(
              child: CustomPaint(
                foregroundPainter: const DashedBorderPainter(
                  color: Palette.coral,
                  radius: phoneMonthControlRadius,
                ),
                child: SizedBox(
                  height: phoneMonthControlHeight,
                  child: Center(
                    child: Text(
                      monthYearBackLabel,
                      style: _backStyle.copyWith(
                        color: context.colors.accentInk,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
