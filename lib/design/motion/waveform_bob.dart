import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'motion_tokens.dart';

class WaveformBars extends StatefulWidget {
  const WaveformBars({
    super.key,
    this.barCount = 5,
    this.color = Palette.coral,
    this.barWidth = 3,
    this.maxHeight = 20,
    this.minHeightFactor = 0.35,
    this.spacing = 3,
    this.duration = Motion.bob,
    this.animate = true,
  });

  final int barCount;
  final Color color;
  final double barWidth;
  final double maxHeight;
  final double minHeightFactor;
  final double spacing;
  final Duration duration;
  final bool animate;

  @override
  State<WaveformBars> createState() => _WaveformBarsState();
}

class _WaveformBarsState extends State<WaveformBars>
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

  double _heightFor(int index, double t) {
    final double phase = index / widget.barCount;
    final double wave = (math.sin((t + phase) * 2 * math.pi) + 1) / 2;
    final double factor =
        widget.minHeightFactor + (1 - widget.minHeightFactor) * wave;
    return widget.maxHeight * factor;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            for (int i = 0; i < widget.barCount; i++) ...<Widget>[
              if (i > 0) SizedBox(width: widget.spacing),
              SizedBox(
                key: ValueKey<String>('wave-bar-$i'),
                width: widget.barWidth,
                height: _heightFor(i, _controller.value),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.all(
                      Radius.circular(widget.barWidth / 2),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
