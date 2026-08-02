import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'motion_tokens.dart';

class GlowPulse extends StatefulWidget {
  const GlowPulse({
    super.key,
    this.child,
    this.color = Palette.coral,
    this.duration = Motion.pulse,
    this.diameter = 150,
    this.gradientAlpha = 0.4,
    this.gradientStop = 0.68,
    this.minScale = 0.9,
    this.maxScale = 1.25,
    this.minOpacity = 0.18,
    this.maxOpacity = 0.5,
    this.animate = true,
  });

  final Widget? child;
  final Color color;
  final Duration duration;
  final double diameter;
  final double gradientAlpha;
  final double gradientStop;
  final double minScale;
  final double maxScale;
  final double minOpacity;
  final double maxOpacity;
  final bool animate;

  @override
  State<GlowPulse> createState() => _GlowPulseState();
}

class _GlowPulseState extends State<GlowPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _progress =>
      Motion.pulseCurve.transform(1 - (_controller.value * 2 - 1).abs());

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        AnimatedBuilder(
          animation: _controller,
          child: _disc(),
          builder: (BuildContext context, Widget? disc) {
            final double t = _progress;
            return Opacity(
              opacity: widget.maxOpacity +
                  (widget.minOpacity - widget.maxOpacity) * t,
              child: Transform.scale(
                scale:
                    widget.minScale + (widget.maxScale - widget.minScale) * t,
                child: disc,
              ),
            );
          },
        ),
        ?widget.child,
      ],
    );
  }

  Widget _disc() {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            widget.color.withValues(alpha: widget.gradientAlpha),
            widget.color.withValues(alpha: 0),
          ],
          stops: <double>[0, widget.gradientStop],
        ),
      ),
      child: SizedBox.square(dimension: widget.diameter),
    );
  }
}
