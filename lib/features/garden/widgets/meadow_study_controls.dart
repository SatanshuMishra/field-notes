import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/format/clock_format.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/garden/model/meadow_year_replay.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/garden_header.dart';
import 'package:field_notes/features/today/today_date.dart';

const int meadowDayMinutes = 24 * 60;
const int meadowHourStepMinutes = 3;
const int meadowLatestHourMinutes = meadowDayMinutes - meadowHourStepMinutes;
const Duration meadowDayPlayerTick = Duration(milliseconds: 50);
const Duration meadowReplayDuration = Duration(seconds: 13);
const String meadowReplayLabel = 'Replay the year';
const String meadowPlantingLabel = 'Planting…';
const ValueKey<String> meadowHourSliderKey = ValueKey<String>(
  'meadow-hour-slider',
);
const ValueKey<String> meadowGrowthSliderKey = ValueKey<String>(
  'meadow-growth-slider',
);

const double _minTapTarget = 48;
const double _boxBasis = 360;
const double _boxGap = 10;
const double _sidebarGap = 10;
const double _compactGap = 8;
const double _compactButtonGap = 6;
const double _compactLabelWidth = 74;
const double _sidebarSliderMinWidth = 50;
const double _sidebarClockMinWidth = 60;
const double _sidebarGrowthMinWidth = 48;
const double _compactValueMinWidth = 50;
const double _trackHeight = 6;
const double _trackRadius = _trackHeight / 2;
const double _handleRadius = 7;
const EdgeInsets _sidebarBoxPadding = EdgeInsets.fromLTRB(13, 0, 10, 0);
const EdgeInsets _compactBoxPadding = EdgeInsets.symmetric(horizontal: 10);
const BorderRadius _sliderFocusRadius = BorderRadius.all(Radius.circular(9));

String _growthLabel(int year, int daysInYear, int growthPoint) {
  if (growthPoint >= daysInYear) {
    return 'Dec 31';
  }
  return shortMonthDayLabel(DateTime(year, 1, math.max(1, growthPoint)));
}

int _minutesOf(DateTime instant) {
  final DateTime local = instant.toLocal();
  return local.hour * 60 + local.minute;
}

class MeadowDayPlayer {
  MeadowDayPlayer({required TickerProvider vsync, required this.onHour}) {
    _ticker = vsync.createTicker(_tick);
  }

  final ValueChanged<int?> onHour;
  late final Ticker _ticker;
  int _from = 0;
  int _steps = 0;

  bool get playing => _ticker.isActive;

  void play(int fromMinutes) {
    _ticker.stop();
    _from = fromMinutes % meadowDayMinutes;
    _steps = 0;
    _ticker.start();
    onHour(_from);
  }

  void pause() => _ticker.stop();

  void toggle(int fromMinutes) {
    if (playing) {
      pause();
    } else {
      play(fromMinutes);
    }
  }

  void now() {
    pause();
    onHour(null);
  }

  void _tick(Duration elapsed) {
    final int steps =
        elapsed.inMicroseconds ~/ meadowDayPlayerTick.inMicroseconds;
    if (steps == _steps) {
      return;
    }
    _steps = steps;
    onHour((_from + steps * meadowHourStepMinutes) % meadowDayMinutes);
  }

  void dispose() => _ticker.dispose();
}

class MeadowStudyControls extends StatefulWidget {
  const MeadowStudyControls({
    super.key,
    required this.compact,
    required this.hourMinutes,
    required this.onHour,
    required this.limit,
    required this.daysInYear,
    required this.year,
    required this.growthPoint,
    required this.onGrowth,
    required this.moment,
    this.debugControls = false,
    this.onNow,
    this.onFastForward,
  });

  final bool compact;
  final int? hourMinutes;
  final ValueChanged<int?> onHour;
  final int limit;
  final int daysInYear;
  final int year;
  final int growthPoint;
  final void Function(int growthPoint, bool growAnimated) onGrowth;
  final bool debugControls;
  final SkyMoment moment;
  final VoidCallback? onNow;
  final VoidCallback? onFastForward;

