import 'package:flutter/widgets.dart';

Widget feedbackHarness(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Align(
        alignment: Alignment.topLeft,
        child: child,
      ),
    ),
  );
}
