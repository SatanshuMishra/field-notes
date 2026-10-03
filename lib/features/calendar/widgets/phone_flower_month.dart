import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';

import '../model/calendar_month.dart';
import 'calendar_chevron_button.dart';

const String phoneMonthEyebrow = 'explore';
const String phoneMonthNotGrownLabel = 'Not grown yet';
const String phoneMonthEmptyLabel = 'Nothing planted this month';
const String phoneMonthPreviousLabel = 'Previous month';
const String phoneMonthPickerLabel = 'Jump to a month';
const String phoneMonthNextLabel = 'Next month';
const String phoneThisMonthLabel = 'This month';

const double phoneMonthControlsLift = 94;
const double phoneMonthControlHeight = 48;
const double phoneMonthControlGap = 8;
const double phoneMonthControlRadius = Shapes.radiusMd;
const double phoneThisMonthLift = 150;
const double phoneThisMonthHeight = 36;
const double phoneThisMonthHitHeight = 48;
const double phoneMonthSwipeDistance = 50;
const double phoneMonthSwipeRatio = 1.3;
const double phoneMonthFlowerSize = 40;
const double phoneMonthWeekGap = 2;
const double phoneMonthFutureOpacity = 0.45;
const Color phoneMonthWeekTint = Color(0x14C76A54);

const Key phoneMonthGridKey = ValueKey<String>('phone-month-grid');
const Key phoneMonthWeekdaysKey = ValueKey<String>('phone-month-weekdays');
const Key phoneMonthPreviousKey = ValueKey<String>('phone-month-previous');
const Key phoneMonthPickerButtonKey = ValueKey<String>('phone-month-picker');
const Key phoneMonthNextKey = ValueKey<String>('phone-month-next');
const Key phoneThisMonthKey = ValueKey<String>('phone-this-month');
const Key phoneMonthDotKey = ValueKey<String>('phone-month-dot');
const Key phoneMonthRingKey = ValueKey<String>('phone-month-ring');
const Key phoneMonthTodayPillKey = ValueKey<String>('phone-month-today-pill');

Key phoneMonthWeekKey(int index) => ValueKey<String>('phone-month-week-$index');

const EdgeInsets _monthPadding = EdgeInsets.fromLTRB(14, 4, 14, 6);
const double _sideInset = 12;
const double _pillClearance = 6;
const double _monthLift =
    phoneThisMonthLift + phoneThisMonthHeight + _pillClearance;
const double _titleInset = 4;
const double _subtitleGap = 3;
const double _weekdayGap = 14;
const double _rowsGap = 4;
const double _markGap = 2;
const double _weekRadius = 16;
const double _cellRadius = 14;
const double _dotSize = 8;
const double _dotMargin = 16;
const double _ringSize = 22;
const double _ringMargin = 9;
const double _ringStroke = 1.5;
const double _ringDash = 4.5;
const double _ringGap = 3;
const double _todayPillRadius = 9;
const EdgeInsets _todayPillPadding = EdgeInsets.symmetric(
  horizontal: 7,
  vertical: 3,
);
const EdgeInsets _numberPadding = EdgeInsets.symmetric(vertical: 3);
const double _chevronSize = 16;
const double _caretSize = 13;
const double _caretGap = 6;
const double _thisMonthRadius = 18;
const EdgeInsets _thisMonthPadding = EdgeInsets.fromLTRB(11, 0, 14, 0);
const double _thisMonthChevron = 12;
const double _thisMonthGap = 6;

const TextStyle _titleStyle = TextStyle(
  fontFamily: TypographyTokens.serif,
  fontSize: 30,
  fontWeight: FontWeight.w500,
  height: 1.05,
);

const TextStyle _eyebrowStyle = TextStyle(
  fontFamily: TypographyTokens.accent,
  fontSize: 15,
  fontWeight: FontWeight.w600,
);

const TextStyle _subtitleStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12,
  fontWeight: FontWeight.w400,
);

const TextStyle _weekdayStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 10,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.6,
);

const TextStyle _numberStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  height: 1,
);

const TextStyle _monthButtonStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 14,
  fontWeight: FontWeight.w600,
);

const TextStyle _thisMonthStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12,
  fontWeight: FontWeight.w600,
);

int _monthOrder(MonthRef month) => month.year * 12 + month.month;

