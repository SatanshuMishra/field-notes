import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/format/clock_format.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/garden/widgets/meadow_glass_popover.dart';
import 'package:field_notes/features/today/today_date.dart';

import '../sky/sky_astronomy.dart';
import '../sky/sky_time.dart';

const String meadowPlayTheDayLabel = 'Play the day';
const String meadowPauseLabel = 'Pause';
const String meadowNowLabel = 'Now';
const double meadowDockPillHeight = 40;

const BorderRadius _pillRadius = BorderRadius.all(Radius.circular(20));
const double _glyphGap = 7;

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
    this.sunEvent,
    this.onNow,
    this.onFastForward,
  });

  final SkyMoment moment;
  final SkyEvent? sunEvent;
  final VoidCallback? onNow;
  final VoidCallback? onFastForward;

  @override
  Widget build(BuildContext context) {
    final String clock = gardenClockLabel(context, moment);
    final String? sun = gardenSunEventLabel(context, sunEvent);
    final VoidCallback? now = onNow;
    final VoidCallback? play = onFastForward;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                clock,
                maxLines: 1,
                softWrap: false,
                style: meadowSans(13).copyWith(height: 1.15),
              ),
              if (sun != null)
                Text(
                  sun,
                  maxLines: 1,
                  softWrap: false,
                  style: meadowSans(
                    10.5,
                    opacity: 0.72,
                    weight: FontWeight.w400,
                  ).copyWith(height: 1.15),
                ),
            ],
          ),
        ),
        if (now != null && moment.shifted)
          MeadowDockPill(label: meadowNowLabel, onPressed: now),
        if (play != null)
          MeadowDockPill(
            label: moment.fastForwarding
                ? meadowPauseLabel
                : meadowPlayTheDayLabel,
            glyph: moment.fastForwarding
                ? MeadowPlayGlyph.pause
                : MeadowPlayGlyph.play,
            onPressed: play,
          ),
      ],
    );
  }
}

enum MeadowPlayGlyph { play, pause }

class MeadowDockPill extends StatefulWidget {
  const MeadowDockPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.text,
    this.glyph,
    this.caret = false,
    this.filled = false,
    this.tooltip,
    this.semanticValue,
    this.fontSize = 12.5,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? text;
  final MeadowPlayGlyph? glyph;
  final bool caret;
  final bool filled;
  final String? tooltip;
  final String? semanticValue;
  final double fontSize;

  @override
  State<MeadowDockPill> createState() => _MeadowDockPillState();
}

class _MeadowDockPillState extends State<MeadowDockPill> {
  bool _hovered = false;

  void _hover(bool hovered) {
    if (hovered != _hovered) {
      setState(() => _hovered = hovered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool filled = widget.filled;
    final Color ink = filled ? Palette.onAccent : meadowCream;
    final MeadowPlayGlyph? glyph = widget.glyph;
    final Color fill = filled
        ? Palette.coral
        : meadowGlassWhite(_hovered ? 0.12 : 0);
    final Widget face = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: _pillRadius,
        border: filled
            ? Border.all(color: context.colors.line, width: Shapes.outlineWidth)
            : null,
      ),
      child: SizedBox(
        height: meadowDockPillHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (glyph != null) ...<Widget>[
                CustomPaint(
                  size: const Size.square(12),
                  painter: MeadowPlayGlyphPainter(glyph: glyph, color: ink),
                ),
                const SizedBox(width: _glyphGap),
              ],
              Text(
                widget.text ?? widget.label,
                maxLines: 1,
                softWrap: false,
                style: meadowSans(widget.fontSize).copyWith(color: ink),
              ),
              if (widget.caret) ...<Widget>[
                const SizedBox(width: _glyphGap),
                CustomPaint(
                  size: const Size.square(12),
                  painter: MeadowStrokePainter(
                    path: meadowCaretUp,
                    color: ink,
                    stroke: 2.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    final String? tip = widget.tooltip;
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label: widget.label,
      value: widget.semanticValue,
      onTap: widget.onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (PointerEnterEvent event) => _hover(true),
        onExit: (PointerExitEvent event) => _hover(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: widget.onPressed,
          child: FocusRing(
            onPressed: widget.onPressed,
            enabled: widget.onPressed != null,
            surface: FocusRingSurface.dark,
            borderRadius: _pillRadius,
            child: ExcludeSemantics(
              child: tip == null
                  ? face
                  : Tooltip(
                      message: tip,
                      excludeFromSemantics: true,
                      child: face,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

final Path meadowCaretUp = Path()
  ..moveTo(6, 15)
  ..lineTo(12, 9)
  ..lineTo(18, 15);

final Path meadowCaretDown = Path()
  ..moveTo(6, 9)
  ..lineTo(12, 15)
  ..lineTo(18, 9);

class MeadowStrokePainter extends CustomPainter {
  const MeadowStrokePainter({
    required this.path,
    required this.color,
    required this.stroke,
  });

  final Path path;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(MeadowStrokePainter oldDelegate) =>
      !identical(oldDelegate.path, path) ||
      oldDelegate.color != color ||
      oldDelegate.stroke != stroke;
}

class MeadowPlayGlyphPainter extends CustomPainter {
  const MeadowPlayGlyphPainter({required this.glyph, required this.color});

  final MeadowPlayGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 24;
    final Paint fill = Paint()..color = color;
    canvas.save();
    canvas.scale(scale);
    switch (glyph) {
      case MeadowPlayGlyph.play:
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
          fill,
        );
      case MeadowPlayGlyph.pause:
        canvas.drawRRect(
          RRect.fromLTRBR(6, 5, 10, 19, const Radius.circular(1)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromLTRBR(14, 5, 18, 19, const Radius.circular(1)),
          fill,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MeadowPlayGlyphPainter oldDelegate) =>
      glyph != oldDelegate.glyph || color != oldDelegate.color;
}
