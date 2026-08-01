import 'package:flutter/painting.dart';

sealed class BloomPart {
  const BloomPart({
    this.fill,
    this.strokeColor,
    this.strokeWidth,
    this.strokeCap = StrokeCap.round,
    this.strokeJoin = StrokeJoin.round,
  });

  final Color? fill;
  final Color? strokeColor;
  final double? strokeWidth;
  final StrokeCap strokeCap;
  final StrokeJoin strokeJoin;
}

final class BloomDisc extends BloomPart {
  const BloomDisc({
    required this.cx,
    required this.cy,
    required this.r,
    super.fill,
    super.strokeColor,
    super.strokeWidth,
    super.strokeCap,
    super.strokeJoin,
  });

  final double cx;
  final double cy;
  final double r;
}

final class BloomOval extends BloomPart {
  const BloomOval({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    this.rotationDeg = 0,
    this.pivotX = 0,
    this.pivotY = 0,
    super.fill,
    super.strokeColor,
    super.strokeWidth,
    super.strokeCap,
    super.strokeJoin,
  });

  final double cx;
  final double cy;
  final double rx;
  final double ry;
  final double rotationDeg;
  final double pivotX;
  final double pivotY;
}

final class BloomOvalRing extends BloomPart {
  const BloomOvalRing({
    required this.count,
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.stepDeg,
    required this.pivotX,
    required this.pivotY,
    this.startDeg = 0,
    super.fill,
    super.strokeColor,
    super.strokeWidth,
    super.strokeCap,
    super.strokeJoin,
  });

  final int count;
  final double cx;
  final double cy;
  final double rx;
  final double ry;
  final double startDeg;
  final double stepDeg;
  final double pivotX;
  final double pivotY;
}

final class BloomShape extends BloomPart {
  const BloomShape({
    required this.commands,
    this.close = false,
    super.fill,
    super.strokeColor,
    super.strokeWidth,
    super.strokeCap,
    super.strokeJoin,
  });

  final List<BloomCmd> commands;
  final bool close;
}

sealed class BloomCmd {
  const BloomCmd();
}

final class BloomMoveTo extends BloomCmd {
  const BloomMoveTo(this.x, this.y);

  final double x;
  final double y;
}

final class BloomLineTo extends BloomCmd {
  const BloomLineTo(this.x, this.y);

  final double x;
  final double y;
}

final class BloomQuadTo extends BloomCmd {
  const BloomQuadTo(this.cx, this.cy, this.x, this.y);

  final double cx;
  final double cy;
  final double x;
  final double y;
}

final class BloomCubicTo extends BloomCmd {
  const BloomCubicTo(this.c1x, this.c1y, this.c2x, this.c2y, this.x, this.y);

  final double c1x;
  final double c1y;
  final double c2x;
  final double c2y;
  final double x;
  final double y;
}

final class BloomArcTo extends BloomCmd {
  const BloomArcTo({
    required this.rx,
    required this.ry,
    required this.largeArc,
    required this.clockwise,
    required this.x,
    required this.y,
  });

  final double rx;
  final double ry;
  final bool largeArc;
  final bool clockwise;
  final double x;
  final double y;
}
