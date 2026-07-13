import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/motion/motion.dart';

import 'harness.dart';

double _glowAlpha(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(GlowPulse),
      matching: find.byType(DecoratedBox),
    ),
  );
  final BoxDecoration deco = box.decoration as BoxDecoration;
  return deco.boxShadow!.first.color.a;
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

    testWidgets('brightens the glow over one period',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(
          const GlowPulse(child: SizedBox(width: 40, height: 40)),
        ),
      );

      final double start = _glowAlpha(tester);
      await tester.pump(Motion.pulse);
      final double peak = _glowAlpha(tester);

      expect(peak, greaterThan(start));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
