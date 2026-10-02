import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/calendar/model/calendar_month.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/model/meadow_year_replay.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/sky/sky_astronomy.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:field_notes/features/garden/widgets/meadow_full_screen.dart'
    show meadowFullScreenBackdrop;
import 'package:field_notes/features/garden/widgets/meadow_study_controls.dart'
    show meadowReplayLabel;
import 'package:field_notes/features/onboarding/chapters/sample_year.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _kicker = 'a year';
const String _title = 'This is roughly what a year of you looks like.';
const String yearWholeLabel = 'A whole year';
const String yearCaptionSidebar =
    'every flower is a day · drag back through it';
const String yearCaptionBottomBar = 'every flower is a day · drag through it';
const String yearSliderLabel = 'The sample year';
const Duration yearReplayDuration = Duration(seconds: 11);

const Key yearSliderKey = ValueKey<String>('year-slider');
const Key yearReplayKey = ValueKey<String>('year-replay');
const Key yearControlsKey = ValueKey<String>('year-controls');

const double _firstHour = 5;
const double _hourSpan = 16.8;
const int _skyMonth = 9;
const int _skyDay = 23;

const Color _kickerInk = Color(0xFFF6C9B8);
const Color _glassFill = Color.fromRGBO(28, 22, 16, 0.5);
const Color _boxEdge = Color.fromRGBO(251, 243, 228, 0.35);
const Color _buttonEdge = Color.fromRGBO(251, 243, 228, 0.55);
const Color _daysInk = Color.fromRGBO(251, 243, 228, 0.8);
const Color _trackRest = Color.fromRGBO(251, 243, 228, 0.35);
const Color _trackFill = Color(0xFFF2C14E);
const Color _shadeTop = Color.fromRGBO(20, 14, 8, 1);
const Color _textShadow = Color.fromRGBO(0, 0, 0, 1);

const double _target = 48;
const double _shadeHeight = 200;
const double _glassBorder = 1.5;
const double _boxBlurSigma = 4;
const double _buttonBlurSigma = 3;
const double _boxMaxWidth = 460;
const double _rowGap = 20;
const double _stackGap = 8;
const double _captionLift = 8;
const double _thumbRadius = 8;
const double _trackHeight = 4;
const double _replayStroke = 2.2;
const BorderRadius _sliderFocusRadius = BorderRadius.all(Radius.circular(9));

const Duration _headingRise = Duration(milliseconds: 600);
const Duration _headingDelay = Duration(milliseconds: 300);
const Duration _captionFade = Duration(milliseconds: 600);
const double _riseDistance = 14;

const int _lastIndex = sampleYearDays - 1;

String yearMonthLabel(int day) {
  if (day >= sampleYearDays) {
    return yearWholeLabel;
  }
  final int index = day.clamp(0, _lastIndex);
  return monthName(DateTime(sampleYearNumber, 1, 1 + index).month);
}

String yearDaysLabel(int day) =>
    '${day.clamp(0, sampleYearDays)} of $sampleYearDays days';

double yearHourAt(int day) =>
    _firstHour + day.clamp(0, sampleYearDays) / sampleYearDays * _hourSpan;

DateTime yearSkyInstant(int day) => DateTime(
  sampleYearNumber,
  _skyMonth,
  _skyDay,
  0,
  (yearHourAt(day) * Duration.minutesPerHour).round(),
);

@immutable
class _YearMetrics {
  const _YearMetrics({
    required this.headingPadding,
    required this.headingAlign,
    required this.kickerSize,
    required this.titleSize,
    required this.titleShadowBlur,
    required this.titleShadowAlpha,
    required this.shadeAlpha,
    required this.controls,
    required this.boxRadius,
    required this.boxPadding,
    required this.monthSize,
    required this.daysSize,
    required this.captionSize,
  });

  static const _YearMetrics sidebar = _YearMetrics(
    headingPadding: EdgeInsets.fromLTRB(40, 36, 40, 0),
    headingAlign: TextAlign.center,
    kickerSize: 21,
    titleSize: 44,
    titleShadowBlur: 16,
    titleShadowAlpha: 0.4,
    shadeAlpha: 0.42,
    controls: EdgeInsets.fromLTRB(56, 0, 56, 84),
    boxRadius: 14,
    boxPadding: EdgeInsets.fromLTRB(15, 11, 15, 0),
    monthSize: 22,
    daysSize: 11,
    captionSize: 19,
  );

