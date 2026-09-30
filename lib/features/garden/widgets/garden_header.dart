import 'package:flutter/material.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/format/clock_format.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/features/today/today_date.dart';

import '../sky/sky_astronomy.dart';
import '../sky/sky_time.dart';

const double _minTapTarget = 48;

String _eventTime(BuildContext context, SkyEvent event) =>
    formatClock(context, TimeOfDay.fromDateTime(event.instant.toLocal()));

String? gardenSunEventLabel(BuildContext context, SkyEvent? event) =>
    event == null
    ? null
    : '${event.isRise ? 'sunrise' : 'sunset'} ${_eventTime(context, event)}';

String? gardenMoonEventLabel(BuildContext context, SkyEvent? event) =>
    event == null
    ? null
    : '${event.isRise ? 'moonrise' : 'moonset'} ${_eventTime(context, event)}';

String gardenClockLabel(BuildContext context, SkyMoment moment) {
  final String time = formatClock(
    context,
    TimeOfDay.fromDateTime(moment.instant.toLocal()),
  );
  if (!moment.shifted) {
    return time;
  }
  final String weekday = shortWeekdayLabel(moment.instant);
  final String date = shortMonthDayLabel(moment.instant);
  return '$weekday $date · $time';
}

class GardenSkyClock extends StatelessWidget {
  const GardenSkyClock({
    super.key,
    required this.moment,
    required this.compact,
    this.sunEvent,
    this.moonEvent,
    this.debugControls = false,
    this.onNow,
    this.onFastForward,
  });

  final SkyMoment moment;
  final bool compact;
  final SkyEvent? sunEvent;
  final SkyEvent? moonEvent;
  final bool debugControls;
  final VoidCallback? onNow;
  final VoidCallback? onFastForward;

  @override
  Widget build(BuildContext context) {
    final FieldNotesTextStyles styles = context.textStyles;
    final String clock = gardenClockLabel(context, moment);
    final String? sun = gardenSunEventLabel(context, sunEvent);
    final String? moon = gardenMoonEventLabel(context, moonEvent);
    final List<Widget> controls = <Widget>[
      if (debugControls && moment.shifted)
        _SkyControlButton(label: 'Now', compact: compact, onPressed: onNow),
      if (debugControls)
        _SkyControlButton(
          label: moment.fastForwarding ? 'Pause' : 'Fast-forward',
          compact: compact,
          running: moment.fastForwarding,
          glyph: moment.fastForwarding
              ? _SkyControlGlyph.pause
              : _SkyControlGlyph.fastForward,
          onPressed: onFastForward,
        ),
    ];
    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    clock,
                    style: styles.labelSans.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  if (sun != null)
                    Text(
                      sun,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: styles.caption9Sans.copyWith(height: 1.25),
                    ),
                ],
              ),
            ),
            for (final Widget control in controls) ...<Widget>[
              const SizedBox(width: 6),
              control,
            ],
          ],
        ),
      );
    }
    final String events = <String>[?sun, ?moon].join(' · ');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              clock,
              textAlign: TextAlign.right,
              style: styles.labelSans.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            if (events.isNotEmpty)
              Text(
                events,
                textAlign: TextAlign.right,
                style: styles.captionSans.copyWith(fontSize: 11, height: 1.25),
              ),
          ],
        ),
        for (final Widget control in controls) ...<Widget>[
          const SizedBox(width: 10),
          control,
        ],
      ],
    );
  }
}

enum _SkyControlGlyph { fastForward, pause }

class _SkyControlButton extends StatelessWidget {
  const _SkyControlButton({
    required this.label,
    required this.compact,
    required this.onPressed,
    this.running = false,
    this.glyph,
  });

  final String label;
  final bool compact;
  final VoidCallback? onPressed;
  final bool running;
  final _SkyControlGlyph? glyph;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final Color foreground = running ? Palette.onAccent : colors.ink;
    final BorderRadius radius = BorderRadius.all(
      Radius.circular(compact ? 9 : 11),
    );
    final double glyphSize = compact ? 10 : 12;
    final _SkyControlGlyph? shape = glyph;
    final Widget face = DecoratedBox(
      decoration: BoxDecoration(
        color: running ? Palette.coral : colors.cardBright,
        border: context.shadows.outline,
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: running ? colors.shadow : colors.shadowTint(0x33),
            offset: const Offset(1.5, 1.5),
          ),
        ],
      ),
      child: Padding(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 9, vertical: 6)
            : EdgeInsets.symmetric(
                horizontal: shape == null ? 12 : 13,
                vertical: 8,
              ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (shape != null) ...<Widget>[
              switch (shape) {
                _SkyControlGlyph.pause => IconStickerGlyphIcon(
                  glyph: IconStickerGlyph.pause,
                  color: foreground,
                  size: glyphSize,
                ),
                _SkyControlGlyph.fastForward => CustomPaint(
                  size: Size.square(glyphSize),
                  painter: _FastForwardGlyphPainter(foreground),
                ),
              },
              SizedBox(width: compact ? 5 : 7),
            ],
            ExcludeSemantics(
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: context.textStyles.captureLabelSans.copyWith(
                  color: foreground,
                  fontSize: compact ? 10 : 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _minTapTarget,
            minHeight: _minTapTarget,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: FocusRing(
              enabled: onPressed != null,
              onPressed: onPressed,
              borderRadius: radius,
              child: face,
            ),
          ),
        ),
      ),
    );
  }
}

class _FastForwardGlyphPainter extends CustomPainter {
  const _FastForwardGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      Path()
        ..moveTo(3, 5.5)
        ..lineTo(12, 12)
        ..lineTo(3, 18.5)
        ..close()
        ..moveTo(12, 5.5)
        ..lineTo(21, 12)
        ..lineTo(12, 18.5)
        ..close(),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FastForwardGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}
