import 'dart:math' as math;

import 'package:field_notes/design/feedback/empty_state.dart'
    show DashedBorderPainter;
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/services/reminder_service.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_schedule_labels.dart';
import 'package:flutter/material.dart';

const Key reminderCustomTimeKey = ValueKey<String>('reminder-custom-time');
const Key reminderLastCallKey = ValueKey<String>('reminder-last-call');
const Key reminderTimelineKey = ValueKey<String>('reminder-timeline');

Key reminderScheduleKey(ReminderSchedule schedule) =>
    ValueKey<String>('reminder-schedule-${schedule.id}');

const BorderRadius _cardRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusMd),
);
const BorderRadius _cardHeadRadius = BorderRadius.vertical(
  top: Radius.circular(Shapes.radiusMd),
);
const double _cardMinHeight = 92;
const double _cardInset = 14;
const double _cardTextInset = 42;
const double _cardGap = 12;
const double _stackedCardGap = 10;
const double _sideBySideFrom = 520;
const double _detailGap = 5;
const double _tagGap = 6;
const double _timeGap = 9;
const double _selectedTint = 0.08;
const double _radioSize = 18;
const double _radioDrop = 2;
const double _radioDotInset = 3;
const double _lastCallGap = 12;
const double _timelineGap = 18;
const EdgeInsets _lastCallPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 14,
);
const double _moonDisc = 30;
const double _moonGlyph = 16;
const double _moonStroke = 1.8;
const double _moonViewBox = 24;
const double _moonTint = 0.14;
const double _moonGap = 14;

class ReminderSchedulePicker extends StatelessWidget {
  const ReminderSchedulePicker({
    super.key,
    required this.schedule,
    required this.customTime,
    required this.onSchedule,
    required this.onCustomTime,
  });

