import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:field_notes/design/interaction/min_target.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/pressable.dart';
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
const BorderRadius _monthBorderRadius = BorderRadius.all(
  Radius.circular(_monthRadius),
);
const BorderRadius _actionRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusXs),
);
const Duration _popDuration = Duration(milliseconds: 140);
double _minTargetOn(TargetPlatform platform) =>
    platform == TargetPlatform.macOS || platform == TargetPlatform.windows
    ? minTargetOn(platform)
    : 0;

const TextStyle _yearStyle = TextStyle(
  fontFamily: TypographyTokens.serif,
  fontSize: 18,
  fontWeight: FontWeight.w500,
  height: 1,
);

const TextStyle _monthStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  height: 1,
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
    final FieldNotesColors colors = context.colors;
    final double arrowSize = math.max(
      _yearArrowSize,
      _minTargetOn(Theme.of(context).platform),
    );
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
            decoration: BoxDecoration(
              color: colors.cardWarm,
              border: Border.fromBorderSide(
                BorderSide(color: colors.line, width: 2),
              ),
              borderRadius: const BorderRadius.all(
                Radius.circular(Shapes.radiusLg),
              ),
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
                        size: arrowSize,
                        glyphSize: 13,
                        alignment: Alignment.centerLeft,
                      ),
                      Expanded(
                        child: Text(
                          '$year',
                          textAlign: TextAlign.center,
                          style: _yearStyle.copyWith(color: colors.ink),
                        ),
                      ),
                      CalendarChevronButton(
                        direction: ChevronDirection.next,
                        semanticLabel: 'Next year',
                        onPressed: onNextYear,
                        size: arrowSize,
                        glyphSize: 13,
                        alignment: Alignment.centerRight,
                      ),
                    ],
                  ),
                  for (int row = 0; row < _monthRows; row++)
                    Row(
                      children: <Widget>[
                        for (
                          int column = 0;
                          column < _monthColumns;
                          column++
                        ) ...<Widget>[
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
                  DashedDivider(color: colors.dashMuted),
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
      semanticLabel: '${monthName(month.month)} ${month.year}',
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
    required this.semanticLabel,
    required this.isDisplayed,
    required this.isCurrent,
    required this.margin,
    required this.onPressed,
  });

  final String label;
  final String semanticLabel;
  final bool isDisplayed;
  final bool isCurrent;
  final EdgeInsets margin;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CalendarTapSlot(
      margin: margin,
      child: Pressable(
        label: semanticLabel,
        selected: isDisplayed,
        onPressed: onPressed,
        borderRadius: _monthBorderRadius,
        paintsHover: false,
        builder: (BuildContext context, bool hovered) =>
            _face(context, hovered),
      ),
    );
  }

  Widget _face(BuildContext context, bool hovered) {
    final FieldNotesColors colors = context.colors;
    final Widget text = HoverFill(
      hovered: hovered,
      surface: isDisplayed ? FocusRingSurface.dark : FocusRingSurface.light,
      borderRadius: _monthBorderRadius,
      position: DecorationPosition.background,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: _minTargetOn(Theme.of(context).platform),
        ),
        child: Center(
          heightFactor: 1,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: _monthStyle.copyWith(
                color: isDisplayed
                    ? Palette.onAccent
                    : (isCurrent ? colors.accentInk : colors.ink),
              ),
            ),
          ),
        ),
      ),
    );
    if (isDisplayed) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Palette.coral,
          border: context.shadows.outline,
          borderRadius: _monthBorderRadius,
          boxShadow: context.shadows.control,
        ),
        child: text,
      );
    }
    if (isCurrent) {
      return CustomPaint(
        foregroundPainter: const DashedBorderPainter(
          color: Palette.coral,
          radius: _monthRadius,
        ),
        child: text,
      );
    }
    return text;
  }
}

class _PickerAction extends StatelessWidget {
  const _PickerAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CalendarTapSlot(
      margin: const EdgeInsets.only(top: _actionGap, bottom: _pickerPadding),
      child: Pressable(
        label: label,
        onPressed: onPressed,
        borderRadius: _actionRadius,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: _minTargetOn(Theme.of(context).platform),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(label, style: context.textStyles.caption11Sans),
            ),
          ),
        ),
      ),
    );
  }
}
