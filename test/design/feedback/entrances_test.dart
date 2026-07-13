import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/motion/motion.dart';

import 'harness.dart';

double _fade(WidgetTester tester) =>
    tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;

Offset _slide(WidgetTester tester) =>
    tester.widget<SlideTransition>(find.byType(SlideTransition)).position.value;

double _scale(WidgetTester tester) =>
    tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value;

void main() {
  group('ToastEntrance', () {
    testWidgets('rises and fades in, then settles at rest',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(
          const ToastEntrance(child: SizedBox(width: 40, height: 20)),
        ),
      );

      expect(_fade(tester), closeTo(0.0, 0.02));
      expect(_slide(tester).dy, greaterThan(0.0));

      await tester.pumpAndSettle();
      expect(_fade(tester), closeTo(1.0, 0.001));
      expect(_slide(tester), const Offset(0.0, 0.0));
    });
  });

  group('ModalEntrance', () {
    testWidgets('pops from a smaller scale and fades in',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(
          const ModalEntrance(child: SizedBox(width: 40, height: 40)),
        ),
      );

      expect(_scale(tester), lessThan(1.0));
      expect(_fade(tester), closeTo(0.0, 0.02));

      await tester.pumpAndSettle();
      expect(_scale(tester), closeTo(1.0, 0.001));
      expect(_fade(tester), closeTo(1.0, 0.001));
    });
  });

  group('SheetEntrance', () {
    testWidgets('slides up from below and settles at rest',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(
          const SheetEntrance(child: SizedBox(width: 40, height: 40)),
        ),
      );

      expect(_slide(tester).dy, closeTo(1.0, 0.02));

      await tester.pumpAndSettle();
      expect(_slide(tester), const Offset(0.0, 0.0));
    });

    testWidgets('rests immediately when animate is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(
          const SheetEntrance(
            animate: false,
            child: SizedBox(width: 40, height: 40),
          ),
        ),
      );

      expect(_slide(tester), const Offset(0.0, 0.0));
    });
  });
}