String phoneMonthSubtitle({required int blooms, required bool isFutureMonth}) {
  if (blooms == 1) {
    return '1 bloom this month';
  }
  if (blooms > 1) {
    return '$blooms blooms this month';
  }
  return isFutureMonth ? phoneMonthNotGrownLabel : phoneMonthEmptyLabel;
}

class PhoneFlowerMonth extends StatelessWidget {
  const PhoneFlowerMonth({
    super.key,
    required this.month,
    required this.currentMonth,
    required this.daysByDate,
    required this.journaledDates,
    required this.firstWeekday,
    required this.todayKey,
    required this.onSelectDay,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onShowCurrentMonth,
    required this.onOpenPicker,
    this.placeholder,
  });

  final MonthRef month;
  final MonthRef currentMonth;
  final Map<String, Day>? daysByDate;
  final Set<String> journaledDates;
  final int firstWeekday;
  final String todayKey;
  final ValueChanged<String> onSelectDay;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onShowCurrentMonth;
  final VoidCallback onOpenPicker;
  final Widget? placeholder;

  bool get _isFutureMonth => _monthOrder(month) > _monthOrder(currentMonth);

  @override
  Widget build(BuildContext context) {
    final double headerInset = MediaQuery.paddingOf(context).top;
    final double gestureBar = MediaQuery.viewPaddingOf(context).bottom;
    final Widget? placeholder = this.placeholder;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Padding(
          padding: _monthPadding.copyWith(
            top: headerInset + _monthPadding.top,
            bottom: gestureBar + _monthLift + _monthPadding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _heading(context),
              const SizedBox(height: _weekdayGap),
              _weekdays(context),
              const SizedBox(height: _rowsGap),
              Expanded(
                child: _MonthSwipe(
                  key: phoneMonthGridKey,
                  onNext: onNextMonth,
                  onPrevious: onPreviousMonth,
                  child: placeholder ?? _weeks(),
                ),
              ),
            ],
          ),
        ),
        if (month != currentMonth)
          Positioned(
            left: 0,
            right: 0,
            bottom:
                gestureBar +
                phoneThisMonthLift -
                (phoneThisMonthHitHeight - phoneThisMonthHeight) / 2,
            height: phoneThisMonthHitHeight,
            child: Center(
              child: _ThisMonthPill(
                pointsBack: _isFutureMonth,
                onPressed: onShowCurrentMonth,
              ),
            ),
          ),
        Positioned(
          left: _sideInset,
          right: _sideInset,
          bottom: gestureBar + phoneMonthControlsLift,
          height: phoneMonthControlHeight,
          child: _controls(context),
        ),
      ],
    );
  }

  Widget _heading(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final Map<String, Day>? daysByDate = this.daysByDate;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _titleInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            phoneMonthEyebrow,
            style: _eyebrowStyle.copyWith(color: colors.accentInk),
          ),
          Text(
            month.title,
            style: _titleStyle.copyWith(color: colors.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: _subtitleGap),
          Text(
            daysByDate == null
                ? ''
                : phoneMonthSubtitle(
                    blooms: daysByDate.values
                        .where((Day day) => day.mood != null)
                        .length,
                    isFutureMonth: _isFutureMonth,
                  ),
            style: _subtitleStyle.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }

  Widget _weekdays(BuildContext context) {
    final List<String> letters = weekdayHeaders(firstWeekday: firstWeekday);
    final List<String> names = weekdayNames(firstWeekday: firstWeekday);
    final TextStyle style = _weekdayStyle.copyWith(color: context.colors.muted);
    return Row(
      key: phoneMonthWeekdaysKey,
      children: <Widget>[
        for (int index = 0; index < letters.length; index++)
          Expanded(
            child: Text(
              letters[index].toUpperCase(),
              semanticsLabel: names[index],
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
      ],
    );
  }

  Widget _weeks() {
    final List<CalendarCell> cells = monthGridCells(
      month,
      firstWeekday: firstWeekday,
    );
    final int rowCount = cells.length ~/ 7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int row = 0; row < rowCount; row++) ...<Widget>[
          if (row > 0) const SizedBox(height: phoneMonthWeekGap),
          Expanded(child: _week(row, cells.sublist(row * 7, row * 7 + 7))),
        ],
      ],
    );
  }

  Widget _week(int index, List<CalendarCell> week) {
    return _PhoneWeekRow(
      key: phoneMonthWeekKey(index),
      isCurrentWeek: week.any((CalendarCell cell) => cell.dateKey == todayKey),
      children: <Widget>[
        for (final CalendarCell cell in week)
          cell.isInMonth ? _cell(cell) : const SizedBox.shrink(),
      ],
    );
  }

  Widget _cell(CalendarCell cell) {
    final String dateKey = cell.dateKey;
    final bool isFuture = dateKey.compareTo(todayKey) > 0;
    final Map<String, Day>? daysByDate = this.daysByDate;
    return _PhoneDayCell(
      key: ValueKey<String>('day-$dateKey'),
      dayOfMonth: cell.dayOfMonth,
      isLoaded: daysByDate != null,
      mood: daysByDate?[dateKey]?.mood,
      hasEntries: journaledDates.contains(dateKey),
      isToday: dateKey == todayKey,
      isFuture: isFuture,
      onTap: isFuture ? null : () => onSelectDay(dateKey),
    );
  }

  Widget _controls(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Row(
      children: <Widget>[
        PhoneCalendarButton(
          key: phoneMonthPreviousKey,
          label: phoneMonthPreviousLabel,
          fill: colors.cardLight,
          width: phoneMonthControlHeight,
          onPressed: onPreviousMonth,
          child: const CalendarChevronGlyph(
            direction: ChevronDirection.previous,
            size: _chevronSize,
          ),
        ),
        const SizedBox(width: phoneMonthControlGap),
        Expanded(
          child: PhoneCalendarButton(
            key: phoneMonthPickerButtonKey,
            label: phoneMonthPickerLabel,
            value: month.title,
            fill: colors.cardWarm,
            onPressed: onOpenPicker,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    month.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _monthButtonStyle.copyWith(color: colors.ink),
                  ),
                ),
                const SizedBox(width: _caretGap),
                const RotatedBox(
                  quarterTurns: 2,
                  child: CalendarChevronGlyph(
                    direction: ChevronDirection.down,
                    size: _caretSize,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: phoneMonthControlGap),
        PhoneCalendarButton(
          key: phoneMonthNextKey,
          label: phoneMonthNextLabel,
          fill: colors.cardLight,
          width: phoneMonthControlHeight,
          onPressed: onNextMonth,
          child: const CalendarChevronGlyph(
            direction: ChevronDirection.next,
            size: _chevronSize,
          ),
        ),
      ],
    );
  }
}