  static const _YearMetrics bottomBar = _YearMetrics(
    headingPadding: EdgeInsets.fromLTRB(18, 22, 18, 0),
    headingAlign: TextAlign.start,
    kickerSize: 18,
    titleSize: 28,
    titleShadowBlur: 14,
    titleShadowAlpha: 0.45,
    shadeAlpha: 0.55,
    controls: EdgeInsets.fromLTRB(14, 0, 14, 74),
    boxRadius: 13,
    boxPadding: EdgeInsets.fromLTRB(12, 9, 12, 0),
    monthSize: 19,
    daysSize: 10,
    captionSize: 16,
  );

  final EdgeInsets headingPadding;
  final TextAlign headingAlign;
  final double kickerSize;
  final double titleSize;
  final double titleShadowBlur;
  final double titleShadowAlpha;
  final double shadeAlpha;
  final EdgeInsets controls;
  final double boxRadius;
  final EdgeInsets boxPadding;
  final double monthSize;
  final double daysSize;
  final double captionSize;

  static _YearMetrics of(ShellLayout layout) => switch (layout) {
    ShellLayout.sidebar => sidebar,
    ShellLayout.bottomBar => bottomBar,
  };
}

class YearChapter extends ConsumerStatefulWidget {
  const YearChapter({super.key, required this.layout});

  final ShellLayout layout;

  @override
  ConsumerState<YearChapter> createState() => _YearChapterState();
}

