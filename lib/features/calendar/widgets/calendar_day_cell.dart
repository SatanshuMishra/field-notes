import 'package:flutter/widgets.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';

import '../model/calendar_month.dart';

const Key calendarActivityDotKey = Key('calendar-activity-dot');

const double _neighbourOpacity = 0.35;
const double _futureOpacity = 0.55;
const double _compactWidthBelow = 64;
const double _compactHeightBelow = 60;

class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.cell,
    this.day,
    this.isToday = false,
    this.isFuture = false,
    this.onTap,
  });

  final CalendarCell cell;
  final Day? day;
  final bool isToday;
  final bool isFuture;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget face = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final _CellMetrics metrics =
            constraints.maxWidth < _compactWidthBelow ||
                    constraints.maxHeight < _compactHeightBelow
                ? _CellMetrics.compact
                : _CellMetrics.regular;
        return cell.isInMonth
            ? _InMonthFace(
                dayOfMonth: cell.dayOfMonth,
                day: day,
                isToday: isToday,
                metrics: metrics,
              )
            : _NumberOnly(dayOfMonth: cell.dayOfMonth, metrics: metrics);
      },
    );
    final double? dimming = !cell.isInMonth
        ? _neighbourOpacity
        : (isFuture ? _futureOpacity : null);
    return Semantics(
      button: onTap != null,
      label: 'Day ${cell.dayOfMonth}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: dimming == null ? face : Opacity(opacity: dimming, child: face),
      ),
    );
  }
}

class _CellMetrics {
  const _CellMetrics({
    required this.radius,
    required this.numberTop,
    required this.numberLeft,
    required this.numberSize,
    required this.flowerSize,
  });

  static const _CellMetrics regular = _CellMetrics(
    radius: Shapes.radiusControl,
    numberTop: 7,
    numberLeft: 9,
    numberSize: 12,
    flowerSize: 40,
  );

  static const _CellMetrics compact = _CellMetrics(
    radius: Shapes.radiusThumb,
    numberTop: 3,
    numberLeft: 4,
    numberSize: 9,
    flowerSize: 22,
  );

  final double radius;
  final double numberTop;
  final double numberLeft;
  final double numberSize;
  final double flowerSize;
}

class _InMonthFace extends StatelessWidget {
  const _InMonthFace({
    required this.dayOfMonth,
    required this.day,
    required this.isToday,
    required this.metrics,
  });

  final int dayOfMonth;
  final Day? day;
  final bool isToday;
  final _CellMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final Mood? mood = day?.mood;
    final BorderRadius radius = BorderRadius.circular(metrics.radius);
    final Widget content = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (mood != null)
          Center(child: FlowerBloom.forMood(mood, size: metrics.flowerSize))
        else if (day != null)
          const _ActivityDot(key: calendarActivityDotKey),
        _DayNumber(
          dayOfMonth: dayOfMonth,
          color: isToday ? Palette.coral : Palette.mutedDeep,
          metrics: metrics,
        ),
      ],
    );
    if (isToday) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Palette.cardLight,
          border: Border.all(color: Palette.coral, width: Shapes.outlineWidth),
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Palette.coral.withValues(alpha: 0.28),
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: content,
      );
    }
    if (day != null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Palette.cardWarm,
          border: Border.all(color: Palette.ink25, width: Shapes.outlineWidth),
          borderRadius: radius,
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Palette.ink12, offset: Offset(1.5, 1.5)),
          ],
        ),
        child: content,
      );
    }
    return CustomPaint(
      foregroundPainter: DashedBorderPainter(
        color: Palette.ink16,
        radius: metrics.radius,
      ),
      child: content,
    );
  }
}

class _NumberOnly extends StatelessWidget {
  const _NumberOnly({required this.dayOfMonth, required this.metrics});

  final int dayOfMonth;
  final _CellMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _DayNumber(
          dayOfMonth: dayOfMonth,
          color: Palette.mutedDeep,
          metrics: metrics,
        ),
      ],
    );
  }
}

class _DayNumber extends StatelessWidget {
  const _DayNumber({
    required this.dayOfMonth,
    required this.color,
    required this.metrics,
  });

  final int dayOfMonth;
  final Color color;
  final _CellMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: metrics.numberTop,
      left: metrics.numberLeft,
      child: Text(
        '$dayOfMonth',
        style: TypographyTokens.captureLabelSans.copyWith(
          fontSize: metrics.numberSize,
          height: 1,
          color: color,
        ),
      ),
    );
  }
}

class _ActivityDot extends StatelessWidget {
  const _ActivityDot({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 8,
        height: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Palette.sage,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
