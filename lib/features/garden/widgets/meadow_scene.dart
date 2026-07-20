import 'package:flutter/widgets.dart';

import '../model/garden_data.dart';
import '../model/garden_insect.dart';
import '../model/garden_motion.dart';
import '../model/meadow_layout.dart';
import '../paint/meadow_painter.dart';

const Duration _swayCycle = Duration(seconds: 6);

class MeadowScene extends StatefulWidget {
  const MeadowScene({
    super.key,
    required this.blooms,
    required this.motion,
    this.seed = 0,
    this.insects = defaultGardenInsects,
  });

  final List<GardenBloomData> blooms;
  final GardenMotionProfile motion;
  final int seed;
  final List<GardenInsect> insects;

  @override
  State<MeadowScene> createState() => _MeadowSceneState();
}

class _MeadowSceneState extends State<MeadowScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _swayCycle);
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant MeadowScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.motion != widget.motion) {
      _syncMotion();
    }
  }

  void _syncMotion() {
    if (widget.motion == GardenMotionProfile.full) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      return;
    }
    _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool animate = widget.motion == GardenMotionProfile.full;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        final List<PlantedBloom> planted = layoutMeadow(
          blooms: widget.blooms,
          size: size,
          seed: widget.seed,
        );
        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              return CustomPaint(
                size: size,
                painter: MeadowPainter(
                  t: animate ? _controller.value : 0.0,
                  planted: planted,
                  insects: widget.insects,
                  showInsects: animate,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