class _YearChapterState extends ConsumerState<YearChapter>
    with SingleTickerProviderStateMixin {
  final MeadowYear _year = buildSampleMeadowYear();
  late final MeadowYearReplay _replay;
  bool _started = false;
  bool _growAnimated = false;

  @override
  void initState() {
    super.initState();
    _replay = MeadowYearReplay(
      vsync: this,
      duration: yearReplayDuration,
      onGrowth: _grown,
    );
  }

  @override
  void dispose() {
    _replay.dispose();
    super.dispose();
  }

  OnboardingController get _controller =>
      ref.read(onboardingControllerProvider.notifier);

  void _shown() {
    if (_started) {
      return;
    }
    _started = true;
    _play();
  }

  void _play() => _replay.start(
    limit: sampleYearDays,
    reduceMotion: MediaQuery.disableAnimationsOf(context),
  );

  void _grown(int point, bool animated) {
    if (animated != _growAnimated) {
      setState(() => _growAnimated = animated);
    }
    _controller.setYearDay(point, scrubbed: false);
  }

  void _scrub(int day) {
    _replay.stop();
    if (_growAnimated) {
      setState(() => _growAnimated = false);
    }
    _controller.setYearDay(day, scrubbed: true);
  }

  @override
  Widget build(BuildContext context) {
    final int? yearDay = ref.watch(
      onboardingControllerProvider.select(
        (OnboardingFlow flow) => switch (flow) {
          OnboardingFlowRunning(:final OnboardingDraft draft) => draft.yearDay,
          OnboardingFlowHidden() || OnboardingFlowMap() => null,
        },
      ),
    );
    if (yearDay == null) {
      return const SizedBox.expand();
    }
    final SkyLocation location =
        ref.watch(skyLocationProvider).value ??
        resolveSkyLocation(null, DateTime.now().timeZoneOffset);
    final DateTime instant = yearSkyInstant(yearDay);
    final ShellLayout layout = widget.layout;
    final _YearMetrics metrics = _YearMetrics.of(layout);
    return SizedBox.expand(
      child: ColoredBox(
        color: meadowFullScreenBackdrop,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            MeadowStage(
              year: _year,
              seed: sampleMeadowSeed,
              sky: skySceneAt(instant, location.latitude, location.longitude),
              morning:
                  sunPosition(
                    instant,
                    location.latitude,
                    location.longitude,
                  ).azimuth <
                  0,
              mode: MeadowSceneMode.full,
              compact: false,
              growthPoint: yearDay,
              growAnimated: _growAnimated,
              readyOverlay: _ReadySignal(
                onShown: _shown,
                child: _Controls(
                  key: yearControlsKey,
                  layout: layout,
                  metrics: metrics,
                  day: yearDay,
                  onScrub: _scrub,
                  onReplay: _play,
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: _shadeHeight,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        _shadeTop.withValues(alpha: metrics.shadeAlpha),
                        _shadeTop.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              child: IgnorePointer(
                child: _Rise(child: _Heading(metrics: metrics)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.metrics});

  final _YearMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final bool centred = metrics.headingAlign == TextAlign.center;
    return Padding(
      padding: metrics.headingPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: centred
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _kicker,
            textAlign: metrics.headingAlign,
            style: TextStyle(
              fontFamily: TypographyTokens.accent,
              fontSize: metrics.kickerSize,
              fontWeight: FontWeight.w600,
              color: _kickerInk,
              shadows: <Shadow>[
                Shadow(
                  color: _textShadow.withValues(alpha: 0.4),
                  offset: const Offset(0, 1),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              _title,
              textAlign: metrics.headingAlign,
              style: TextStyle(
                fontFamily: TypographyTokens.serif,
                fontSize: metrics.titleSize,
                fontWeight: FontWeight.w500,
                height: 1.05,
                color: FieldNotesColors.light.composerPaper,
                shadows: <Shadow>[
                  Shadow(
                    color: _textShadow.withValues(
                      alpha: metrics.titleShadowAlpha,
                    ),
                    offset: const Offset(0, 2),
                    blurRadius: metrics.titleShadowBlur,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadySignal extends StatefulWidget {
  const _ReadySignal({required this.onShown, required this.child});

  final VoidCallback onShown;
  final Widget child;

  @override
  State<_ReadySignal> createState() => _ReadySignalState();
}

class _ReadySignalState extends State<_ReadySignal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        widget.onShown();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Controls extends StatelessWidget {
  const _Controls({
    super.key,
    required this.layout,
    required this.metrics,
    required this.day,
    required this.onScrub,
    required this.onReplay,
  });

  final ShellLayout layout;
  final _YearMetrics metrics;
  final int day;
  final ValueChanged<int> onScrub;
  final VoidCallback onReplay;

  bool get _whole => day >= sampleYearDays;

  @override
  Widget build(BuildContext context) {
    final Widget box = _GlassBox(
      metrics: metrics,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Expanded(
                  child: Text(
                    yearMonthLabel(day),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: TypographyTokens.accent,
                      fontSize: metrics.monthSize,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: FieldNotesColors.light.composerPaper,
                    ),
                  ),
                ),
                Text(
                  yearDaysLabel(day),
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: TypographyTokens.sans,
                    fontSize: metrics.daysSize,
                    fontWeight: FontWeight.w600,
                    color: _daysInk,
                  ),
                ),
              ],
            ),
          ),
          _YearSlider(key: yearSliderKey, day: day, onChanged: onScrub),
        ],
      ),
    );
    final String caption = switch (layout) {
      ShellLayout.sidebar => yearCaptionSidebar,
      ShellLayout.bottomBar => yearCaptionBottomBar,
    };
    final Widget? shownCaption = _whole
        ? _Caption(text: caption, size: metrics.captionSize, layout: layout)
        : null;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned(
          left: metrics.controls.left,
          right: metrics.controls.right,
          bottom: metrics.controls.bottom,
          child: switch (layout) {
            ShellLayout.sidebar => Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _boxMaxWidth),
                    child: box,
                  ),
                ),
                const SizedBox(width: _rowGap),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: _captionLift),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: shownCaption ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SizedBox(width: _rowGap),
                _ReplayButton(
                  key: yearReplayKey,
                  layout: layout,
                  onPressed: onReplay,
                ),
              ],
            ),
            ShellLayout.bottomBar => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (shownCaption != null) ...<Widget>[
                  Center(child: shownCaption),
                  const SizedBox(height: _stackGap),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(child: box),
                    const SizedBox(width: _stackGap),
                    _ReplayButton(
                      key: yearReplayKey,
                      layout: layout,
                      onPressed: onReplay,
                    ),
                  ],
                ),
              ],
            ),
          },
        ),
      ],
    );
  }
}

