import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

double effectiveOpacity(WidgetTester tester, Finder finder) {
  final double faded = tester
      .widgetList<FadeTransition>(
        find.ancestor(of: finder, matching: find.byType(FadeTransition)),
      )
      .fold(1.0, (double sum, FadeTransition fade) => sum * fade.opacity.value);
  return tester
      .widgetList<Opacity>(
        find.ancestor(of: finder, matching: find.byType(Opacity)),
      )
      .fold(faded, (double sum, Opacity layer) => sum * layer.opacity);
}
