import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/entry_cards/util/duration_format.dart';

import 'stage_phase.dart';

const Key recorderStatusTextKey = ValueKey<String>('recorder-status-text');
const Key recorderTimerKey = ValueKey<String>('recorder-timer');
const Key recorderStatusDotKey = ValueKey<String>('recorder-status-dot');

const Color _statusInk = Color(0xFFDCCAB0);
const Color _timerInk = Color(0xFFB7A58C);
const Color _pausedDot = Color(0xFFD9B36B);
const Color _numeralInk = Color(0xFFF3E6D1);

const double _sidebarStatusSize = 21;
const double _bottomBarStatusSize = 18;
const double _timerSize = 12;
const double _timerTracking = 0.08 * _timerSize;
const double _sidebarTimerBand = 22;
const double _bottomBarTimerBand = 18;
const double _stackedTimerGap = 4;
const double _inlineGap = 9;
const double _dotSize = 8;
const double _dotMinOpacity = 0.45;
const double _dotGlowAlpha = 0.6;
const Duration _dotGlowHalfCycle = Duration(milliseconds: 1500);

const int _countdownFrom = 3;
const int _countdownTo = 1;
const Duration _countdownStep = Duration(seconds: 1);
const double _numeralSize = 1.25;
const double _numeralGap = 0.28;
const double _numeralMinWidth = 0.6;
const Duration _numeralMotion = Duration(seconds: 1);
const double _numeralEnterWeight = 22;
const double _numeralHoldWeight = 58;
const double _numeralLeaveWeight = 20;
const double _numeralEnterScale = 1.3;
const double _numeralHoldScale = 0.98;
const double _numeralLeaveScale = 0.9;
const Curve _numeralCurve = Curves.easeOut;

Animatable<double> _eased(double begin, double end) => Tween<double>(
  begin: begin,
  end: end,
).chain(CurveTween(curve: _numeralCurve));

final Animatable<double> _numeralOpacity = TweenSequence<double>(
  <TweenSequenceItem<double>>[
    TweenSequenceItem<double>(tween: _eased(0, 1), weight: _numeralEnterWeight),
    TweenSequenceItem<double>(tween: _eased(1, 1), weight: _numeralHoldWeight),
    TweenSequenceItem<double>(tween: _eased(1, 0), weight: _numeralLeaveWeight),
  ],
);

final Animatable<double> _numeralScale = TweenSequence<double>(
  <TweenSequenceItem<double>>[
    TweenSequenceItem<double>(
      tween: _eased(_numeralEnterScale, 1),
      weight: _numeralEnterWeight,
    ),
    TweenSequenceItem<double>(
      tween: _eased(1, _numeralHoldScale),
      weight: _numeralHoldWeight,
    ),
    TweenSequenceItem<double>(
      tween: _eased(_numeralHoldScale, _numeralLeaveScale),
      weight: _numeralLeaveWeight,
    ),
  ],
);

int _numeralAt(Duration elapsed) =>
    (_countdownFrom - elapsed.inMicroseconds ~/ _countdownStep.inMicroseconds)
        .clamp(_countdownTo, _countdownFrom);

TextStyle _statusStyle(double size) => TextStyle(
  fontFamily: TypographyTokens.accent,
  fontSize: size,
  fontWeight: FontWeight.w600,
  color: _statusInk,
);

class RecorderStatusLine extends StatefulWidget {
  const RecorderStatusLine({
    super.key,
    required this.phase,
    required this.elapsed,
    this.savingText,
    required this.inline,
  });

  final StagePhase phase;
  final Duration elapsed;
  final String? savingText;
  final bool inline;

  @override
  State<RecorderStatusLine> createState() => _RecorderStatusLineState();
}

