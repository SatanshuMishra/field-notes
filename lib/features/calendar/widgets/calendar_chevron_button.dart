import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';

enum ChevronDirection { previous, next, down }

const double calendarChevronButtonSize = 34;

const double calendarMinTapTarget = 48;

class CalendarChevronButton extends StatelessWidget {
  const CalendarChevronButton({
    super.key,
    required this.direction,
    required this.onPressed,
    required this.semanticLabel,
    this.size = calendarChevronButtonSize,
    this.glyphSize = 15,
    this.alignment = Alignment.center,
  });

  final ChevronDirection direction;
  final VoidCallback onPressed;
  final String semanticLabel;
  final double size;
  final double glyphSize;
  final Alignment alignment;

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
          child: CalendarTapSlot(
            alignment: alignment,
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

class CalendarTapSlot extends SingleChildRenderObjectWidget {
  const CalendarTapSlot({
    super.key,
    this.alignment = Alignment.center,
    this.margin = EdgeInsets.zero,
    super.child,
  });

  final Alignment alignment;
  final EdgeInsets margin;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCalendarTapSlot(alignment: alignment, margin: margin);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderCalendarTapSlot)
      ..alignment = alignment
      ..margin = margin;
  }
}

class _RenderCalendarTapSlot extends RenderShiftedBox {
  _RenderCalendarTapSlot({
    required this._alignment,
    required this._margin,
  }) : super(null);

  Alignment _alignment;
  EdgeInsets _margin;

  set alignment(Alignment value) {
    if (value == _alignment) {
      return;
    }
    _alignment = value;
    markNeedsLayout();
  }

  set margin(EdgeInsets value) {
    if (value == _margin) {
      return;
    }
    _margin = value;
    markNeedsLayout();
  }

  Rect _slotAround(Size child) {
    final Size area = Size(
      math.max(child.width, calendarMinTapTarget),
      math.max(child.height, calendarMinTapTarget),
    );
    final Offset inArea = _alignment.alongOffset(
      Offset(area.width - child.width, area.height - child.height),
    );
    return (-inArea & area).expandToInclude(
      _margin.inflateRect(Offset.zero & child),
    );
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.deflate(_margin);

  double _innerExtent(double extent, double margin) =>
      math.max(0.0, extent - margin);

  @override
  double computeMinIntrinsicWidth(double height) => _slotAround(
    Size(
      child?.getMinIntrinsicWidth(_innerExtent(height, _margin.vertical)) ?? 0,
      0,
    ),
  ).width;

  @override
  double computeMaxIntrinsicWidth(double height) => _slotAround(
    Size(
      child?.getMaxIntrinsicWidth(_innerExtent(height, _margin.vertical)) ?? 0,
      0,
    ),
  ).width;

  @override
  double computeMinIntrinsicHeight(double width) => _slotAround(
    Size(
      0,
      child?.getMinIntrinsicHeight(_innerExtent(width, _margin.horizontal)) ??
          0,
    ),
  ).height;

  @override
  double computeMaxIntrinsicHeight(double width) => _slotAround(
    Size(
      0,
      child?.getMaxIntrinsicHeight(_innerExtent(width, _margin.horizontal)) ??
          0,
    ),
  ).height;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.constrain(
        _slotAround(
          child?.getDryLayout(_childConstraints(constraints)) ?? Size.zero,
        ).size,
      );

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child == null) {
      size = constraints.constrain(_slotAround(Size.zero).size);
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    final Rect slot = _slotAround(child.size);
    size = constraints.constrain(slot.size);
    final Offset spare = _alignment.alongOffset(
      Offset(size.width - slot.width, size.height - slot.height),
    );
    (child.parentData! as BoxParentData).offset = spare - slot.topLeft;
  }
}

class CalendarTapArea extends SingleChildRenderObjectWidget {
  const CalendarTapArea({super.key, required this.reach, super.child});

  final EdgeInsets reach;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCalendarTapArea(reach: reach);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderCalendarTapArea).reach = reach;
  }
}

class _RenderCalendarTapArea extends RenderProxyBox {
  _RenderCalendarTapArea({required this._reach});

  EdgeInsets _reach;

  set reach(EdgeInsets value) {
    if (value == _reach) {
      return;
    }
    _reach = value;
    markNeedsSemanticsUpdate();
  }

  Rect get _area {
    final (double left, double right) = _grow(
      size.width,
      _reach.left,
      _reach.right,
    );
    final (double top, double bottom) = _grow(
      size.height,
      _reach.top,
      _reach.bottom,
    );
    return Rect.fromLTRB(
      -left,
      -top,
      size.width + right,
      size.height + bottom,
    );
  }

  static (double, double) _grow(double extent, double before, double after) {
    final double deficit = math.max(0.0, calendarMinTapTarget - extent);
    final double lead = math.min(
      before,
      math.max(deficit / 2, deficit - after),
    );
    return (lead, math.min(after, deficit - lead));
  }

  @override
  Rect get semanticBounds => _area;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.contains(position)) {
      return super.hitTest(result, position: position);
    }
    if (!_area.contains(position)) {
      return false;
    }
    final Offset center = size.center(Offset.zero);
    return result.addWithRawTransform(
      transform: MatrixUtils.forceToPoint(center),
      position: center,
      hitTest: (BoxHitTestResult result, Offset position) =>
          super.hitTest(result, position: position),
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
