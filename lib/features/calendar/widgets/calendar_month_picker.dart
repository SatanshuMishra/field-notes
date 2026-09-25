import 'package:flutter/widgets.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/dashed_divider.dart';

import '../model/calendar_month.dart';
import 'calendar_chevron_button.dart';

const double calendarMonthPickerWidth = 264;
const double calendarMonthPickerCompactWidth = 236;

const double _pickerPadding = 12;
const double _yearArrowSize = 28;
const double _yearOverhang = (calendarMinTapTarget - _yearArrowSize) / 2;
const double _monthGap = 6;
const double _dividerGap = 12;
const double _actionGap = 10;
const int _monthColumns = 3;
const int _monthRows = 12 ~/ _monthColumns;
const double _monthRadius = 9;
const Duration _popDuration = Duration(milliseconds: 140);

const TextStyle _yearStyle = TextStyle(
  fontFamily: TypographyTokens.serif,
  fontSize: 18,
  fontWeight: FontWeight.w500,
  height: 1,
  color: Palette.ink,
);

const TextStyle _monthStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  height: 1,
  color: Palette.ink,
);

class CalendarMonthPicker extends StatelessWidget {
  const CalendarMonthPicker({
    super.key,
    required this.year,
    required this.displayedMonth,
    required this.currentMonth,
    required this.onPreviousYear,
    required this.onNextYear,
    required this.onPickMonth,
    required this.onBackToThisWeek,
    this.width = calendarMonthPickerWidth,
  });

  final int year;
  final MonthRef displayedMonth;
  final MonthRef currentMonth;
  final VoidCallback onPreviousYear;
  final VoidCallback onNextYear;
  final ValueChanged<MonthRef> onPickMonth;
  final VoidCallback onBackToThisWeek;
  final double width;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: _popDuration,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double progress, Widget? child) {
        return Opacity(
          opacity: progress,
          child: Transform.scale(
            scale: 0.96 + 0.04 * progress,
            alignment: Alignment.topLeft,
            child: child,
          ),
        );
      },
      child: DialogHost(
        child: SizedBox(
          width: width,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Palette.cardWarm,
              border: Border.fromBorderSide(
                BorderSide(color: Palette.ink, width: 2),
              ),
              borderRadius: BorderRadius.all(Radius.circular(Shapes.radiusLg)),
              boxShadow: Shadows.softLift,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                _pickerPadding,
                _pickerPadding - _yearOverhang,
                _pickerPadding,
                0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      CalendarChevronButton(
                        direction: ChevronDirection.previous,
                        semanticLabel: 'Previous year',
                        onPressed: onPreviousYear,
                        size: _yearArrowSize,
                        glyphSize: 13,
                        alignment: Alignment.centerLeft,
                      ),
                      Expanded(
                        child: Text(
                          '$year',
                          textAlign: TextAlign.center,
                          style: _yearStyle,
                        ),
                      ),
                      CalendarChevronButton(
                        direction: ChevronDirection.next,
                        semanticLabel: 'Next year',
                        onPressed: onNextYear,
                        size: _yearArrowSize,
                        glyphSize: 13,
                        alignment: Alignment.centerRight,
                      ),
                    ],
                  ),
                  for (int row = 0; row < _monthRows; row++)
                    Row(
                      children: <Widget>[
                        for (int column = 0;
                            column < _monthColumns;
                            column++) ...<Widget>[
                          if (column > 0) const SizedBox(width: _monthGap),
                          Expanded(
                            child: _monthTile(
                              MonthRef(year, row * _monthColumns + column + 1),
                              margin: EdgeInsets.only(
                                top: row == 0 ? 0 : _monthGap / 2,
                                bottom: row == _monthRows - 1
                                    ? _dividerGap
                                    : _monthGap / 2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  const DashedDivider(color: Palette.dashMuted),
                  Center(
                    child: _PickerAction(
                      label: 'Back to this week',
                      onPressed: onBackToThisWeek,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _monthTile(MonthRef month, {required EdgeInsets margin}) {
    return _MonthTile(
      label: monthAbbreviation(month.month),
      isDisplayed: month == displayedMonth,
      isCurrent: month == currentMonth,
      margin: margin,
      onPressed: () => onPickMonth(month),
    );
  }
}

class _MonthTile extends StatelessWidget {
  const _MonthTile({
    required this.label,
    required this.isDisplayed,
    required this.isCurrent,
    required this.margin,
    required this.onPressed,
  });

  final String label;
  final bool isDisplayed;
  final bool isCurrent;
  final EdgeInsets margin;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Widget text = Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: _monthStyle.copyWith(
          color: isDisplayed
              ? Palette.onAccent
              : (isCurrent ? Palette.coral : Palette.ink),
        ),
      ),
    );
    final Widget face;
    if (isDisplayed) {
      face = DecoratedBox(
        decoration: const BoxDecoration(
          color: Palette.coral,
          border: Shapes.outline,
          borderRadius: BorderRadius.all(Radius.circular(_monthRadius)),
          boxShadow: Shadows.control,
        ),
        child: text,
      );
    } else if (isCurrent) {
      face = CustomPaint(
        foregroundPainter: const DashedBorderPainter(
          color: Palette.coral,
          radius: _monthRadius,
        ),
        child: text,
      );
    } else {
      face = text;
    }
    return Semantics(
      button: true,
      selected: isDisplayed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: CalendarTapSlot(margin: margin, child: face),
        ),
      ),
    );
  }
}

class _PickerAction extends StatelessWidget {
  const _PickerAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: CalendarTapSlot(
            margin: const EdgeInsets.only(
              top: _actionGap,
              bottom: _pickerPadding,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(label, style: TypographyTokens.caption11Sans),
            ),
          ),
        ),
      ),
    );
  }
}