  @override
  State<MeadowStudyControls> createState() => _MeadowStudyControlsState();
}

class _MeadowStudyControlsState extends State<MeadowStudyControls>
    with TickerProviderStateMixin {
  late final MeadowDayPlayer _player;
  late final MeadowYearReplay _replay;
  bool _planting = false;

  @override
  void initState() {
    super.initState();
    _player = MeadowDayPlayer(vsync: this, onHour: _reportHour);
    _replay = MeadowYearReplay(
      vsync: this,
      duration: meadowReplayDuration,
      onGrowth: _reportReplay,
    );
  }

  @override
  void didUpdateWidget(MeadowStudyControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool otherYear = oldWidget.year != widget.year;
    if (otherYear) {
      _stopReplay();
    }
    if (otherYear || !widget.debugControls) {
      _player.pause();
    }
  }

  @override
  void dispose() {
    _replay.dispose();
    _player.dispose();
    super.dispose();
  }

  void _reportHour(int? minutes) => widget.onHour(minutes);

  int get _shownMinutes =>
      widget.hourMinutes ?? _minutesOf(widget.moment.instant);

  void _onHourSlider(int minutes) {
    if (_player.playing) {
      setState(_player.pause);
    }
    widget.onHour(minutes);
  }

  void _togglePlay() {
    setState(() => _player.toggle(_shownMinutes));
    widget.onFastForward?.call();
  }

  void _backToNow() {
    setState(_player.now);
    widget.onNow?.call();
  }

  void _onGrowthSlider(int point) {
    if (_planting) {
      setState(_stopReplay);
    }
    widget.onGrowth(point, true);
  }

  void _stopReplay() {
    _replay.stop();
    _planting = false;
  }

  void _startReplay() => _replay.start(
    limit: widget.limit,
    reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
  );

  void _reportReplay(int point, bool animated) {
    final bool planting = _replay.playing;
    if (planting != _planting) {
      setState(() => _planting = planting);
    }
    widget.onGrowth(point, animated);
  }

  String _describeMinutes(int minutes) => formatClock(
    context,
    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
  );

  @override
  Widget build(BuildContext context) {
    final bool compact = widget.compact;
    final FieldNotesTextStyles styles = context.textStyles;
    final FieldNotesColors colors = context.colors;
    final TextStyle labelStyle = styles.captureLabelSans.copyWith(
      color: colors.mutedDeep,
      fontSize: compact ? 10 : 12,
    );
    final TextStyle valueStyle = styles.labelSans.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: compact ? 11 : 13,
    );
    final int limit = math.max(1, widget.limit);
    final String clock = gardenClockLabel(context, widget.moment);
    final String grown = _growthLabel(
      widget.year,
      widget.daysInYear,
      widget.growthPoint,
    );
    final Widget hourSlider = _MeadowSlider(
      key: meadowHourSliderKey,
      label: 'Time of day',
      value: _shownMinutes,
      min: 0,
      max: meadowLatestHourMinutes,
      step: meadowHourStepMinutes,
      describe: _describeMinutes,
      onChanged: _onHourSlider,
    );
    final Widget growthSlider = _MeadowSlider(
      key: meadowGrowthSliderKey,
      label: 'Grown through',
      value: widget.growthPoint,
      min: 1,
      max: limit,
      step: 1,
      describe: (int point) =>
          _growthLabel(widget.year, widget.daysInYear, point),
      onChanged: _onGrowthSlider,
    );
    final bool playing = _player.playing;
    final _StudyButton? play = widget.debugControls
        ? _StudyButton(
            label: playing ? 'Pause' : 'Play the day',
            compact: compact,
            filled: playing,
            glyph: playing ? _PlayGlyph.pause : _PlayGlyph.fastForward,
            onPressed: _togglePlay,
          )
        : null;
    final _StudyButton? now = widget.debugControls && widget.hourMinutes != null
        ? _StudyButton(label: 'Now', compact: compact, onPressed: _backToNow)
        : null;
    final _StudyButton replay = _StudyButton(
      label: _planting ? meadowPlantingLabel : meadowReplayLabel,
      compact: compact,
      filled: true,
      onPressed: _startReplay,
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: _ControlBox(
          compact: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _CompactSliderRow(
                label: 'Time of day',
                labelStyle: labelStyle,
                slider: hourSlider,
                value: clock,
                valueStyle: valueStyle,
              ),
              _CompactSliderRow(
                label: 'Grown through',
                labelStyle: labelStyle,
                slider: growthSlider,
                value: grown,
                valueStyle: valueStyle,
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: _compactButtonGap,
                children: <Widget>[?now, ?play, replay],
              ),
            ],
          ),
        ),
      );
    }
    final List<_StudyButton> debugButtons = <_StudyButton>[?play, ?now];
    final double inlineWidth = debugButtons.isEmpty
        ? 0
        : _sidebarBoxPadding.horizontal +
              _measureText(context, 'Time of day', labelStyle) +
              _sidebarGap +
              _sidebarSliderMinWidth +
              _sidebarGap +
              math.max(
                _sidebarClockMinWidth,
                _measureText(context, clock, valueStyle),
              ) +
              debugButtons.fold<double>(
                0,
                (double sum, _StudyButton button) =>
                    sum + _sidebarGap + button.measure(context),
              );
    final Widget timeBox = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool inline = inlineWidth <= constraints.maxWidth;
        return _ControlBox(
          compact: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _SidebarSliderRow(
                label: 'Time of day',
                labelStyle: labelStyle,
                slider: hourSlider,
                value: clock,
                valueStyle: valueStyle,
                valueMinWidth: _sidebarClockMinWidth,
                trailing: inline ? debugButtons : const <Widget>[],
              ),
              if (!inline && debugButtons.isNotEmpty)
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: _sidebarGap,
                  children: debugButtons,
                ),
            ],
          ),
        );
      },
    );
    final Widget growthBox = _ControlBox(
      compact: false,
      child: _SidebarSliderRow(
        label: 'Grown through',
        labelStyle: labelStyle,
        slider: growthSlider,
        value: grown,
        valueStyle: valueStyle,
        valueMinWidth: _sidebarGrowthMinWidth,
        trailing: <Widget>[replay],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth >= _boxBasis * 2 + _boxGap) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: timeBox),
                const SizedBox(width: _boxGap),
                Expanded(child: growthBox),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              timeBox,
              const SizedBox(height: _boxGap),
              growthBox,
            ],
          );
        },
      ),
    );
  }
}

