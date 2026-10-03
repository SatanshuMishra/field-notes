import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/format/clock_format.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/garden/model/meadow_year_replay.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/garden_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_glass_popover.dart';
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
const ValueKey<String> meadowStudyPanelKey = ValueKey<String>(
  'meadow-study-panel',
);
const ValueKey<String> meadowReplayKey = ValueKey<String>('meadow-replay');
const ValueKey<String> meadowStudyPlayKey = ValueKey<String>(
  'meadow-study-play',
);

const double _phoneSliderReach = 48;
const double _phoneTrack = 32;
const double _deskTrack = 22;
const double _trackThickness = 4;
const double _phoneHandleRadius = 8;
const double _deskHandleRadius = 7;
const BorderRadius _sliderFocusRadius = BorderRadius.all(Radius.circular(9));
const Color _handleEdge = Color.fromRGBO(20, 14, 8, 0.35);

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

@immutable
class MeadowStudyParts {
  const MeadowStudyParts({
    required this.panel,
    required this.play,
    required this.replay,
    required this.playing,
    required this.planting,
  });

  final Widget panel;
  final Widget play;
  final Widget replay;
  final bool playing;
  final bool planting;
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
    required this.builder,
  });

  final bool compact;
  final int? hourMinutes;
  final ValueChanged<int?> onHour;
  final int limit;
  final int daysInYear;
  final int year;
  final int growthPoint;
  final void Function(int growthPoint, bool growAnimated) onGrowth;
  final SkyMoment moment;
  final Widget Function(BuildContext context, MeadowStudyParts parts) builder;

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
    if (oldWidget.year != widget.year) {
      _stopReplay();
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
    final int limit = math.max(1, widget.limit);
    final String clock = gardenClockLabel(
      context,
      SkyMoment(instant: widget.moment.instant),
    );
    final String grown = _growthLabel(
      widget.year,
      widget.daysInYear,
      widget.growthPoint,
    );
    final Widget hourSlider = _MeadowSlider(
      key: meadowHourSliderKey,
      label: 'Time of day',
      compact: compact,
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
      compact: compact,
      value: widget.growthPoint,
      min: 1,
      max: limit,
      step: 1,
      describe: (int point) =>
          _growthLabel(widget.year, widget.daysInYear, point),
      onChanged: _onGrowthSlider,
    );
    final bool playing = _player.playing;
    final String replayText = _planting
        ? meadowPlantingLabel
        : meadowReplayLabel;
    final Widget panel = GlassSurface(
      key: meadowStudyPanelKey,
      tone: GlassTone.scene,
      borderRadius: BorderRadius.all(Radius.circular(compact ? 14 : 20)),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _SliderRow(
            compact: compact,
            label: 'Time of day',
            slider: hourSlider,
            value: clock,
          ),
          if (!compact) const SizedBox(height: 8),
          _SliderRow(
            compact: compact,
            label: 'Grown through',
            slider: growthSlider,
            value: grown,
          ),
        ],
      ),
    );
    final Widget play = MeadowDockPill(
      key: meadowStudyPlayKey,
      label: playing ? meadowPauseLabel : meadowPlayTheDayLabel,
      glyph: playing ? MeadowPlayGlyph.pause : MeadowPlayGlyph.play,
      onPressed: _togglePlay,
    );
    final Widget replay = compact
        ? _PhoneReplayButton(label: replayText, onPressed: _startReplay)
        : MeadowDockPill(
            key: meadowReplayKey,
            label: replayText,
            filled: true,
            onPressed: _startReplay,
          );
    return widget.builder(
      context,
      MeadowStudyParts(
        panel: MeadowChromeBlock(child: panel),
        play: play,
        replay: replay,
        playing: playing,
        planting: _planting,
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.compact,
    required this.label,
    required this.slider,
    required this.value,
  });

  final bool compact;
  final String label;
  final Widget slider;
  final String value;

  @override
  Widget build(BuildContext context) {
    final double gap = compact ? 10 : 12;
    return Row(
      children: <Widget>[
        SizedBox(
          width: compact ? 84 : 96,
          child: ExcludeSemantics(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: meadowSans(compact ? 11 : 12, opacity: 0.85),
            ),
          ),
        ),
        SizedBox(width: gap),
        Expanded(child: slider),
        SizedBox(width: gap),
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: compact ? 54 : 64),
          child: ExcludeSemantics(
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.right,
              style: meadowSans(compact ? 12 : 13),
            ),
          ),
        ),
      ],
    );
  }
}

