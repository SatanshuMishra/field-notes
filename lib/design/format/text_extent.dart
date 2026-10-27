import 'dart:math' as math;

import 'package:flutter/widgets.dart';

double singleLineWidth(BuildContext context, String text, TextStyle style) {
  final TextPainter painter = _painterFor(context, text, style, maxLines: 1)
    ..layout();
  final double width = painter.width;
  painter.dispose();
  return width;
}

double wrappedHeight(
  BuildContext context,
  String text,
  TextStyle style, {
  required double maxWidth,
}) {
  final TextPainter painter = _painterFor(context, text, style)
    ..layout(maxWidth: math.max(0, maxWidth));
  final double height = painter.height;
  painter.dispose();
  return height;
}

TextPainter _painterFor(
  BuildContext context,
  String text,
  TextStyle style, {
  int? maxLines,
}) => TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: Directionality.of(context),
  textScaler: MediaQuery.textScalerOf(context),
  maxLines: maxLines,
);

double widestWordWidth(BuildContext context, String text, TextStyle style) {
  final TextStyle resolved = DefaultTextStyle.of(context).style.merge(style);
  return text
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .map((String word) => singleLineWidth(context, word, resolved))
      .fold<double>(0, math.max)
      .ceilToDouble();
}
