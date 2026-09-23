import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';

enum ChevronDirection { previous, next, down }

const double calendarChevronButtonSize = 34;

class CalendarChevronButton extends StatelessWidget {
  const CalendarChevronButton({
    super.key,
    required this.direction,
    required this.onPressed,
    required this.semanticLabel,
    this.size = calendarChevronButtonSize,
    this.glyphSize = 15,
  });

  final ChevronDirection direction;
  final VoidCallback onPressed;
  final String semanticLabel;
  final double size;
  final double glyphSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Palette.cardWarm,
              border: Shapes.outline,
              borderRadius: BorderRadius.all(
                Radius.circular(Shapes.radiusCell),
              ),
              boxShadow: Shadows.chip,
            ),
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: CalendarChevronGlyph(
                  direction: direction,
                  size: glyphSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CalendarChevronGlyph extends StatelessWidget {
  const CalendarChevronGlyph({
    super.key,
    required this.direction,
    required this.size,
    this.color = Palette.ink,
  });

  final ChevronDirection direction;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ChevronPainter(direction: direction, color: color),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({required this.direction, required this.color});

  final ChevronDirection direction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double arm = size.shortestSide * 0.33;
    final double half = arm / 2;
    final Path path = switch (direction) {
      ChevronDirection.previous => Path()
        ..moveTo(cx + half, cy - arm)
        ..lineTo(cx - half, cy)
        ..lineTo(cx + half, cy + arm),
      ChevronDirection.next => Path()
        ..moveTo(cx - half, cy - arm)
        ..lineTo(cx + half, cy)
        ..lineTo(cx - half, cy + arm),
      ChevronDirection.down => Path()
        ..moveTo(cx - arm, cy - half)
        ..lineTo(cx, cy + half)
        ..lineTo(cx + arm, cy - half),
    };
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) =>
      oldDelegate.direction != direction || oldDelegate.color != color;
}
