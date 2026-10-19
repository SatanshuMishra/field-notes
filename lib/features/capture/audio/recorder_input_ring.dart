import 'dart:async';
import 'dart:math' as math;

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/capture/audio/microphone_hearing.dart';
import 'package:flutter/widgets.dart';

const Key recorderInputRingKey = ValueKey<String>('recorder-input-ring');

const double recorderInputRingReach = 8;
const double recorderInputRingMaxSpread = 6;
const double recorderInputRingMinOpacity = 0.35;
const double recorderInputRingMaxOpacity = 0.85;
const double recorderInputRingFloor = 0.02;
const Duration recorderInputRingSilence = Duration(milliseconds: 300);
const Duration _release = Duration(milliseconds: 180);

double recorderInputRingSpread(double level) =>
    recorderInputRingMaxSpread * level.clamp(0, 1);

double recorderInputRingOpacity(double level) =>
    recorderInputRingMinOpacity +
    (recorderInputRingMaxOpacity - recorderInputRingMinOpacity) *
        level.clamp(0, 1);

class RecorderInputRing extends StatefulWidget {
  const RecorderInputRing({
    super.key,
    required this.levels,
    required this.child,
    this.hearing = MicrophoneHearing.hearing,
  });

  final Stream<double> levels;
  final MicrophoneHearing hearing;
  final Widget child;

  @override
  State<RecorderInputRing> createState() => _RecorderInputRingState();
}

class _RecorderInputRingState extends State<RecorderInputRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _level = AnimationController(vsync: this);
  StreamSubscription<double>? _subscription;
  Timer? _silence;
  bool _stepping = false;

  bool get _hearing => widget.hearing == MicrophoneHearing.hearing;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(RecorderInputRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.levels != widget.levels) {
      unawaited(_subscription?.cancel());
      _listen();
    }
    if (!_hearing) {
      _fallSilent();
    }
  }

  @override
  void dispose() {
    _silence?.cancel();
    unawaited(_subscription?.cancel());
    _level.dispose();
    super.dispose();
  }

  void _listen() {
    _subscription = widget.levels.listen(_heard);
  }

  void _heard(double level) {
    if (!mounted) {
      return;
    }
    _silence?.cancel();
    _silence = Timer(recorderInputRingSilence, _fallSilent);
    final double target = _hearing ? level.clamp(0, 1).toDouble() : 0;
    if (_stepping || target >= _level.value) {
      _level.value = target;
      return;
    }
    unawaited(
      _level.animateTo(target, duration: _release, curve: Curves.easeOut),
    );
  }

  void _fallSilent() {
    _silence?.cancel();
    _silence = null;
    _level.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    _stepping = MediaQuery.disableAnimationsOf(context);
    final Color highlight = context.colors.accentBright;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: -recorderInputRingReach,
          top: -recorderInputRingReach,
          right: -recorderInputRingReach,
          bottom: -recorderInputRingReach,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _level,
                builder: (BuildContext context, Widget? _) {
                  final double level = _level.value;
                  if (level < recorderInputRingFloor) {
                    return const SizedBox.expand();
                  }
                  return CustomPaint(
                    key: recorderInputRingKey,
                    size: Size.infinite,
                    painter: RecorderInputRingPainter(
                      spread: recorderInputRingSpread(level),
                      opacity: recorderInputRingOpacity(level),
                      highlight: highlight,
                      glow: Palette.coral,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class RecorderInputRingPainter extends CustomPainter {
  const RecorderInputRingPainter({
    required this.spread,
    required this.opacity,
    required this.highlight,
    required this.glow,
  });

  final double spread;
  final double opacity;
  final Color highlight;
  final Color glow;

  double innerRadius(Size size) =>
      math.max(0, size.shortestSide / 2 - recorderInputRingReach);

  double outerRadius(Size size) =>
      innerRadius(size) + math.min(spread, recorderInputRingReach);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = size.center(Offset.zero);
    final double inner = innerRadius(size);
    final double outer = outerRadius(size);
    if (outer <= inner) {
      return;
    }
    final Path ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: centre, radius: outer))
      ..addOval(Rect.fromCircle(center: centre, radius: inner));
    final Paint paint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          highlight.withValues(alpha: opacity),
          highlight.withValues(alpha: opacity),
          glow.withValues(alpha: 0),
        ],
        stops: <double>[0, inner / outer, 1],
      ).createShader(Rect.fromCircle(center: centre, radius: outer));
    canvas.drawPath(ring, paint);
  }

  @override
  bool shouldRepaint(RecorderInputRingPainter oldDelegate) =>
      oldDelegate.spread != spread ||
      oldDelegate.opacity != opacity ||
      oldDelegate.highlight != highlight ||
      oldDelegate.glow != glow;
}