class _RecorderStatusLineState extends State<RecorderStatusLine>
    with SingleTickerProviderStateMixin {
  late final Ticker _countdown = createTicker(_tick);
  int _numeral = _countdownFrom;

  StagePhase get _phase => widget.phase;

  bool get _breathing => _phase == StagePhase.breathing;

  @override
  void initState() {
    super.initState();
    if (_breathing) {
      _countdown.start();
    }
  }

  @override
  void didUpdateWidget(RecorderStatusLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool wasBreathing = oldWidget.phase == StagePhase.breathing;
    if (_breathing && !wasBreathing) {
      _numeral = _countdownFrom;
      _countdown
        ..stop()
        ..start();
    } else if (!_breathing && wasBreathing) {
      _countdown.stop();
    }
  }

  void _tick(Duration elapsed) {
    final int numeral = _numeralAt(elapsed);
    if (numeral == _countdownTo) {
      _countdown.stop();
    }
    if (numeral != _numeral) {
      setState(() => _numeral = numeral);
    }
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ShellLayout layout = stageLayoutOf(context);
    final Widget status = _status(context, layout);
    final Widget? timer = _phase.showsTimer ? _timer() : null;
    if (widget.inline) {
      final Widget? dot = _dot(context);
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (dot != null) ...<Widget>[dot, const SizedBox(width: _inlineGap)],
          Flexible(child: status),
          if (timer != null) ...<Widget>[
            const SizedBox(width: _inlineGap),
            timer,
          ],
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        status,
        const SizedBox(height: _stackedTimerGap),
        SizedBox(
          height: layout == ShellLayout.sidebar
              ? _sidebarTimerBand
              : _bottomBarTimerBand,
          child: Center(child: timer),
        ),
      ],
    );
  }

  Widget _status(BuildContext context, ShellLayout layout) {
    final double size = layout == ShellLayout.sidebar
        ? _sidebarStatusSize
        : _bottomBarStatusSize;
    final String text = _phase.statusText(
      layout: layout,
      savingText: widget.savingText,
    );
    if (_breathing) {
      return Semantics(
        container: true,
        liveRegion: true,
        label: _phase.announcement,
        child: ExcludeSemantics(child: _countdownLine(context, text, size)),
      );
    }
    return Semantics(
      container: true,
      liveRegion: true,
      label: _phase.announcement,
      value: text,
      child: ExcludeSemantics(
        child: Text(
          text,
          key: recorderStatusTextKey,
          textAlign: TextAlign.center,
          style: _statusStyle(size),
        ),
      ),
    );
  }

  Widget _countdownLine(BuildContext context, String words, double size) {
    final double em = MediaQuery.textScalerOf(context).scale(size);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Text(
            words,
            key: recorderStatusTextKey,
            maxLines: 1,
            softWrap: false,
            style: _statusStyle(size),
          ),
          SizedBox(width: em * _numeralGap),
          _CountdownNumeral(
            key: ValueKey<int>(_numeral),
            numeral: _numeral,
            size: size,
            minWidth: em * _numeralMinWidth,
          ),
        ],
      ),
    );
  }

  Widget _timer() {
    return Semantics(
      container: true,
      child: Text(
        formatMediaDuration(widget.elapsed.inMilliseconds),
        key: recorderTimerKey,
        maxLines: 1,
        style: const TextStyle(
          fontFamily: TypographyTokens.sans,
          fontSize: _timerSize,
          fontWeight: FontWeight.w500,
          letterSpacing: _timerTracking,
          color: _timerInk,
        ),
      ),
    );
  }

  Widget? _dot(BuildContext context) {
    if (_phase == StagePhase.recording) {
      return Blink(
        key: recorderStatusDotKey,
        minOpacity: _dotMinOpacity,
        duration: _dotGlowHalfCycle,
        animate: !MediaQuery.disableAnimationsOf(context),
        child: _Dot(color: context.colors.accentBright, glow: true),
      );
    }
    if (_phase == StagePhase.paused) {
      return const _Dot(
        key: recorderStatusDotKey,
        color: _pausedDot,
        glow: false,
      );
    }
    return null;
  }
}

class _CountdownNumeral extends StatefulWidget {
  const _CountdownNumeral({
    super.key,
    required this.numeral,
    required this.size,
    required this.minWidth,
  });

  final int numeral;
  final double size;
  final double minWidth;

  @override
  State<_CountdownNumeral> createState() => _CountdownNumeralState();
}

class _CountdownNumeralState extends State<_CountdownNumeral>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: _numeralMotion,
  );
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _motion.stop();
    } else if (!_motion.isAnimating && !_motion.isCompleted) {
      _motion.forward();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _motion,
      builder: (BuildContext context, Widget? child) {
        final double progress = _motion.value;
        return Opacity(
          opacity: _still ? 1 : _numeralOpacity.transform(progress),
          child: Transform.scale(
            scale: _still ? 1 : _numeralScale.transform(progress),
            child: child,
          ),
        );
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: widget.minWidth),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            '${widget.numeral}',
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontFamily: TypographyTokens.accent,
              fontSize: widget.size * _numeralSize,
              fontWeight: FontWeight.w600,
              color: _numeralInk,
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({super.key, required this.color, required this.glow});

  final Color color;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _dotSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: glow
              ? <BoxShadow>[
                  BoxShadow(
                    color: color.withValues(alpha: _dotGlowAlpha),
                    blurRadius: _dotSize,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
