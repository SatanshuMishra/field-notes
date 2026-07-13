import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'motion_tokens.dart';

class GlowPulse extends StatefulWidget {
  const GlowPulse({
    super.key,
    required this.child,
    this.color = Palette.coral,
    this.duration = Motion.pulse,
    this.maxBlur = 16,
    this.maxSpread = 2,
    this.maxAlpha = 0.55,
    this.borderRadius = Shapes.cardBorderRadius,
    this.animate = true,
  });

  final Widget child;
  final Color color;
  final Duration duration;
  final double maxBlur;
  final double maxSpread;
  final double maxAlpha;
  final BorderRadius borderRadius;
  final bool animate;

  @override
  State<GlowPulse> createState() => _GlowPulseState();
}

class _GlowPulseState extends State<GlowPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curved = CurvedAnimation(parent: _controller, curve: Motion.pulseCurve);
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curved,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double t = _curved.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.color.withValues(alpha: t * widget.maxAlpha),
                blurRadius: t * widget.maxBlur,
                spreadRadius: t * widget.maxSpread,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}
