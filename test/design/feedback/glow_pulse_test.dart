import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/motion/motion.dart';

import 'harness.dart';

double _haloOpacity(WidgetTester tester) {
  return tester
      .widget<Opacity>(
        find.descendant(
          of: find.byType(GlowPulse),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;
}

double _haloScale(WidgetTester tester) {
  return tester
      .widget<Transform>(
        find.descendant(
          of: find.byType(GlowPulse),
          matching: find.byType(Transform),
        ),
      )
      .transform
      .storage[0];
}

void main() {
  group('GlowPulse', () {
    testWidgets('renders its child', (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(
          const GlowPulse(child: Text('rec')),
        ),
      );

      expect(find.text('rec'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('scales the halo up and fades it out over half a period',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(
          const GlowPulse(child: SizedBox(width: 40, height: 40)),
        ),
      );

      final double startScale = _haloScale(tester);
      final double startOpacity = _haloOpacity(tester);
      await tester.pump(Motion.pulse ~/ 2);
      final double peakScale = _haloScale(tester);
      final double peakOpacity = _haloOpacity(tester);

      expect(startScale, closeTo(0.9, 0.01));
      expect(startOpacity, closeTo(0.5, 0.01));
      expect(peakScale, closeTo(1.25, 0.01));
      expect(peakOpacity, closeTo(0.18, 0.01));
      expect(peakScale, greaterThan(startScale));
      expect(peakOpacity, lessThan(startOpacity));

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
