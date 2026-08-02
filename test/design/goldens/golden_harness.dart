import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/widget_harness.dart';

const Size _goldenPhysicalSize = Size(800, 600);
const double _goldenDevicePixelRatio = 1.0;

void pinGoldenSurface(WidgetTester tester) {
  tester.view.physicalSize = _goldenPhysicalSize;
  tester.view.devicePixelRatio = _goldenDevicePixelRatio;
  addTearDown(tester.view.reset);
}

Widget goldenHarness(Widget subject, {EdgeInsets padding = EdgeInsets.zero}) {
  return stickerHarness(
    RepaintBoundary(
      child: Padding(padding: padding, child: subject),
    ),
  );
}
