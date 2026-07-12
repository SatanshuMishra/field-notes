import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/motion/motion.dart';

import 'harness.dart';

Finder _bars() => find.byWidgetPredicate(
      (Widget w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('wave-bar-'),
    );

void main() {
  group('WaveformBars', () {
    testWidgets('renders one bar per barCount', (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(const WaveformBars(barCount: 6)),
      );

      expect(_bars(), findsNWidgets(6));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('bobs a bar height over time', (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(const WaveformBars()),
      );

      final double first = tester
          .getSize(find.byKey(const ValueKey<String>('wave-bar-0')))
          .height;
      await tester.pump(const Duration(milliseconds: 175));
      final double later = tester
          .getSize(find.byKey(const ValueKey<String>('wave-bar-0')))
          .height;

      expect((later - first).abs(), greaterThan(0.1));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