const double _replayPadding = 12;
const String _replayShortLabel = 'Replay';

String _shortReplay(String label) =>
    label == meadowReplayLabel ? _replayShortLabel : label;

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

class _PhoneReplayButton extends StatelessWidget {
  const _PhoneReplayButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const BorderRadius radius = BorderRadius.all(
      Radius.circular(meadowPhoneDockRadius),
    );
    return Semantics(
      key: meadowReplayKey,
      button: true,
      label: label,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          surface: FocusRingSurface.dark,
          borderRadius: radius,
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Palette.coral,
                borderRadius: radius,
                border: Border.all(
                  color: context.colors.line,
                  width: Shapes.outlineWidth,
                ),
              ),
              child: SizedBox(
                height: meadowPhoneControlHeight,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final TextStyle style = meadowSans(13)
                        .copyWith(color: Palette.onAccent);
                    final double room = constraints.maxWidth - _replayPadding;
                    final String shown =
                        _measureText(context, label, style) <= room
                        ? label
                        : _shortReplay(label);
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _replayPadding / 2,
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            shown,
                            maxLines: 1,
                            softWrap: false,
                            style: style,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
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
    required this.compact,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.describe,
    required this.onChanged,
  });

  final String label;
  final bool compact;
  final int value;
  final int min;
  final int max;
  final int step;
  final String Function(int value) describe;
  final ValueChanged<int> onChanged;

  int get _current => value.clamp(min, max);

  double get _fraction => max <= min ? 0 : (_current - min) / (max - min);

  double get _handle => compact ? _phoneHandleRadius : _deskHandleRadius;

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
    final double span = width - _handle * 2;
    if (!span.isFinite || span <= 0) {
      return;
    }
    final double fraction = ((dx - _handle) / span).clamp(0.0, 1.0);
    _set(min + ((max - min) * fraction).round());
  }

  @override
  Widget build(BuildContext context) {
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
                  surface: FocusRingSurface.dark,
                  borderRadius: _sliderFocusRadius,
                  child: SizedBox(
                    height: compact ? _phoneSliderReach : _deskTrack,
                    width: width,
                    child: Center(
                      child: SizedBox(
                        height: compact ? _phoneTrack : _deskTrack,
                        width: width,
                        child: CustomPaint(
                          painter: _SliderPainter(
                            fraction: _fraction,
                            handleRadius: _handle,
                          ),
                        ),
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
  const _SliderPainter({required this.fraction, required this.handleRadius});

  final double fraction;
  final double handleRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final double left = handleRadius;
    final double right = size.width - handleRadius;
    if (right <= left) {
      return;
    }
    final double centerY = size.height / 2;
    const Radius round = Radius.circular(_trackThickness / 2);
    final RRect track = RRect.fromLTRBR(
      left,
      centerY - _trackThickness / 2,
      right,
      centerY + _trackThickness / 2,
      round,
    );
    canvas.drawRRect(track, Paint()..color = meadowCreamAt(0.3));
    final double filled = (right - left) * fraction.clamp(0.0, 1.0);
    if (filled > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(left, track.top, left + filled, track.bottom, round),
        Paint()..color = meadowGold,
      );
    }
    final Offset handle = Offset(left + filled, centerY);
    canvas.drawCircle(handle, handleRadius, Paint()..color = meadowGold);
    canvas.drawCircle(
      handle,
      handleRadius,
      Paint()
        ..color = _handleEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_SliderPainter oldDelegate) =>
      fraction != oldDelegate.fraction ||
      handleRadius != oldDelegate.handleRadius;
}
