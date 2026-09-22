import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

class NoteColumn extends StatelessWidget {
  const NoteColumn({
    super.key,
    required this.child,
    this.horizontalInset = 0,
    this.maxEm = measureEm,
  });

  static const double measureEm = 35;

  final Widget child;
  final double horizontalInset;
  final double maxEm;

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
        final double width =
            NoteMeasureScope.fillsWidthOf(context) && constraints.hasBoundedWidth
                ? constraints.maxWidth
                : math.min(
                    constraints.maxWidth,
                    maxEm * emOf(context) + horizontalInset,
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

class NoteMeasureScope extends InheritedWidget {
  const NoteMeasureScope({
    super.key,
    required this.fillsWidth,
    required super.child,
  });

  final bool fillsWidth;

  static bool fillsWidthOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NoteMeasureScope>()
          ?.fillsWidth ??
      false;

  @override
  bool updateShouldNotify(NoteMeasureScope oldWidget) =>
      fillsWidth != oldWidget.fillsWidth;
}
