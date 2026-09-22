import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
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

  group('showTransientToast', () {
    Future<void> showOnLandscapePhone(
      WidgetTester tester, {
      IconStickerGlyph? glyph,
      Size surface = const Size(844, 390),
      double keyboard = 200,
      double statusBar = 0,
    }) async {
      tester.view.physicalSize = surface;
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      tester.view.padding = FakeViewPadding(top: statusBar);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => GestureDetector(
              onTap: () => glyph == null
                  ? showTransientToast(context, 'Could not add that photo')
                  : showTransientToast(
                      context,
                      'Could not add that photo',
                      glyph: glyph,
                    ),
              child: const Text('show'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('rises above the keyboard', (WidgetTester tester) async {
      await showOnLandscapePhone(tester);

      expect(
        tester.getRect(find.text('Could not add that photo')).bottom,
        lessThanOrEqualTo(390 - 200),
      );

      await tester.pump(kToastLifetime);
    });

    testWidgets('stays below the status bar when the keyboard leaves little room',
        (WidgetTester tester) async {
      await showOnLandscapePhone(
        tester,
        surface: const Size(844, 320),
        statusBar: 24,
      );

      final Rect toast = tester.getRect(find.text('Could not add that photo'));
      expect(toast.top, greaterThanOrEqualTo(24));
      expect(toast.bottom, lessThanOrEqualTo(320 - 200));

      await tester.pump(kToastLifetime);
    });

    testWidgets('an error toast carries a close glyph instead of a check',
        (WidgetTester tester) async {
      await showOnLandscapePhone(tester, glyph: IconStickerGlyph.close);

      expect(
        tester
            .widget<IconStickerGlyphIcon>(find.byType(IconStickerGlyphIcon))
            .glyph,
        IconStickerGlyph.close,
      );

      await tester.pump(kToastLifetime);
    });
  });
}