double _measureText(BuildContext context, String text, TextStyle style) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final double width = painter.width;
  painter.dispose();
  return width;
}

class _ControlBox extends StatelessWidget {
  const _ControlBox({required this.compact, required this.child});

  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.cardWarm,
        border: context.shadows.outline,
        borderRadius: BorderRadius.all(Radius.circular(compact ? 12 : 13)),
        boxShadow: context.shadows.cardDefault,
      ),
      child: Padding(
        padding: compact ? _compactBoxPadding : _sidebarBoxPadding,
        child: child,
      ),
    );
  }
}

class _SidebarSliderRow extends StatelessWidget {
  const _SidebarSliderRow({
    required this.label,
    required this.labelStyle,
    required this.slider,
    required this.value,
    required this.valueStyle,
    required this.valueMinWidth,
    required this.trailing,
  });

  final String label;
  final TextStyle labelStyle;
  final Widget slider;
  final String value;
  final TextStyle valueStyle;
  final double valueMinWidth;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        ExcludeSemantics(
          child: Text(label, maxLines: 1, softWrap: false, style: labelStyle),
        ),
        const SizedBox(width: _sidebarGap),
        Expanded(child: slider),
        const SizedBox(width: _sidebarGap),
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: valueMinWidth),
          child: ExcludeSemantics(
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.right,
              style: valueStyle,
            ),
          ),
        ),
        for (final Widget control in trailing) ...<Widget>[
          const SizedBox(width: _sidebarGap),
          control,
        ],
      ],
    );
  }
}

