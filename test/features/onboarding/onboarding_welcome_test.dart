import 'dart:ui' as ui;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/onboarding/onboarding_surface.dart';
import 'package:field_notes/features/onboarding/welcome/onboarding_welcome.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _desktop = Size(1280, 800);
const Size _phone = Size(360, 740);

const String _begin = 'Let’s begin';
const String _skip = 'Skip how it works';

Future<void> _onLayout(ShellLayout layout, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = layout == ShellLayout.sidebar
      ? TargetPlatform.macOS
      : TargetPlatform.android;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<List<String>> _pumpWelcome(
  WidgetTester tester,
  ShellLayout layout,
) async {
  final bool sidebar = layout == ShellLayout.sidebar;
  tester.view.physicalSize = sidebar ? _desktop : _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final List<String> calls = <String>[];
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(
        platform: sidebar ? TargetPlatform.macOS : TargetPlatform.android,
      ),
      home: Scaffold(
        backgroundColor: FieldNotesColors.light.page,
        body: OnboardingWelcome(
          layout: layout,
          onBegin: () => calls.add('begin'),
          onSkip: () => calls.add('skip'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

Size _faceSize(WidgetTester tester, String label) => tester.getSize(
  find
      .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
      .first,
);

String _focusedLabel() {
  String label = '';
  FocusManager.instance.primaryFocus?.context?.visitAncestorElements((
    Element element,
  ) {
    final Widget widget = element.widget;
    if (widget is Semantics && (widget.properties.label ?? '').isNotEmpty) {
      label = widget.properties.label!;
      return false;
    }
    return true;
  });
  return label;
}

void main() {
  testWidgets('the welcome shows its copy and part cards', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        final bool sidebar = layout == ShellLayout.sidebar;
        await _pumpWelcome(tester, layout);

        expect(
          tester.widget<FlowerBloom>(find.byType(FlowerBloom)).kind,
          Mood.happy.flower,
        );
        expect(find.text('field notes'), findsOneWidget);
        final TextStyle wordmark = _styleOf(tester, 'field notes');
        expect(wordmark.fontFamily, TypographyTokens.accent);
        expect(wordmark.fontWeight, FontWeight.w700);
        expect(wordmark.fontSize, 26);
        expect(wordmark.color, FieldNotesColors.light.accentInk);

        final TextStyle headline = _styleOf(tester, 'A journal of days.');
        expect(headline.fontFamily, TypographyTokens.serif);
        expect(headline.fontWeight, FontWeight.w500);
        expect(headline.fontSize, sidebar ? 34 : 28);
        expect(
          find.text('Write, speak or film a moment. Each day grows a bloom.'),
          findsOneWidget,
        );

        for (final String text in <String>[
          '1',
          'How it works',
          '6 quick tips · about a minute',
          '2',
          'Basic setup',
          'Reminder · week · storage',
          _begin,
          _skip,
        ]) {
          expect(find.text(text), findsOneWidget, reason: text);
        }

        final Rect first = tester.getRect(find.text('How it works'));
        final Rect second = tester.getRect(find.text('Basic setup'));
        if (sidebar) {
          expect(second.top, moreOrLessEquals(first.top));
          expect(second.left, greaterThan(first.right));
        } else {
          expect(second.left, moreOrLessEquals(first.left));
          expect(second.top, greaterThan(first.bottom));
        }

        final Size begin = _faceSize(tester, _begin);
        expect(begin.height, sidebar ? 46 : 48);
        expect(begin.width, sidebar ? 520 - 4 - 72 : 360 - 40);
        expect(
          tester.getRect(find.text(_skip)).top,
          greaterThan(tester.getRect(find.text(_begin)).bottom),
        );
      });
    }
  });

  testWidgets("Let's begin and Skip how it works call their callbacks", (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        final List<String> calls = await _pumpWelcome(tester, layout);

        await tester.tap(find.text(_begin));
        await tester.pumpAndSettle();
        expect(calls, <String>['begin'], reason: layout.name);

        await tester.tap(find.text(_skip));
        await tester.pumpAndSettle();
        expect(calls, <String>['begin', 'skip'], reason: layout.name);
      });
    }
  });

  testWidgets(
    'the sidebar welcome is a 520-wide card over a blurred scrim and the '
    'bottom-bar welcome is full screen',
    (WidgetTester tester) async {
      await _onLayout(ShellLayout.sidebar, () async {
        await _pumpWelcome(tester, ShellLayout.sidebar);

        final Finder card = find.byKey(onboardingCardKey);
        expect(tester.getSize(card).width, 520);
        expect(tester.getCenter(card), const Offset(640, 400));
        final BoxDecoration cardDecoration =
            tester.widget<Container>(card).decoration! as BoxDecoration;
        expect(cardDecoration.color, FieldNotesColors.light.composerPaper);
        expect(
          cardDecoration.border,
          Border.all(color: FieldNotesColors.light.line, width: 2),
        );
        expect(cardDecoration.borderRadius, BorderRadius.circular(22));
        expect(
          cardDecoration.boxShadow!.first,
          const BoxShadow(color: Color(0x594A3B2E), offset: Offset(5, 5)),
        );
        expect(cardDecoration.boxShadow, hasLength(2));

        final Finder scrim = find.byType(BackdropFilter);
        expect(scrim, findsOneWidget);
        expect(
          tester.widget<BackdropFilter>(scrim).filter,
          ui.ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
        );
        expect(tester.getRect(scrim), Offset.zero & _desktop);
        final BoxDecoration scrimDecoration =
            tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: scrim,
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        expect(
          scrimDecoration.gradient,
          const RadialGradient(
            center: Alignment(0, -0.36),
            radius: 1.2,
            colors: <Color>[Color(0x5C2A2016), Color(0x9E1C140C)],
          ),
        );
        expect(find.byKey(onboardingPageKey), findsNothing);
      });

      await _onLayout(ShellLayout.bottomBar, () async {
        await _pumpWelcome(tester, ShellLayout.bottomBar);

        expect(find.byType(BackdropFilter), findsNothing);
        expect(find.byKey(onboardingCardKey), findsNothing);
        final Finder page = find.byKey(onboardingPageKey);
        expect(tester.getRect(page), Offset.zero & _phone);
        final BoxDecoration pageDecoration =
            tester.widget<DecoratedBox>(page).decoration as BoxDecoration;
        expect(
          (pageDecoration.gradient! as LinearGradient).colors,
          const <Color>[Color(0xFFF3E7D4), Color(0xFFECDFC8)],
        );
        expect(
          tester.getRect(find.text(_skip)).bottom,
          lessThanOrEqualTo(_phone.height),
        );
      });
    },
  );

  testWidgets('Enter and Right arrow begin and Esc skips how it works', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        final List<String> calls = await _pumpWelcome(tester, layout);
        expect(_focusedLabel(), _begin, reason: layout.name);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(calls, <String>['begin'], reason: layout.name);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(calls, <String>['begin', 'begin'], reason: layout.name);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(calls, <String>['begin', 'begin', 'skip'], reason: layout.name);
      });
    }
  });
}
