import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';

enum ChevronDirection { previous, next }

class CalendarChevronButton extends StatelessWidget {
  const CalendarChevronButton({
    super.key,
    required this.direction,
    required this.onPressed,
    required this.semanticLabel,
  });

  final ChevronDirection direction;
  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Palette.cardBright,
            border: Shapes.outline,
            borderRadius: Shapes.buttonBorderRadius,
            boxShadow: Shadows.button,
          ),
          child: SizedBox(
            width: 40,
            height: 40,
            child: CustomPaint(
              painter: _ChevronPainter(direction: direction),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({required this.direction});

  final ChevronDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    const double arm = 5;
    final Path path = Path();
    if (direction == ChevronDirection.previous) {
      path.moveTo(cx + arm / 2, cy - arm);
      path.lineTo(cx - arm / 2, cy);
      path.lineTo(cx + arm / 2, cy + arm);
    } else {
      path.moveTo(cx - arm / 2, cy - arm);
      path.lineTo(cx + arm / 2, cy);
      path.lineTo(cx - arm / 2, cy + arm);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) =>
      oldDelegate.direction != direction;
}