class _CompactSliderRow extends StatelessWidget {
  const _CompactSliderRow({
    required this.label,
    required this.labelStyle,
    required this.slider,
    required this.value,
    required this.valueStyle,
  });

  final String label;
  final TextStyle labelStyle;
  final Widget slider;
  final String value;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: _compactLabelWidth,
          child: ExcludeSemantics(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
        ),
        const SizedBox(width: _compactGap),
        Expanded(child: slider),
        const SizedBox(width: _compactGap),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: _compactValueMinWidth),
          child: ExcludeSemantics(
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.right,
              style: valueStyle,
            ),
          ),
        ),
      ],
    );
  }
}

class _NudgeIntent extends Intent {
  const _NudgeIntent(this.steps);

  final int steps;
}

class _EdgeIntent extends Intent {
  const _EdgeIntent(this.toEnd);

  final bool toEnd;
}

const Map<ShortcutActivator, Intent> _sliderShortcuts =
    <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.arrowRight): _NudgeIntent(1),
      SingleActivator(LogicalKeyboardKey.arrowLeft): _NudgeIntent(-1),
      SingleActivator(LogicalKeyboardKey.arrowUp): _NudgeIntent(1),
      SingleActivator(LogicalKeyboardKey.arrowDown): _NudgeIntent(-1),
      SingleActivator(LogicalKeyboardKey.home): _EdgeIntent(false),
      SingleActivator(LogicalKeyboardKey.end): _EdgeIntent(true),
    };

class _MeadowSlider extends StatelessWidget {
  const _MeadowSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.describe,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final String Function(int value) describe;
  final ValueChanged<int> onChanged;

  int get _current => value.clamp(min, max);

  double get _fraction => max <= min ? 0 : (_current - min) / (max - min);

  void _set(int next) {
    final int snapped = (min + ((next - min) / step).round() * step).clamp(
      min,
      max,
    );
    if (snapped != value) {
      onChanged(snapped);
    }
  }