class PhoneCalendarButton extends StatelessWidget {
  const PhoneCalendarButton({
    super.key,
    required this.label,
    required this.fill,
    required this.onPressed,
    required this.child,
    this.value,
    this.width,
    this.height = phoneMonthControlHeight,
  });

  final String label;
  final String? value;
  final Color fill;
  final VoidCallback onPressed;
  final Widget child;
  final double? width;
  final double height;

  static const BorderRadius _radius = BorderRadius.all(
    Radius.circular(phoneMonthControlRadius),
  );

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        value: value,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: FocusRing(
              onPressed: onPressed,
              borderRadius: _radius,
              child: ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: fill,
                    border: context.shadows.outline,
                    borderRadius: _radius,
                    boxShadow: context.shadows.chip,
                  ),
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: Center(child: child),
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

class _MonthSwipe extends StatefulWidget {
  const _MonthSwipe({
    super.key,
    required this.onNext,
    required this.onPrevious,
    required this.child,
  });

  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Widget child;

  @override
  State<_MonthSwipe> createState() => _MonthSwipeState();
}

class _MonthSwipeState extends State<_MonthSwipe> {
  Offset? _start;

  void _begin(DragStartDetails details) => _start = details.globalPosition;

  void _cancel() => _start = null;

  void _finish(DragEndDetails details) {
    final Offset? start = _start;
    _start = null;
    if (start == null) {
      return;
    }
    final Offset travel = details.globalPosition - start;
    final double across = travel.dx.abs();
    if (across <= phoneMonthSwipeDistance ||
        across <= travel.dy.abs() * phoneMonthSwipeRatio) {
      return;
    }
    if (travel.dx < 0) {
      widget.onNext();
    } else {
      widget.onPrevious();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onHorizontalDragStart: _begin,
      onHorizontalDragEnd: _finish,
      onHorizontalDragCancel: _cancel,
      child: widget.child,
    );
  }
}

class _PhoneWeekRow extends StatelessWidget {
  const _PhoneWeekRow({
    super.key,
    required this.isCurrentWeek,
    required this.children,
  });

  final bool isCurrentWeek;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final Widget child in children) Expanded(child: child),
      ],
    );
    if (!isCurrentWeek) {
      return row;
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: phoneMonthWeekTint,
        borderRadius: BorderRadius.all(Radius.circular(_weekRadius)),
      ),
      child: row,
    );
  }
}