class _GlassBox extends StatelessWidget {
  const _GlassBox({required this.metrics, required this.child});

  final _YearMetrics metrics;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.all(
      Radius.circular(metrics.boxRadius),
    );
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: _boxBlurSigma,
          sigmaY: _boxBlurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _glassFill,
            border: Border.all(color: _boxEdge, width: _glassBorder),
            borderRadius: radius,
          ),
          child: Padding(
            padding: metrics.boxPadding + const EdgeInsets.all(_glassBorder),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({
    required this.text,
    required this.size,
    required this.layout,
  });

  final String text;
  final double size;
  final ShellLayout layout;

  @override
  Widget build(BuildContext context) {
    return _FadeIn(
      child: Text(
        text,
        textAlign: layout == ShellLayout.sidebar
            ? TextAlign.end
            : TextAlign.center,
        style: TextStyle(
          fontFamily: TypographyTokens.accent,
          fontSize: size,
          fontWeight: FontWeight.w600,
          color: FieldNotesColors.light.composerPaper,
          shadows: <Shadow>[
            Shadow(
              color: _textShadow.withValues(alpha: 0.5),
              offset: const Offset(0, 1),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplayButton extends StatelessWidget {
  const _ReplayButton({
    super.key,
    required this.layout,
    required this.onPressed,
  });

  final ShellLayout layout;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool sidebar = layout == ShellLayout.sidebar;
    final BorderRadius radius = BorderRadius.all(
      Radius.circular(sidebar ? 11 : 13),
    );
    final Widget face = sidebar
        ? Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 13 + _glassBorder,
              vertical: 9 + _glassBorder,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _ReplayGlyph(size: 12),
                const SizedBox(width: 7),
                Text(
                  meadowReplayLabel,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: TypographyTokens.sans,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FieldNotesColors.light.composerPaper,
                  ),
                ),
              ],
            ),
          )
        : const SizedBox.square(
            dimension: _target,
            child: Center(child: _ReplayGlyph(size: 16)),
          );
    return Semantics(
      button: true,
      label: meadowReplayLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _target,
            minHeight: _target,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: FocusRing(
              onPressed: onPressed,
              surface: FocusRingSurface.dark,
              borderRadius: radius,
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: _buttonBlurSigma,
                    sigmaY: _buttonBlurSigma,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _glassFill,
                      border: Border.all(
                        color: _buttonEdge,
                        width: _glassBorder,
                      ),
                      borderRadius: radius,
                    ),
                    child: ExcludeSemantics(child: face),
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

class _ReplayGlyph extends StatelessWidget {
  const _ReplayGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ReplayGlyphPainter(color: FieldNotesColors.light.composerPaper),
    );
  }
}

class _ReplayGlyphPainter extends CustomPainter {
  const _ReplayGlyphPainter({required this.color});

  final Color color;

  static const double _viewBox = 24;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / _viewBox);
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _replayStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawPath(
      Path()
        ..moveTo(4, 12)
        ..relativeArcToPoint(
          const Offset(2.4, -5.7),
          radius: const Radius.circular(8),
          largeArc: true,
          clockwise: false,
        )
        ..moveTo(4, 4)
        ..lineTo(4, 9)
        ..lineTo(9, 9),
      stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ReplayGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _NudgeIntent extends Intent {
  const _NudgeIntent(this.days);

  final int days;
}

class _EdgeIntent extends Intent {
  const _EdgeIntent({required this.toEnd});

  final bool toEnd;
}

const Map<ShortcutActivator, Intent> _sliderKeys = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.arrowRight): _NudgeIntent(1),
  SingleActivator(LogicalKeyboardKey.arrowUp): _NudgeIntent(1),
  SingleActivator(LogicalKeyboardKey.arrowLeft): _NudgeIntent(-1),
  SingleActivator(LogicalKeyboardKey.arrowDown): _NudgeIntent(-1),
  SingleActivator(LogicalKeyboardKey.home): _EdgeIntent(toEnd: false),
  SingleActivator(LogicalKeyboardKey.end): _EdgeIntent(toEnd: true),
};

String _describe(int day) => '${yearMonthLabel(day)}, ${yearDaysLabel(day)}';

class _YearSlider extends StatelessWidget {
  const _YearSlider({super.key, required this.day, required this.onChanged});

  final int day;
  final ValueChanged<int> onChanged;

  int get _current => day.clamp(0, sampleYearDays);

  void _set(int next) {
    final int clamped = next.clamp(0, sampleYearDays);
    if (clamped != _current) {
      onChanged(clamped);
    }
  }

  void _seek(double dx, double width) {
    final double span = width - _thumbRadius * 2;
    if (!span.isFinite || span <= 0) {
      return;
    }
    final double fraction = ((dx - _thumbRadius) / span).clamp(0.0, 1.0);
    onChanged((fraction * sampleYearDays).round());
  }

  @override
  Widget build(BuildContext context) {
    final int current = _current;
    final bool canGrow = current < sampleYearDays;
    final bool canShrink = current > 0;
    return Shortcuts(
      shortcuts: _sliderKeys,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NudgeIntent: CallbackAction<_NudgeIntent>(
            onInvoke: (_NudgeIntent intent) {
              _set(current + intent.days);
              return null;
            },
          ),
          _EdgeIntent: CallbackAction<_EdgeIntent>(
            onInvoke: (_EdgeIntent intent) {
              _set(intent.toEnd ? sampleYearDays : 0);
              return null;
            },
          ),
        },
        child: Semantics(
          container: true,
          slider: true,
          label: yearSliderLabel,
          value: _describe(current),
          increasedValue: canGrow ? _describe(current + 1) : null,
          decreasedValue: canShrink ? _describe(current - 1) : null,
          onIncrease: canGrow ? () => _set(current + 1) : null,
          onDecrease: canShrink ? () => _set(current - 1) : null,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
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
                    width: width,
                    height: _target,
                    child: CustomPaint(
                      painter: _TrackPainter(
                        fraction: current / sampleYearDays,
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

class _TrackPainter extends CustomPainter {
  const _TrackPainter({required this.fraction});

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const double left = _thumbRadius;
    final double right = size.width - _thumbRadius;
    if (right <= left) {
      return;
    }
    final double centre = size.height / 2;
    const Radius round = Radius.circular(_trackHeight / 2);
    final double thumb = left + (right - left) * fraction.clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromLTRBR(
        left,
        centre - _trackHeight / 2,
        right,
        centre + _trackHeight / 2,
        round,
      ),
      Paint()..color = _trackRest,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        left,
        centre - _trackHeight / 2,
        math.max(left, thumb),
        centre + _trackHeight / 2,
        round,
      ),
      Paint()..color = _trackFill,
    );
    canvas.drawCircle(
      Offset(thumb, centre),
      _thumbRadius,
      Paint()..color = _trackFill,
    );
  }

  @override
  bool shouldRepaint(_TrackPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

class _Rise extends StatefulWidget {
  const _Rise({required this.child});

  final Widget child;

  @override
  State<_Rise> createState() => _RiseState();
}

class _RiseState extends State<_Rise> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: _headingDelay + _headingRise,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.value = 1;
    } else if (_clock.isDismissed) {
      _clock.forward();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  double get _progress {
    final int delay = _headingDelay.inMicroseconds;
    final int rise = _headingRise.inMicroseconds;
    final double elapsed = _clock.value * (delay + rise);
    return ((elapsed - delay) / rise).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double eased = Curves.ease.transform(_progress);
        return Opacity(
          opacity: eased,
          alwaysIncludeSemantics: true,
          child: Transform.translate(
            offset: Offset(0, _riseDistance * (1 - eased)),
            child: child,
          ),
        );
      },
    );
  }
}

class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: _captionFade,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.value = 1;
    } else if (_clock.isDismissed) {
      _clock.forward();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _clock,
      alwaysIncludeSemantics: true,
      child: widget.child,
    );
  }
}
