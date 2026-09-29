import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

const Color tourScrimColor = Color(0x8F211810);
const Color tourRingOuterColor = Palette.coral;
const double tourRingInnerWidth = 2;
const double tourRingOuterWidth = 2.5;
const Duration tourMoveDuration = Duration(milliseconds: 420);
const Curve tourMoveCurve = Cubic(0.2, 0.8, 0.2, 1);

class TourSpotlightPainter extends CustomPainter {
  const TourSpotlightPainter({
    required this.hole,
    required this.radius,
    required this.innerRingColor,
  });

  final Rect? hole;
  final double radius;
  final Color innerRingColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect window = Offset.zero & size;
    final Paint scrim = Paint()..color = tourScrimColor;
    final Rect? cut = hole;
    if (cut == null || cut.isEmpty) {
      canvas.drawRect(window, scrim);
      return;
    }
    final RRect inner = RRect.fromRectAndRadius(cut, Radius.circular(radius));
    final RRect cream = inner.inflate(tourRingInnerWidth);
    final RRect coral = inner.inflate(tourRingInnerWidth + tourRingOuterWidth);
    canvas.save();
    canvas.clipRect(window);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(window),
        Path()..addRRect(inner),
      ),
      scrim,
    );
    canvas.drawDRRect(cream, inner, Paint()..color = innerRingColor);
    canvas.drawDRRect(coral, cream, Paint()..color = tourRingOuterColor);
    canvas.restore();
  }

  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(TourSpotlightPainter oldDelegate) =>
      oldDelegate.hole != hole ||
      oldDelegate.radius != radius ||
      oldDelegate.innerRingColor != innerRingColor;
}