class _PhoneDayCell extends StatelessWidget {
  const _PhoneDayCell({
    super.key,
    required this.dayOfMonth,
    required this.isLoaded,
    required this.mood,
    required this.hasEntries,
    required this.isToday,
    required this.isFuture,
    required this.onTap,
  });

  final int dayOfMonth;
  final bool isLoaded;
  final Mood? mood;
  final bool hasEntries;
  final bool isToday;
  final bool isFuture;
  final VoidCallback? onTap;

  String get _semanticLabel => <String>[
    'Day $dayOfMonth',
    if (isToday) 'today',
    ?mood?.label,
    if (hasEntries) 'has entries',
  ].join(', ');

  @override
  Widget build(BuildContext context) {
    final Widget face = FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _mark(context),
          const SizedBox(height: _markGap),
          _number(context),
        ],
      ),
    );
    final VoidCallback? onTap = this.onTap;
    return FocusRing(
      enabled: onTap != null,
      onPressed: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(_cellRadius)),
      child: Semantics(
        container: true,
        button: onTap != null,
        label: _semanticLabel,
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: isFuture
                ? Opacity(opacity: phoneMonthFutureOpacity, child: face)
                : face,
          ),
        ),
      ),
    );
  }

  Widget _mark(BuildContext context) {
    final Mood? mood = this.mood;
    if (mood != null) {
      return FlowerBloom.forMood(mood, size: phoneMonthFlowerSize);
    }
    if (!isLoaded) {
      return const SizedBox(height: phoneMonthFlowerSize);
    }
    if (hasEntries) {
      return Padding(
        key: phoneMonthDotKey,
        padding: const EdgeInsets.symmetric(vertical: _dotMargin),
        child: SizedBox.square(
          dimension: _dotSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.sage,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }
    if (isFuture) {
      return const SizedBox(height: phoneMonthFlowerSize);
    }
    return Padding(
      key: phoneMonthRingKey,
      padding: const EdgeInsets.symmetric(vertical: _ringMargin),
      child: SizedBox.square(
        dimension: _ringSize,
        child: CustomPaint(
          painter: DashedBorderPainter(
            color: context.colors.ink30,
            strokeWidth: _ringStroke,
            radius: _ringSize / 2,
            dashLength: _ringDash,
            dashGap: _ringGap,
          ),
        ),
      ),
    );
  }

  Widget _number(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    if (isToday) {
      return DecoratedBox(
        key: phoneMonthTodayPillKey,
        decoration: const BoxDecoration(
          color: Palette.coral,
          borderRadius: BorderRadius.all(Radius.circular(_todayPillRadius)),
        ),
        child: Padding(
          padding: _todayPillPadding,
          child: Text(
            '$dayOfMonth',
            style: _numberStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: Palette.onAccent,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: _numberPadding,
      child: Text(
        '$dayOfMonth',
        style: _numberStyle.copyWith(
          color: mood == null ? colors.muted : colors.ink,
        ),
      ),
    );
  }
}

class _ThisMonthPill extends StatelessWidget {
  const _ThisMonthPill({required this.pointsBack, required this.onPressed});

  final bool pointsBack;
  final VoidCallback onPressed;

  static const BorderRadius _radius = BorderRadius.all(
    Radius.circular(_thisMonthRadius),
  );

  @override
  Widget build(BuildContext context) {
    final Color ink = context.colors.accentInk;
    return Semantics(
      button: true,
      label: phoneThisMonthLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: phoneThisMonthKey,
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: (phoneThisMonthHitHeight - phoneThisMonthHeight) / 2,
            ),
            child: FocusRing(
              onPressed: onPressed,
              borderRadius: _radius,
              child: ExcludeSemantics(
                child: SizedBox(
                  height: phoneThisMonthHeight,
                  child: GlassSurface(
                    tone: GlassTone.paper,
                    borderRadius: _radius,
                    padding: _thisMonthPadding,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        CalendarChevronGlyph(
                          direction: pointsBack
                              ? ChevronDirection.previous
                              : ChevronDirection.next,
                          size: _thisMonthChevron,
                          color: ink,
                        ),
                        const SizedBox(width: _thisMonthGap),
                        Text(
                          phoneThisMonthLabel,
                          style: _thisMonthStyle.copyWith(color: ink),
                        ),
                      ],
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
