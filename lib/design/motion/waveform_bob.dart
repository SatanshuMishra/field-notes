import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'motion_tokens.dart';

const double _bobMinScaleY = 0.45;

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
    this.heights,
    this.perBarDurations,
    this.twoToneThreshold,
  });

  final int barCount;
  final Color color;
  final double barWidth;
  final double maxHeight;
  final double minHeightFactor;
  final double spacing;
  final Duration duration;
  final bool animate;
  final List<double>? heights;
  final List<Duration>? perBarDurations;
  final double? twoToneThreshold;

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

  int get _barCount => widget.heights?.length ?? widget.barCount;

  double _heightFor(int index, double t) {
    final List<double>? heights = widget.heights;
    if (heights == null) {
      final double phase = index / widget.barCount;
      final double wave = (math.sin((t + phase) * 2 * math.pi) + 1) / 2;
      final double factor =
          widget.minHeightFactor + (1 - widget.minHeightFactor) * wave;
      return widget.maxHeight * factor;
    }
    return widget.maxHeight * heights[index] * _scaleYFor(index);
  }

  double _scaleYFor(int index) {
    final List<Duration>? durations = widget.perBarDurations;
    if (durations == null || durations.isEmpty) {
      return 1;
    }
    final int periodMicros = durations[index % durations.length].inMicroseconds;
    if (periodMicros <= 0) {
      return 1;
    }
    final Duration elapsed = _controller.lastElapsedDuration ?? Duration.zero;
    final double cycle = (elapsed.inMicroseconds / periodMicros) % 1;
    final double wave = Motion.bobCurve.transform(1 - (cycle * 2 - 1).abs());
    return _bobMinScaleY + (1 - _bobMinScaleY) * wave;
  }

  Color _colorFor(int index) {
    final List<double>? heights = widget.heights;
    final double? threshold = widget.twoToneThreshold;
    if (heights == null || threshold == null) {
      return widget.color;
    }
    return heights[index] > threshold ? widget.color : Palette.waveMid;
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
            for (int i = 0; i < _barCount; i++) ...<Widget>[
              if (i > 0) SizedBox(width: widget.spacing),
              SizedBox(
                key: ValueKey<String>('wave-bar-$i'),
                width: widget.barWidth,
                height: _heightFor(i, _controller.value),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _colorFor(i),
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