  void _seek(double dx, double width) {
    final double span = width - _handleRadius * 2;
    if (!span.isFinite || span <= 0) {
      return;
    }
    final double fraction = ((dx - _handleRadius) / span).clamp(0.0, 1.0);
    _set(min + ((max - min) * fraction).round());
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final int current = _current;
    final int up = math.min(max, current + step);
    final int down = math.max(min, current - step);
    return Shortcuts(
      shortcuts: _sliderShortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NudgeIntent: CallbackAction<_NudgeIntent>(
            onInvoke: (_NudgeIntent intent) {
              _set(current + intent.steps * step);
              return null;
            },
          ),
          _EdgeIntent: CallbackAction<_EdgeIntent>(
            onInvoke: (_EdgeIntent intent) {
              _set(intent.toEnd ? max : min);
              return null;
            },
          ),
        },
        child: Semantics(
          container: true,
          slider: true,
          label: label,
          value: describe(current),
          increasedValue: describe(up),
          decreasedValue: describe(down),
          onIncrease: () => _set(up),
          onDecrease: () => _set(down),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (TapDownDetails details) =>
                    _seek(details.localPosition.dx, width),
                onHorizontalDragStart: (DragStartDetails details) =>
                    _seek(details.localPosition.dx, width),
                onHorizontalDragUpdate: (DragUpdateDetails details) =>
                    _seek(details.localPosition.dx, width),
                child: FocusRing(
                  onPressed: null,
                  borderRadius: _sliderFocusRadius,
                  child: SizedBox(
                    height: _minTapTarget,
                    width: width,
                    child: CustomPaint(
                      painter: _SliderPainter(
                        fraction: _fraction,
                        trackColor: colors.cardBright,
                        lineColor: colors.line,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  const _SliderPainter({
    required this.fraction,
    required this.trackColor,
    required this.lineColor,
  });

  final double fraction;
  final Color trackColor;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double left = _handleRadius;
    final double right = size.width - _handleRadius;
    if (right <= left) {
      return;
    }
    final double centerY = size.height / 2;
    final RRect track = RRect.fromLTRBR(
      left,
      centerY - _trackRadius,
      right,
      centerY + _trackRadius,
      const Radius.circular(_trackRadius),
    );
    canvas.drawRRect(track, Paint()..color = trackColor);
    final double filled = (right - left) * fraction.clamp(0.0, 1.0);
    if (filled > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          left,
          track.top,
          left + filled,
          track.bottom,
          const Radius.circular(_trackRadius),
        ),
        Paint()..color = Palette.coral,
      );
    }
    final Paint outline = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = Shapes.outlineWidth;
    canvas.drawRRect(track, outline);
    final Offset handle = Offset(left + filled, centerY);
    canvas.drawCircle(handle, _handleRadius, Paint()..color = Palette.coral);
    canvas.drawCircle(handle, _handleRadius, outline);
  }

  @override
  bool shouldRepaint(_SliderPainter oldDelegate) =>
      fraction != oldDelegate.fraction ||
      trackColor != oldDelegate.trackColor ||
      lineColor != oldDelegate.lineColor;
}

enum _PlayGlyph { fastForward, pause }

class _StudyButton extends StatelessWidget {
  const _StudyButton({
    required this.label,
    required this.compact,
    required this.onPressed,
    this.filled = false,
    this.glyph,
  });

  final String label;
  final bool compact;
  final VoidCallback onPressed;
  final bool filled;
  final _PlayGlyph? glyph;

  double get _glyphSize => compact ? 10 : 11;

  double get _glyphGap => compact ? 5 : 7;

  EdgeInsets get _padding {
    if (compact) {
      return EdgeInsets.symmetric(
        horizontal: glyph == null && filled ? 9 : 8,
        vertical: 6,
      );
    }
    if (glyph != null) {
      return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    }
    return EdgeInsets.symmetric(horizontal: filled ? 11 : 10, vertical: 7);
  }

  TextStyle _textStyle(BuildContext context) =>
      context.textStyles.captureLabelSans.copyWith(
        color: filled ? Palette.onAccent : context.colors.ink,
        fontSize: compact ? 10 : 12,
      );

  double measure(BuildContext context) => math.max(
    _minTapTarget,
    Shapes.outlineWidth * 2 +
        _padding.horizontal +
        (glyph == null ? 0 : _glyphSize + _glyphGap) +
        _measureText(context, label, _textStyle(context)),
  );

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final Color foreground = filled ? Palette.onAccent : colors.ink;
    final BorderRadius radius = BorderRadius.all(
      Radius.circular(compact ? 9 : 11),
    );
    final _PlayGlyph? shape = glyph;
    final Widget face = DecoratedBox(
      decoration: BoxDecoration(
        color: filled ? Palette.coral : colors.cardBright,
        border: context.shadows.outline,
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: filled ? colors.shadow : colors.shadowTint(0x33),
            offset: const Offset(1.5, 1.5),
          ),
        ],
      ),
      child: Padding(
        padding: _padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (shape != null) ...<Widget>[
              CustomPaint(
                size: Size.square(_glyphSize),
                painter: _PlayGlyphPainter(glyph: shape, color: foreground),
              ),
              SizedBox(width: _glyphGap),
            ],
            ExcludeSemantics(
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: _textStyle(context),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
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

class _PlayGlyphPainter extends CustomPainter {
  const _PlayGlyphPainter({required this.glyph, required this.color});

  final _PlayGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 24;
    final Paint fill = Paint()..color = color;
    canvas.save();
    canvas.scale(scale);
    switch (glyph) {
      case _PlayGlyph.fastForward:
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
      case _PlayGlyph.pause:
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
  bool shouldRepaint(_PlayGlyphPainter oldDelegate) =>
      glyph != oldDelegate.glyph || color != oldDelegate.color;
}