  final ReminderSchedule schedule;
  final ReminderTime customTime;
  final ValueChanged<ReminderSchedule> onSchedule;
  final VoidCallback onCustomTime;

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = <Widget>[
      for (final ReminderSchedule option in ReminderSchedule.values)
        _ScheduleCard(
          schedule: option,
          selected: option == schedule,
          onPressed: () {
            if (option != schedule) {
              onSchedule(option);
            }
          },
          below: option == ReminderSchedule.custom && option == schedule
              ? SettingsTimeField(
                  key: reminderCustomTimeKey,
                  semanticLabel: reminderScheduleTitle(ReminderSchedule.custom),
                  value: TimeOfDay(
                    hour: customTime.hour,
                    minute: customTime.minute,
                  ),
                  onTap: onCustomTime,
                )
              : null,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: reminderScheduleGroupLabel,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth < _sideBySideFrom) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final (int index, Widget card)
                        in cards.indexed) ...<Widget>[
                      if (index > 0) const SizedBox(height: _stackedCardGap),
                      card,
                    ],
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final (int index, Widget card)
                        in cards.indexed) ...<Widget>[
                      if (index > 0) const SizedBox(width: _cardGap),
                      Expanded(child: card),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: _lastCallGap),
        const _LastCallNote(),
        const SizedBox(height: _timelineGap),
        ReminderTimeline(
          key: reminderTimelineKey,
          slots: const ReminderService().slotsFor(schedule, customTime),
        ),
      ],
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.selected,
    required this.onPressed,
    this.below,
  });

  final ReminderSchedule schedule;
  final bool selected;
  final VoidCallback onPressed;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final FieldNotesTextStyles styles = context.textStyles;
    final String title = reminderScheduleTitle(schedule);
    final String detail = reminderScheduleDetail(context, schedule);
    final bool isDefault = schedule == AppSettings.defaults.reminderSchedule;
    final Widget? below = this.below;
    final Widget head = Pressable(
      key: reminderScheduleKey(schedule),
      label: isDefault ? '$title, $reminderDefaultTag' : title,
      value: detail,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      onPressed: onPressed,
      borderRadius: below == null ? _cardRadius : _cardHeadRadius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => HoverFill(
        hovered: hovered,
        borderRadius: below == null ? _cardRadius : _cardHeadRadius,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: below == null ? _cardMinHeight : 0,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              _cardTextInset,
              _cardInset,
              _cardInset,
              below == null ? _cardInset : 0,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Wrap(
                      spacing: _tagGap,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          title,
                          style: styles.labelSans.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isDefault)
                          Text(
                            reminderDefaultTag,
                            style: styles.subtitleAccent.copyWith(
                              color: colors.sage,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: _detailGap),
                    Text(detail, style: styles.captionSans),
                  ],
                ),
                Positioned(
                  left: _cardInset - _cardTextInset,
                  top: _radioDrop,
                  child: _Radio(selected: selected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected
            ? Color.alphaBlend(
                colors.accentInk.withValues(alpha: _selectedTint),
                colors.cardBright,
              )
            : null,
        borderRadius: _cardRadius,
        boxShadow: selected ? context.shadows.emphasis : null,
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? colors.accentInk : colors.ink30,
            width: Shapes.outlineWidth,
          ),
          borderRadius: _cardRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            head,
            if (below != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _cardTextInset,
                  _timeGap,
                  _cardInset,
                  _cardInset,
                ),
                child: Align(alignment: Alignment.centerLeft, child: below),
              ),
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return SizedBox.square(
      dimension: _radioSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? colors.accentInk : colors.ink35,
            width: Shapes.outlineWidth,
          ),
        ),
        child: selected
            ? Padding(
                padding: const EdgeInsets.all(_radioDotInset),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accentInk,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _LastCallNote extends StatelessWidget {
  const _LastCallNote();

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final FieldNotesTextStyles styles = context.textStyles;
    return MergeSemantics(
      key: reminderLastCallKey,
      child: CustomPaint(
        foregroundPainter: DashedBorderPainter(color: colors.dashMuted),
        child: Padding(
          padding: _lastCallPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ExcludeSemantics(
                child: SizedBox.square(
                  dimension: _moonDisc,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.lateNight.withValues(alpha: _moonTint),
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size.square(_moonGlyph),
                        painter: _MoonPainter(color: colors.lateNight),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _moonGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      reminderLastCallTitle(context),
                      style: styles.labelSans.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: _detailGap),
                    Text(reminderLastCallExplainer, style: styles.captionSans),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  const _MoonPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _moonStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..save()
      ..scale(size.shortestSide / _moonViewBox)
      ..drawPath(
        Path()
          ..moveTo(19, 14.5)
          ..arcToPoint(const Offset(9.5, 5), radius: const Radius.circular(7.5))
          ..arcToPoint(
            const Offset(19, 14.5),
            radius: const Radius.circular(7.5),
            largeArc: true,
            clockwise: false,
          )
          ..close(),
        stroke,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_MoonPainter oldDelegate) => oldDelegate.color != color;
}

const int _timelineStartHour = 6;
const int _timelineEndHour = 4;
const int _timelineMinutes = 22 * 60;
const double _timelineFont = 11;
const double _timelineLineHeight = 1.3;
const double _markerRadius = 8;
const double _markerRing = 2;
const double _lineThickness = 2;
const double _nightBandHeight = 14;
const double _midnightTickHeight = 22;
const double _labelGap = 6;
const double _rowGap = 4;
const double _nightFill = 0.14;
const double _nightEdge = 0.5;

double _timelineFraction(ReminderTime time) {
  if (time.hour >= _timelineEndHour && time.hour < _timelineStartHour) {
    return 0;
  }
  final int hour = time.hour < _timelineEndHour ? time.hour + 24 : time.hour;
  return ((hour - _timelineStartHour) * 60 + time.minute) / _timelineMinutes;
}

class ReminderTimeline extends StatelessWidget {
  const ReminderTimeline({super.key, required this.slots});

  final List<ReminderSlot> slots;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final bool twentyFour = MediaQuery.alwaysUse24HourFormatOf(context);
    final TextStyle base = context.textStyles.captionSans.copyWith(
      fontSize: _timelineFont,
      height: _timelineLineHeight,
    );
    final double textHeight = scaler.scale(_timelineFont) * _timelineLineHeight;
    final double height = textHeight * 2 + _rowGap * 2 + _midnightTickHeight;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _TimelinePainter(
            marks: <_TimelineMark>[
              for (final ReminderSlot slot in slots)
                _TimelineMark(
                  at: _timelineFraction(slot.time),
                  label: slot.nudge == ReminderNudge.lastCall
                      ? 'last call ${reminderClockLabel(context, slot.time)}'
                      : reminderClockLabel(context, slot.time),
                  lastCall: slot.nudge == ReminderNudge.lastCall,
                ),
            ],
            ticks: <(double, String)>[
              (0, twentyFour ? '06:00' : '6 AM'),
              (
                _timelineFraction(const ReminderTime(hour: 12, minute: 0)),
                twentyFour ? '12:00' : 'noon',
              ),
              (
                _timelineFraction(const ReminderTime(hour: 18, minute: 0)),
                twentyFour ? '18:00' : '6 PM',
              ),
              (
                _timelineFraction(const ReminderTime(hour: 0, minute: 0)),
                twentyFour ? '00:00' : 'midnight',
              ),
              (1, twentyFour ? '04:00' : '4 AM'),
            ],
            markStyle: base.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.inkSoft,
            ),
            tickStyle: base.copyWith(color: colors.muted),
            scaler: scaler,
            textDirection: Directionality.of(context),
            line: colors.ink14,
            midnight: colors.ink35,
            nudge: colors.accentInk,
            lastCall: colors.lateNight,
            ring: colors.cardLight,
          ),
        ),
      ),
    );
  }
}

