import 'package:flutter/widgets.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';

import '../model/calendar_month.dart';
import 'calendar_chevron_button.dart';

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
    this.hasEntries = false,
    this.onTap,
    this.tapReach = EdgeInsets.zero,
  });

  final CalendarCell cell;
  final Day? day;
  final bool isToday;
  final bool isFuture;
  final bool hasEntries;
  final VoidCallback? onTap;
  final EdgeInsets tapReach;

  String get semanticLabel {
    final Mood? mood = cell.isInMonth ? day?.mood : null;
    return <String>[
      'Day ${cell.dayOfMonth}',
      if (isToday) 'today',
      if (mood != null) mood.label,
      if (hasEntries) 'has entries',
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final double? dimming = !cell.isInMonth
        ? _neighbourOpacity
        : (isFuture ? _futureOpacity : null);
    return CalendarTapArea(
      reach: onTap == null ? EdgeInsets.zero : tapReach,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final _CellMetrics metrics =
              constraints.maxWidth < _compactWidthBelow ||
                  constraints.maxHeight < _compactHeightBelow
              ? _CellMetrics.compact
              : _CellMetrics.regular;
          final BorderRadius radius = BorderRadius.circular(metrics.radius);
          Widget faceWith(Color? hover) {
            final Widget face = cell.isInMonth
                ? _InMonthFace(
                    dayOfMonth: cell.dayOfMonth,
                    day: day,
                    isToday: isToday,
                    metrics: metrics,
                    hover: hover,
                  )
                : _NumberOnly(
                    dayOfMonth: cell.dayOfMonth,
                    metrics: metrics,
                    hover: hover,
                  );
            return dimming == null
                ? face
                : Opacity(opacity: dimming, child: face);
          }

          final VoidCallback? onTap = this.onTap;
          if (onTap == null) {
            return Semantics(
              label: semanticLabel,
              excludeSemantics: true,
              child: faceWith(null),
            );
          }
          return Pressable(
            label: semanticLabel,
            onPressed: onTap,
            borderRadius: radius,
            paintsHover: false,
            builder: (BuildContext context, bool hovered) => faceWith(
              hovered
                  ? HoverStyle.of(
                      context,
                      FocusRingSurface.light,
                      HoverShape.rounded,
                    )
                  : null,
            ),
          );
        },
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
    required this.hover,
  });

  final int dayOfMonth;
  final Day? day;
  final bool isToday;
  final _CellMetrics metrics;
  final Color? hover;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final Mood? mood = day?.mood;
    final BorderRadius radius = BorderRadius.circular(metrics.radius);
    final Widget content = _HoverFill(
      color: hover,
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (mood != null)
            Center(child: FlowerBloom.forMood(mood, size: metrics.flowerSize))
          else if (day != null)
            const _ActivityDot(key: calendarActivityDotKey),
          _DayNumber(
            dayOfMonth: dayOfMonth,
            color: isToday ? colors.accentInk : colors.mutedDeep,
            metrics: metrics,
          ),
        ],
      ),
    );
    if (isToday) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cardLight,
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
          color: colors.cardWarm,
          border: Border.all(color: colors.ink25, width: Shapes.outlineWidth),
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.shadowTint(0x1F),
              offset: const Offset(1.5, 1.5),
            ),
          ],
        ),
        child: content,
      );
    }
    return CustomPaint(
      foregroundPainter: DashedBorderPainter(
        color: colors.ink16,
        radius: metrics.radius,
      ),
      child: content,
    );
  }
}

class _NumberOnly extends StatelessWidget {
  const _NumberOnly({
    required this.dayOfMonth,
    required this.metrics,
    required this.hover,
  });

  final int dayOfMonth;
  final _CellMetrics metrics;
  final Color? hover;

  @override
  Widget build(BuildContext context) {
    return _HoverFill(
      color: hover,
      borderRadius: BorderRadius.circular(metrics.radius),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _DayNumber(
            dayOfMonth: dayOfMonth,
            color: context.colors.mutedDeep,
            metrics: metrics,
          ),
        ],
      ),
    );
  }
}

class _HoverFill extends StatelessWidget {
  const _HoverFill({
    required this.color,
    required this.borderRadius,
    required this.child,
  });

  final Color? color;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: HoverStyle.decoration(
        color: color,
        shape: HoverShape.rounded,
        borderRadius: borderRadius,
      ),
      child: child,
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
        style: context.textStyles.captureLabelSans.copyWith(
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
    return Center(
      child: SizedBox(
        width: 8,
        height: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.sage,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
