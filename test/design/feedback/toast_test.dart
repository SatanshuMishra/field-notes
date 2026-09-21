import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import 'harness.dart';

Color _surface(WidgetTester tester) {
  return tester.widget<StickerCard>(find.byType(StickerCard)).surface;
}

void main() {
  group('Toast', () {
    testWidgets('renders its message on a sticker surface',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(const Toast(message: 'Recording paused')),
      );

      expect(find.text('Recording paused'), findsOneWidget);
      expect(find.byType(StickerCard), findsOneWidget);
      expect(_surface(tester), Palette.cardBright);
    });

    testWidgets('honours a custom surface colour',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(
          const Toast(message: 'Saved', surface: Palette.cardWarm),
        ),
      );

      expect(_surface(tester), Palette.cardWarm);
    });

    testWidgets('carries a trailing action beside the message',
        (WidgetTester tester) async {
      int undos = 0;
      await tester.pumpWidget(
        feedbackHarness(
          Toast(
            message: 'Photo removed',
            action: ToastAction(label: 'Undo', onPressed: () => undos++),
          ),
        ),
      );

      expect(find.text('Photo removed'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Undo')).dx,
        greaterThan(tester.getTopRight(find.text('Photo removed')).dx),
      );

      await tester.tap(find.text('Undo'));
      expect(undos, 1);
    });

    testWidgets('the action is a 48dp target announced as a button',
        (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        feedbackHarness(
          Toast(
            message: 'Photo removed',
            action: ToastAction(label: 'Undo', onPressed: () {}),
          ),
        ),
      );

      final Finder target = find.ancestor(
        of: find.text('Undo'),
        matching: find.byType(GestureDetector),
      );
      expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(target),
        isSemantics(label: 'Undo', isButton: true),
      );
      semantics.dispose();
    });

    testWidgets('without an action it renders no action target',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(const Toast(message: 'Saved')),
      );

      expect(find.byType(GestureDetector), findsNothing);
    });
  });
}
