import 'package:flutter/widgets.dart';

import 'motion_tokens.dart';

class Blink extends StatefulWidget {
  const Blink({
    super.key,
    required this.child,
    this.duration = Motion.blink,
    this.minOpacity = 0.2,
    this.animate = true,
  });

  final Widget child;
  final Duration duration;
  final double minOpacity;
  final bool animate;

  @override
  State<Blink> createState() => _BlinkState();
}

class _BlinkState extends State<Blink> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = Tween<double>(begin: 1.0, end: widget.minOpacity).animate(
      CurvedAnimation(parent: _controller, curve: Motion.blinkCurve),
    );
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
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}
