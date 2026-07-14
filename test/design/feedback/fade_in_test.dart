import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/motion/motion.dart';

import 'harness.dart';

double _fadeOpacity(WidgetTester tester) {
  return tester
      .widget<FadeTransition>(find.byType(FadeTransition))
      .opacity
      .value;
}

void main() {
  group('FadeIn', () {
    testWidgets('animates from transparent to opaque and settles',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(
          const FadeIn(child: SizedBox(width: 20, height: 20)),
        ),
      );

      expect(_fadeOpacity(tester), closeTo(0.0, 0.02));

      await tester.pumpAndSettle();
      expect(_fadeOpacity(tester), closeTo(1.0, 0.001));
    });

    testWidgets('is opaque immediately when animate is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(
          const FadeIn(
            animate: false,
            child: SizedBox(width: 20, height: 20),
          ),
        ),
      );

      expect(_fadeOpacity(tester), closeTo(1.0, 0.001));
    });
  });
}
