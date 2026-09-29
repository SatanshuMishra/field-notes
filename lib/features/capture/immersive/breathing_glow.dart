import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import 'stage_phase.dart';

enum BreathingGlowMode { breathe, settle }

const Duration breathingGlowCycle = Duration(seconds: 10);

const Color _glowCoral = Color(0xFFC76A54);
const Color _ringInk = Color(0x57E7A087);
const double _ringWidth = 1;
const double _glowFadeStop = 0.68;
const double _breatheAlpha = 0.42;
const double _settleAlpha = 0.48;

const double _breatheRestScale = 0.8;
const double _breathePeakScale = 1.12;
const double _breatheRestOpacity = 0.35;
const double _breathePeakOpacity = 0.95;

const double _settleStartScale = 0.55;
const double _settlePeakScale = 1.14;
const double _settleEndScale = 0.82;
const double _settleStartOpacity = 0;
const double _settlePeakOpacity = 0.95;
const double _settleEndOpacity = 0.35;
const double _settlePeakAt = 0.48;

const Curve _segmentCurve = Curves.easeInOut;

class _GlowFrame {
  const _GlowFrame({required this.scale, required this.opacity});

  final double scale;
  final double opacity;
}

const _GlowFrame _breatheRest = _GlowFrame(
  scale: _breatheRestScale,
  opacity: _breatheRestOpacity,
);

const _GlowFrame _settleRest = _GlowFrame(
  scale: _settleEndScale,
  opacity: _settleEndOpacity,
);

_GlowFrame _lerpFrame(_GlowFrame a, _GlowFrame b, double t) {
  final double eased = _segmentCurve.transform(t.clamp(0.0, 1.0));
  return _GlowFrame(
    scale: lerpDouble(a.scale, b.scale, eased)!,
    opacity: lerpDouble(a.opacity, b.opacity, eased)!,
  );
}

_GlowFrame _breatheAt(double t) {
  const _GlowFrame peak = _GlowFrame(
    scale: _breathePeakScale,
    opacity: _breathePeakOpacity,
  );
  final double wrapped = t - t.floorToDouble();
  return wrapped < 0.5
      ? _lerpFrame(_breatheRest, peak, wrapped / 0.5)
      : _lerpFrame(peak, _breatheRest, (wrapped - 0.5) / 0.5);
}

_GlowFrame _settleAt(double t) {
  const _GlowFrame start = _GlowFrame(
    scale: _settleStartScale,
    opacity: _settleStartOpacity,
  );
  const _GlowFrame peak = _GlowFrame(
    scale: _settlePeakScale,
    opacity: _settlePeakOpacity,
  );
  return t < _settlePeakAt
      ? _lerpFrame(start, peak, t / _settlePeakAt)
      : _lerpFrame(
          peak,
          _settleRest,
          (t - _settlePeakAt) / (1 - _settlePeakAt),
        );
}

class BreathingGlow extends StatefulWidget {
  const BreathingGlow({
    super.key,
    required this.diameter,
    this.mode = BreathingGlowMode.breathe,
    this.alpha,
    this.ringInset,
    this.child,
  });

  final double diameter;
  final BreathingGlowMode mode;
  final double? alpha;
  final double? ringInset;
  final Widget? child;

  @override
  State<BreathingGlow> createState() => _BreathingGlowState();
}

class _BreathingGlowState extends State<BreathingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _durationFor(widget.mode),
  );
  bool _still = false;

  static Duration _durationFor(BreathingGlowMode mode) =>
      mode == BreathingGlowMode.breathe
      ? breathingGlowCycle
      : stageBreathDuration;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    _run();
  }

  @override
  void didUpdateWidget(BreathingGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _controller.duration = _durationFor(widget.mode);
      _controller.value = 0;
      _run();
    }
  }

  void _run() {
    if (_still) {
      _controller.stop();
      return;
    }
    if (widget.mode == BreathingGlowMode.breathe) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      return;
    }
    if (!_controller.isAnimating && !_controller.isCompleted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _GlowFrame _frame(double shift) {
    if (_still) {
      return widget.mode == BreathingGlowMode.breathe
          ? _breatheRest
          : _settleRest;
    }
    return widget.mode == BreathingGlowMode.breathe
        ? _breatheAt(_controller.value + shift)
        : _settleAt(_controller.value);
  }

  double get _alpha =>
      widget.alpha ??
      (widget.mode == BreathingGlowMode.breathe ? _breatheAlpha : _settleAlpha);

  @override
  Widget build(BuildContext context) {
    final double? ringInset = widget.ringInset;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.diameter,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned.fill(
              child: _Animated(
                animation: _controller,
                frame: () => _frame(0),
                child: _disc(),
              ),
            ),
            if (ringInset != null)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(ringInset),
                  child: _Animated(
                    animation: _controller,
                    frame: () => _frame(0.5),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: _ringInk, width: _ringWidth),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ?widget.child,
          ],
        ),
      ),
    );
  }

  Widget _disc() {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            _glowCoral.withValues(alpha: _alpha),
            _glowCoral.withValues(alpha: 0),
          ],
          stops: const <double>[0, _glowFadeStop],
        ),
      ),
    );
  }
}

class _Animated extends StatelessWidget {
  const _Animated({
    required this.animation,
    required this.frame,
    required this.child,
  });

  final Animation<double> animation;
  final _GlowFrame Function() frame;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (BuildContext context, Widget? child) {
        final _GlowFrame current = frame();
        return Opacity(
          opacity: current.opacity.clamp(0.0, 1.0),
          child: Transform.scale(scale: current.scale, child: child),
        );
      },
    );
  }
}
