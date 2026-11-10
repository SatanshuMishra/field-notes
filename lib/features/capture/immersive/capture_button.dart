import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:field_notes/design/motion/motion_tokens.dart';

import 'stage_phase.dart';

enum CaptureButtonForm { ready, countdown, pause, stop, resume, saving }

CaptureButtonForm captureButtonForm(
  StagePhase stage, {
  required bool canPause,
}) => switch (stage) {
  StagePhase.idle => CaptureButtonForm.ready,
  StagePhase.breathing => CaptureButtonForm.countdown,
  StagePhase.recording =>
    canPause ? CaptureButtonForm.pause : CaptureButtonForm.stop,
  StagePhase.paused => CaptureButtonForm.resume,
  StagePhase.saving => CaptureButtonForm.saving,
};

const double captureRingWidth = 3;

const double _ringStart = -math.pi / 2;
const double _fullTurn = 2 * math.pi;
const double _savingArcShare = 0.26;
const Duration _savingTurn = Duration(milliseconds: 1100);

class CaptureCountdownRingPainter extends CustomPainter {
  const CaptureCountdownRingPainter({
    required this.fraction,
    required this.color,
    this.strokeWidth = captureRingWidth,
  });

  final double fraction;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final double sweep = fraction.clamp(0.0, 1.0) * _fullTurn;
    if (sweep <= 0 || size.isEmpty) {
      return;
    }
    final Rect bounds = (Offset.zero & size).deflate(strokeWidth / 2);
    canvas.drawArc(
      bounds,
      _ringStart,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(CaptureCountdownRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

class CaptureCountdownSweep extends StatelessWidget {
  const CaptureCountdownSweep({
    super.key,
    required this.progress,
    required this.color,
  });

  final Animation<double> progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (BuildContext context, Widget? _) => CustomPaint(
        painter: CaptureCountdownRingPainter(
          fraction: progress.value,
          color: color,
        ),
      ),
    );
  }
}

class CaptureSavingSweep extends StatefulWidget {
  const CaptureSavingSweep({super.key, required this.color});

  final Color color;

  @override
  State<CaptureSavingSweep> createState() => _CaptureSavingSweepState();
}

class _CaptureSavingSweepState extends State<CaptureSavingSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: _savingTurn,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _turn.stop();
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _turn,
      child: CustomPaint(
        painter: CaptureCountdownRingPainter(
          fraction: _savingArcShare,
          color: widget.color,
        ),
      ),
    );
  }
}

class CaptureButtonFace extends StatefulWidget {
  const CaptureButtonFace({
    super.key,
    required this.form,
    required this.diameter,
    required this.fade,
    required this.formKey,
    required this.base,
    required this.core,
  });

  final CaptureButtonForm form;
  final double diameter;
  final Duration fade;
  final Key Function(CaptureButtonForm form) formKey;
  final Widget base;
  final Widget Function(BuildContext context, CaptureButtonForm form) core;

  @override
  State<CaptureButtonFace> createState() => _CaptureButtonFaceState();
}

class _CaptureButtonFaceState extends State<CaptureButtonFace> {
  int _generation = 0;

  @override
  void didUpdateWidget(CaptureButtonFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.form != widget.form) {
      _generation += 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.diameter,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(child: widget.base),
          AnimatedSwitcher(
            duration: widget.fade,
            switchInCurve: Motion.fadeCurve,
            switchOutCurve: Motion.fadeCurve,
            child: KeyedSubtree(
              key: ValueKey<int>(_generation),
              child: KeyedSubtree(
                key: widget.formKey(widget.form),
                child: widget.core(context, widget.form),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