class _TimelineMark {
  const _TimelineMark({
    required this.at,
    required this.label,
    required this.lastCall,
  });

  final double at;
  final String label;
  final bool lastCall;
}

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({
    required this.marks,
    required this.ticks,
    required this.markStyle,
    required this.tickStyle,
    required this.scaler,
    required this.textDirection,
    required this.line,
    required this.midnight,
    required this.nudge,
    required this.lastCall,
    required this.ring,
  });

  final List<_TimelineMark> marks;
  final List<(double, String)> ticks;
  final TextStyle markStyle;
  final TextStyle tickStyle;
  final TextScaler scaler;
  final TextDirection textDirection;
  final Color line;
  final Color midnight;
  final Color nudge;
  final Color lastCall;
  final Color ring;

  TextPainter _text(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: textDirection,
    textScaler: scaler,
    maxLines: 1,
  )..layout();

  List<double> _spread(List<double> centres, List<double> widths, double span) {
    final List<double> lefts = <double>[];
    for (int index = 0; index < centres.length; index++) {
      final double wanted = (centres[index] - widths[index] / 2).clamp(
        0,
        math.max(0, span - widths[index]),
      );
      lefts.add(
        index == 0
            ? wanted
            : math.max(
                wanted,
                lefts[index - 1] + widths[index - 1] + _labelGap,
              ),
      );
    }
    for (int index = lefts.length - 1; index >= 0; index--) {
      final double limit = index == lefts.length - 1
          ? span - widths[index]
          : lefts[index + 1] - _labelGap - widths[index];
      lefts[index] = math.max(0, math.min(lefts[index], limit));
    }
    return List<double>.unmodifiable(lefts);
  }

  double _markerX(_TimelineMark mark, double span) {
    const double inset = _markerRadius + _markerRing;
    return (span * mark.at).clamp(inset, math.max(inset, span - inset));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double span = size.width;
    final List<TextPainter> markLabels = <TextPainter>[
      for (final _TimelineMark mark in marks) _text(mark.label, markStyle),
    ];
    final double labelHeight = markLabels.isEmpty
        ? scaler.scale(_timelineFont) * _timelineLineHeight
        : markLabels.first.height;
    final double axis = labelHeight + _rowGap + _midnightTickHeight / 2;
    final double midnightX =
        span * _timelineFraction(const ReminderTime(hour: 0, minute: 0));
    final RRect band = RRect.fromLTRBR(
      midnightX,
      axis - _nightBandHeight / 2,
      span,
      axis + _nightBandHeight / 2,
      const Radius.circular(_nightBandHeight / 2),
    );
    canvas
      ..drawRect(
        Rect.fromLTWH(0, axis - _lineThickness / 2, span, _lineThickness),
        Paint()..color = line,
      )
      ..drawRRect(band, Paint()..color = lastCall.withValues(alpha: _nightFill))
      ..save()
      ..translate(band.left, band.top);
    DashedBorderPainter(
      color: lastCall.withValues(alpha: _nightEdge),
      strokeWidth: 1,
      radius: _nightBandHeight / 2,
    ).paint(canvas, Size(band.width, band.height));
    canvas
      ..restore()
      ..drawRect(
        Rect.fromLTWH(
          midnightX - _lineThickness / 2,
          axis - _midnightTickHeight / 2,
          _lineThickness,
          _midnightTickHeight,
        ),
        Paint()..color = midnight,
      );
    for (final _TimelineMark mark in marks) {
      final Offset centre = Offset(_markerX(mark, span), axis);
      canvas
        ..drawCircle(centre, _markerRadius + _markerRing, Paint()..color = ring)
        ..drawCircle(
          centre,
          _markerRadius,
          Paint()..color = mark.lastCall ? lastCall : nudge,
        );
    }
    final List<double> markLefts = _spread(
      <double>[for (final _TimelineMark mark in marks) _markerX(mark, span)],
      <double>[for (final TextPainter label in markLabels) label.width],
      span,
    );
    for (int index = 0; index < markLabels.length; index++) {
      markLabels[index].paint(canvas, Offset(markLefts[index], 0));
    }
    final List<TextPainter> tickLabels = <TextPainter>[
      for (final (double _, String label) in ticks) _text(label, tickStyle),
    ];
    final List<double> tickLefts = _spread(
      <double>[for (final (double at, String _) in ticks) span * at],
      <double>[for (final TextPainter label in tickLabels) label.width],
      span,
    );
    final double tickTop = axis + _midnightTickHeight / 2 + _rowGap;
    for (int index = 0; index < tickLabels.length; index++) {
      tickLabels[index].paint(canvas, Offset(tickLefts[index], tickTop));
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter oldDelegate) => true;
}
