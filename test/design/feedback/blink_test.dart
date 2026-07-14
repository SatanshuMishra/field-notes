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
  group('Blink', () {
    testWidgets('starts fully opaque and dims toward minOpacity over a period',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(
          const Blink(
            minOpacity: 0.2,
            child: SizedBox(width: 12, height: 12),
          ),
        ),
      );

      expect(_fadeOpacity(tester), closeTo(1.0, 0.001));

      await tester.pump(Motion.blink);
      expect(_fadeOpacity(tester), closeTo(0.2, 0.02));

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('stays fully opaque when animate is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(
          const Blink(
            animate: false,
            child: SizedBox(width: 12, height: 12),
          ),
        ),
      );

      expect(_fadeOpacity(tester), closeTo(1.0, 0.001));
      await tester.pump(Motion.blink);
      expect(_fadeOpacity(tester), closeTo(1.0, 0.001));
    });
  });
}
