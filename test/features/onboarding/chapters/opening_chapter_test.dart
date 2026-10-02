import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/settings/week_start.dart';
import 'package:field_notes/features/onboarding/chapters/opening_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/features/onboarding/onboarding_frame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../app/support/app_shell_harness.dart';

const Size _sidebarArea = Size(1280, 758);
const Size _bottomBarArea = Size(360, 740);

const String _kicker = 'field notes';
const String _title = "Most days won't feel like a story.";
const String _subtitle =
    "Write them down anyway. Each one becomes a flower, and they're yours "
    'to keep.';
const String _plantLabel = 'Plant your first seed';
const String _clickHint = 'click anywhere to plant your first seed';
const String _tapHint = 'tap anywhere to plant your first seed';
const String _enterHint = 'or press Enter';

const OnboardingFlowRunning _opening = OnboardingFlowRunning(
  chapter: OnboardingChapter.opening,
  draft: OnboardingDraft(
    entryDate: '2026-10-01',
    regionWeek: WeekStart.sunday,
    week: WeekStart.sunday,
  ),
);

Future<void> _onLayout(ShellLayout layout, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = switch (layout) {
    ShellLayout.sidebar => TargetPlatform.macOS,
    ShellLayout.bottomBar => TargetPlatform.android,
  };
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _pumpOpening(
  WidgetTester tester,
  ShellLayout layout, {
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = switch (layout) {
    ShellLayout.sidebar => _sidebarArea,
    ShellLayout.bottomBar => _bottomBarArea,
  };
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        ...shellOverrides(),
        onboardingControllerProvider.overrideWithBuild(
          (Ref ref, OnboardingController controller) => _opening,
        ),
      ],
      child: MaterialApp(
        theme: fieldNotesTheme(platform: defaultTargetPlatform),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Material(child: OnboardingFrame(layout: layout)),
      ),
    ),
  );
  await tester.pump();
}

OnboardingDraft _draft(WidgetTester tester) => (ProviderScope.containerOf(
  tester.element(find.byType(OpeningChapter)),
).read(onboardingControllerProvider) as OnboardingFlowRunning).draft;

double _shown(WidgetTester tester, String text) => tester
    .widgetList<Opacity>(
      find.ancestor(of: find.text(text), matching: find.byType(Opacity)),
    )
    .fold<double>(
      1,
      (double shown, Opacity opacity) => shown * opacity.opacity,
    );

void _expectHeading(WidgetTester tester, {required double shown}) {
  for (final String text in <String>[_kicker, _title, _subtitle]) {
    expect(find.text(text), findsOneWidget);
    expect(_shown(tester, text), shown, reason: text);
  }
}

void _expectUnplanted(WidgetTester tester, ShellLayout layout) {
  final bool sidebar = layout == ShellLayout.sidebar;
  expect(find.text(_clickHint), sidebar ? findsOneWidget : findsNothing);
  expect(find.text(_enterHint), sidebar ? findsOneWidget : findsNothing);
  expect(find.text(_tapHint), sidebar ? findsNothing : findsOneWidget);
  expect(find.bySemanticsLabel(_plantLabel), findsOneWidget);
  expect(find.bySemanticsLabel(_title), findsNothing);
  _expectHeading(tester, shown: 0);
  expect(_draft(tester).planted, isFalse);
  expect(_draft(tester).grown, isFalse);
}

Future<void> _expectGrowth(WidgetTester tester) async {
  await tester.pump();
  final OnboardingDraft planted = _draft(tester);
  expect(planted.planted, isTrue);
  expect(planted.grown, isFalse);
  expect(find.bySemanticsLabel(_plantLabel), findsNothing);
  expect(find.bySemanticsLabel(_title), findsOneWidget);
  expect(find.bySemanticsLabel(_subtitle), findsOneWidget);

  await tester.pump(const Duration(seconds: 1));
  expect(find.text(_clickHint), findsNothing);
  expect(find.text(_tapHint), findsNothing);
  expect(find.text(_enterHint), findsNothing);
  _expectHeading(tester, shown: 0);

  await tester.tap(find.byType(OpeningChapter));
  await tester.pump();
  expect(_draft(tester), planted);

  await tester.pump(const Duration(milliseconds: 2400));
  expect(_draft(tester).grown, isFalse);
  expect(_shown(tester, _title), greaterThan(0));

  await tester.pump(const Duration(milliseconds: 200));
  expect(_draft(tester).grown, isTrue);
  _expectHeading(tester, shown: 1);
  expect(
    find.descendant(
      of: find.byKey(onboardingPrimaryKey),
      matching: find.text('Begin'),
    ),
    findsOneWidget,
  );

  final OnboardingDraft grown = _draft(tester);
  await tester.tap(find.byType(OpeningChapter));
  await tester.pump(const Duration(seconds: 4));
  expect(_draft(tester), grown);
  _expectHeading(tester, shown: 1);
}

void main() {
  testWidgets('the opening plants on a tap or Enter and grows the peony', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        await _pumpOpening(tester, layout);
        await tester.pump(const Duration(seconds: 2));
        _expectUnplanted(tester, layout);

        await tester.tap(find.byType(OpeningChapter));
        await _expectGrowth(tester);
      });
    }

    await _onLayout(ShellLayout.sidebar, () async {
      await _pumpOpening(tester, ShellLayout.sidebar);
      await tester.pump(const Duration(seconds: 2));
      _expectUnplanted(tester, ShellLayout.sidebar);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _expectGrowth(tester);
    });

    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        await _pumpOpening(tester, layout, reduceMotion: true);
        _expectUnplanted(tester, layout);

        await tester.tap(find.byType(OpeningChapter));
        await tester.pump();

        expect(_draft(tester).planted, isTrue);
        expect(_draft(tester).grown, isTrue);
        _expectHeading(tester, shown: 1);
        expect(find.bySemanticsLabel(_title), findsOneWidget);
        expect(find.bySemanticsLabel(_plantLabel), findsNothing);
        expect(find.text(_clickHint), findsNothing);
        expect(find.text(_tapHint), findsNothing);
        expect(tester.hasRunningAnimations, isFalse);
      });
    }
  });
}
