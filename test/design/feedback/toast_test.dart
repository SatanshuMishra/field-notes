import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import 'harness.dart';

Color? _surface(WidgetTester tester) {
  return tester.widget<StickerCard>(find.byType(StickerCard)).surface;
}

class _AnchoredBand extends StatelessWidget {
  const _AnchoredBand({
    required this.anchor,
    required this.height,
    this.published = true,
  });

  final GlobalKey anchor;
  final double height;
  final bool published;

  @override
  Widget build(BuildContext context) {
    final Widget band = Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Builder(
          builder: (BuildContext context) => GestureDetector(
            onTap: () => showTransientToast(context, 'Photo removed'),
            child: const Text('show'),
          ),
        ),
        SizedBox(key: anchor, height: height),
      ],
    );
    return published
        ? ToastClearance(anchors: <GlobalKey>[anchor], child: band)
        : band;
  }
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
      expect(_surface(tester), FieldNotesColors.light.cardBright);
    });

    testWidgets('honours a custom surface colour',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        feedbackHarness(
          Toast(message: 'Saved', surface: FieldNotesColors.light.cardWarm),
        ),
      );

      expect(_surface(tester), FieldNotesColors.light.cardWarm);
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

    testWidgets(
        'sits just above the keyboard without stacking the navigation inset '
        'on it', (WidgetTester tester) async {
      await showOnLandscapePhone(
        tester,
        surface: const Size(844, 320),
        statusBar: 24,
      );

      final Rect toast = tester.getRect(find.text('Could not add that photo'));
      expect(toast.bottom, lessThanOrEqualTo(320 - 200 - 16));
      expect(toast.top, greaterThanOrEqualTo(24));

      await tester.pump(kToastLifetime);
    });

    Future<void> showOn(
      WidgetTester tester, {
      required Size surface,
      TargetPlatform platform = TargetPlatform.android,
    }) async {
      tester.view.physicalSize = surface;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (BuildContext context) => GestureDetector(
              onTap: () => showTransientToast(context, 'Mood planted · Rose'),
              child: const Text('show'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('show'));
      await tester.pumpAndSettle();
    }

    double messageSize(WidgetTester tester) => tester
        .widget<Text>(find.text('Mood planted · Rose'))
        .style!
        .fontSize!;

    double glyphSize(WidgetTester tester) => tester
        .widget<IconStickerGlyphIcon>(find.byType(IconStickerGlyphIcon))
        .size;

    testWidgets('on macOS it floats 22 above the window bottom, desktop size',
        (WidgetTester tester) async {
      await showOn(
        tester,
        surface: const Size(1280, 800),
        platform: TargetPlatform.macOS,
      );

      final Rect toast = tester.getRect(find.byType(Toast));
      expect(toast.bottom, 800 - 22);
      expect(toast.center.dx, 640);
      expect(messageSize(tester), 13);
      expect(glyphSize(tester), 15);

      await tester.pump(kToastLifetime);
    });

    testWidgets('on a phone it floats 84 above the screen bottom, phone size',
        (WidgetTester tester) async {
      await showOn(tester, surface: const Size(390, 844));

      final Rect toast = tester.getRect(find.byType(Toast));
      expect(toast.bottom, 844 - 84);
      expect(toast.center.dx, 195);
      expect(messageSize(tester), 11);
      expect(glyphSize(tester), 13);

      await tester.pump(kToastLifetime);
    });

    Future<void> showAboveBand(
      WidgetTester tester,
      GlobalKey anchor, {
      required double band,
      double statusBar = 0,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(top: statusBar);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: _AnchoredBand(anchor: anchor, height: band),
        ),
      );
      await tester.tap(find.text('show'));
      await tester.pumpAndSettle();
    }

    testWidgets('inside a clearance it floats 16 above the anchored band', (
      WidgetTester tester,
    ) async {
      await showAboveBand(tester, GlobalKey(), band: 200);

      expect(tester.getRect(find.byType(Toast)).bottom, 844 - 200 - 16);

      await tester.pump(kToastLifetime);
    });

    testWidgets('inside a clearance its top stays below the status bar', (
      WidgetTester tester,
    ) async {
      await showAboveBand(tester, GlobalKey(), band: 790, statusBar: 24);

      expect(tester.getRect(find.byType(Toast)).top, 24);

      await tester.pump(kToastLifetime);
    });

    testWidgets('when its clearance goes away the toast drops back to 84', (
      WidgetTester tester,
    ) async {
      final GlobalKey anchor = GlobalKey();
      await showAboveBand(tester, anchor, band: 200);
      expect(tester.getRect(find.byType(Toast)).bottom, 844 - 200 - 16);

      await tester.pumpWidget(
        MaterialApp(
          home: _AnchoredBand(anchor: anchor, height: 200, published: false),
        ),
      );
      await tester.pump();

      expect(tester.getRect(find.byType(Toast)).bottom, 844 - 84);

      await tester.pump(kToastLifetime);
    });

    testWidgets('its message carries no fallback text decoration',
        (WidgetTester tester) async {
      await showOn(
        tester,
        surface: const Size(1280, 800),
        platform: TargetPlatform.macOS,
      );

      final TextStyle drawn = tester
          .widget<RichText>(
            find.descendant(
              of: find.byType(Toast),
              matching: find.byType(RichText),
            ),
          )
          .text
          .style!;
      expect(drawn.decoration, anyOf(isNull, TextDecoration.none));
      expect(
        drawn.fontFamily,
        FieldNotesTextStyles(FieldNotesColors.light).toastSans.fontFamily,
      );

      await tester.pump(kToastLifetime);
    });

    testWidgets('once risen it stays up for its whole lifetime, then goes',
        (WidgetTester tester) async {
      await showOn(tester, surface: const Size(390, 844));

      expect(find.text('Mood planted · Rose'), findsOneWidget);

      await tester.pump(kToastLifetime);
      await tester.pump();

      expect(find.text('Mood planted · Rose'), findsNothing);
    });

    testWidgets('a toast with an action keeps its action until it is pressed',
        (WidgetTester tester) async {
      int undos = 0;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => GestureDetector(
              onTap: () => showTransientToast(
                context,
                'Photo removed',
                action: ToastAction(
                  label: 'Undo',
                  onPressed: () => undos++,
                ),
              ),
              child: const Text('show'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('show'));
      await tester.pumpAndSettle();

      expect(find.text('Photo removed'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      await tester.pump(kToastLifetime);
      await tester.pump();

      expect(find.text('Undo'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();

      expect(undos, 1);
      expect(find.text('Photo removed'), findsNothing);
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

  group('showTransientToast after a trigger', () {
    const String deferred = 'Voice memo saved';
    const String newer = 'Mood planted · Rose';

    Widget app(Future<void> trigger) {
      return MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: Builder(
          builder: (BuildContext context) => Column(
            children: <Widget>[
              GestureDetector(
                onTap: () =>
                    showTransientToast(context, deferred, after: trigger),
                child: const Text('later'),
              ),
              GestureDetector(
                onTap: () => showTransientToast(context, newer),
                child: const Text('now'),
              ),
            ],
          ),
        ),
      );
    }

    Future<void> showDeferred(WidgetTester tester, Future<void> trigger) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(trigger));
      await tester.tap(find.text('later'));
      await tester.pump();
    }

    testWidgets('waits for its trigger, then floats in its usual place for its '
        'whole lifetime', (WidgetTester tester) async {
      final Completer<void> trigger = Completer<void>();
      await showDeferred(tester, trigger.future);

      expect(find.text(deferred), findsNothing);

      await tester.pump(kToastLifetime);

      expect(find.text(deferred), findsNothing);

      trigger.complete();
      await tester.pumpAndSettle();

      expect(find.text(deferred), findsOneWidget);
      expect(tester.getRect(find.byType(Toast)).bottom, 800 - 22);

      await tester.pump(kToastLifetime);
      await tester.pump();

      expect(find.text(deferred), findsNothing);
    });

    testWidgets('a newer toast before the trigger keeps it from appearing', (
      WidgetTester tester,
    ) async {
      final Completer<void> trigger = Completer<void>();
      await showDeferred(tester, trigger.future);
      await tester.tap(find.text('now'));
      await tester.pump();

      trigger.complete();
      await tester.pump();
      await tester.pump();

      expect(find.text(newer), findsOneWidget);
      expect(find.text(deferred), findsNothing);

      await tester.pump(kToastLifetime);
      await tester.pump();

      expect(find.text(newer), findsNothing);
      expect(find.text(deferred), findsNothing);
    });

    testWidgets('dismissing before the trigger keeps it from appearing', (
      WidgetTester tester,
    ) async {
      final Completer<void> trigger = Completer<void>();
      await showDeferred(tester, trigger.future);
      dismissTransientToast();

      trigger.complete();
      await tester.pump();
      await tester.pump();

      expect(find.text(deferred), findsNothing);
    });

    testWidgets('a trigger that fails still shows it', (
      WidgetTester tester,
    ) async {
      final Completer<void> trigger = Completer<void>();
      await showDeferred(tester, trigger.future);

      trigger.completeError(StateError('route failed'));
      await tester.pumpAndSettle();

      expect(find.text(deferred), findsOneWidget);

      await tester.pump(kToastLifetime);
      await tester.pump();

      expect(find.text(deferred), findsNothing);
    });

    testWidgets(
      'a trigger that lands after its overlay is gone shows nothing',
      (WidgetTester tester) async {
        final Completer<void> trigger = Completer<void>();
        await showDeferred(tester, trigger.future);
        await tester.pumpWidget(const SizedBox.shrink());

        trigger.complete();
        await tester.pump();

        await tester.pumpWidget(app(Completer<void>().future));
        await tester.tap(find.text('now'));
        await tester.pump();

        expect(find.text(newer), findsOneWidget);
        expect(find.text(deferred), findsNothing);

        await tester.pump(kToastLifetime);
      },
    );
  });
}
