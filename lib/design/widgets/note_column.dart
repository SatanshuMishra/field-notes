import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

class NoteColumn extends StatelessWidget {
  const NoteColumn({super.key, required this.child, this.horizontalInset = 0});

  static const double measureEm = 35;

  final Widget child;
  final double horizontalInset;

  static double emOf(BuildContext context) {
    return MediaQuery.textScalerOf(
      context,
    ).scale(TypographyTokens.noteBody.fontSize!);
  }

  static double measureOf(BuildContext context) => measureEm * emOf(context);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = math.min(
          constraints.maxWidth,
          measureOf(context) + horizontalInset,
        );
        return Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: SizedBox(width: width, child: child),
        );
      },
    );
  }
}
