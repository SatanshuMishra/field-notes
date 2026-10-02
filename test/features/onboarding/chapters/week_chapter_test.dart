import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/settings/week_start.dart';
import 'package:field_notes/features/onboarding/chapters/week_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../app/support/app_shell_harness.dart';
import '../../settings/support/fake_settings_repository.dart';

const String _regionDefault = "Your region's default";
const String _privacy = 'Your stories stay private, on this device.';

const Size _sidebarArea = Size(1280, 758);
const Size _bottomBarArea = Size(360, 740);

const List<int> _week = <int>[
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
  DateTime.sunday,
];

const Map<WeekStart, String> _usedIn = <WeekStart, String>{
  WeekStart.monday: 'Most of Europe',
  WeekStart.sunday: 'US, Canada, Japan',
  WeekStart.saturday: 'Parts of the Middle East',
};

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

Future<FakeSettingsRepository> _pumpWeek(
  WidgetTester tester,
  ShellLayout layout, {
  required String country,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = switch (layout) {
    ShellLayout.sidebar => _sidebarArea,
    ShellLayout.bottomBar => _bottomBarArea,
  };
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final FakeSettingsRepository settings = FakeSettingsRepository();
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        for (final Override override in shellOverrides())
          if (override.origin != settingsRepositoryProvider) override,
        settingsRepositoryProvider.overrideWithValue(settings),
        onboardingCountryCodeProvider.overrideWithValue(country),
      ],
      child: MaterialApp(
        theme: fieldNotesTheme(platform: defaultTargetPlatform),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Material(child: WeekChapter(layout: layout)),
      ),
    ),
  );
  _container(tester).read(onboardingControllerProvider.notifier).start();
  await tester.pump();
  return settings;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(WeekChapter)));

OnboardingDraft? _draft(WidgetTester tester) =>
    switch (_container(tester).read(onboardingControllerProvider)) {
      OnboardingFlowRunning(:final OnboardingDraft draft) => draft,
      OnboardingFlowHidden() || OnboardingFlowMap() => null,
    };

double _left(WidgetTester tester, int weekday) =>
    tester.getTopLeft(find.byKey(weekDayKey(weekday))).dx -
    tester.getTopLeft(find.byKey(weekStripKey)).dx;

List<int> _stripOrder(WidgetTester tester) =>
    _week.toList()
      ..sort((int a, int b) => _left(tester, a).compareTo(_left(tester, b)));

String _letterOf(WidgetTester tester, int weekday) => tester
    .widget<Text>(
      find
          .descendant(
            of: find.byKey(weekDayKey(weekday)),
            matching: find.byType(Text),
          )
          .first,
    )
    .data!;

List<String> _stripLetters(WidgetTester tester) => <String>[
  for (final int weekday in _stripOrder(tester)) _letterOf(tester, weekday),
];

BoxDecoration _cardFace(WidgetTester tester, int weekday) =>
    tester
            .widget<AnimatedContainer>(
              find.descendant(
                of: find.byKey(weekDayKey(weekday)),
                matching: find.byType(AnimatedContainer),
              ),
            )
            .decoration!
        as BoxDecoration;

FieldNotesColors _colors(WidgetTester tester) =>
    FieldNotesColors.of(tester.element(find.byType(WeekChapter)));

void _expectFirstRinged(WidgetTester tester, int first) {
  final FieldNotesColors colors = _colors(tester);
  for (final int weekday in _week) {
    final BoxDecoration face = _cardFace(tester, weekday);
    final Border border = face.border! as Border;
    if (weekday == first) {
      expect(face.color, colors.cardLight);
      expect(border.top.color, Palette.coral);
    } else {
      expect(face.color, colors.cardWarm);
      expect(border.top.color, isNot(Palette.coral));
    }
  }
}

List<WeekStart> _choiceOrder(WidgetTester tester, ShellLayout layout) {
  double at(WeekStart start) {
    final Offset place = tester.getTopLeft(find.byKey(weekChoiceKey(start)));
    return switch (layout) {
      ShellLayout.sidebar => place.dx,
      ShellLayout.bottomBar => place.dy,
    };
  }

  return WeekStart.values.toList()
    ..sort((WeekStart a, WeekStart b) => at(a).compareTo(at(b)));
}

Finder _inChoice(WeekStart start, String text) => find.descendant(
  of: find.byKey(weekChoiceKey(start)),
  matching: find.text(text),
);

void _expectChoices(
  WidgetTester tester,
  ShellLayout layout, {
  required List<WeekStart> order,
  required WeekStart selected,
}) {
  expect(_choiceOrder(tester, layout), order);
  final WeekStart region = order.first;
  for (final WeekStart start in WeekStart.values) {
    final Finder control = find.byKey(weekChoiceKey(start));
    final bool on = start == selected;
    final String caption = start == region ? _regionDefault : _usedIn[start]!;
    expect(_inChoice(start, start.label), findsOneWidget);
    expect(tester.getSize(control).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
    switch (layout) {
      case ShellLayout.sidebar:
        expect(_inChoice(start, caption), findsNothing);
        expect(
          tester.getSemantics(control),
          isSemantics(
            label: start.label,
            isButton: true,
            isSelected: on,
            hasTapAction: true,
          ),
        );
      case ShellLayout.bottomBar:
        expect(_inChoice(start, caption), findsOneWidget);
        expect(
          tester.getSemantics(control),
          isSemantics(
            label: '${start.label}, $caption',
            hasCheckedState: true,
            isChecked: on,
            isInMutuallyExclusiveGroup: true,
            hasTapAction: true,
          ),
        );
    }
  }
  expect(find.text(_usedIn[region]!), findsNothing);
  expect(
    find.text(_regionDefault),
    layout == ShellLayout.bottomBar ? findsOneWidget : findsNothing,
  );
}

void _expectNothingSaved(FakeSettingsRepository settings) {
  expect(settings.weekStartWrites, isEmpty);
  expect(settings.reminderEnabledWrites, isEmpty);
  expect(settings.reminderTimeWrites, isEmpty);
  expect(settings.notificationPermissionAskedWrites, isEmpty);
  expect(settings.onboardingStatusWrites, isEmpty);
  expect(settings.appearanceWrites, isEmpty);
}

Iterable<double> _opacitiesAbove(WidgetTester tester, Finder finder) => tester
    .widgetList<Opacity>(
      find.ancestor(of: finder, matching: find.byType(Opacity)),
    )
    .map((Opacity opacity) => opacity.opacity);

void main() {
  testWidgets('week puts the region default first and slides the chosen day '
      'to the front', (WidgetTester tester) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        final FakeSettingsRepository us = await _pumpWeek(
          tester,
          layout,
          country: 'US',
        );
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('and you'), findsOneWidget);
        expect(find.text('Your week starts on…'), findsOneWidget);
        expect(_draft(tester)!.regionWeek, WeekStart.sunday);
        expect(_draft(tester)!.week, WeekStart.sunday);
        _expectChoices(
          tester,
          layout,
          order: <WeekStart>[
            WeekStart.sunday,
            WeekStart.monday,
            WeekStart.saturday,
          ],
          selected: WeekStart.sunday,
        );
        expect(_stripLetters(tester), <String>[
          'S',
          'M',
          'T',
          'W',
          'T',
          'F',
          'S',
        ]);
        expect(_stripOrder(tester).first, DateTime.sunday);
        _expectFirstRinged(tester, DateTime.sunday);
        expect(find.text(_privacy), findsOneWidget);

        final double sundayBefore = _left(tester, DateTime.sunday);
        await tester.tap(find.byKey(weekChoiceKey(WeekStart.monday)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final double sundayMoving = _left(tester, DateTime.sunday);
        await tester.pump(const Duration(seconds: 1));
        final double sundayAfter = _left(tester, DateTime.sunday);

        expect(sundayMoving, greaterThan(sundayBefore));
        expect(sundayMoving, lessThan(sundayAfter));
        expect(_draft(tester)!.week, WeekStart.monday);
        expect(_draft(tester)!.regionWeek, WeekStart.sunday);
        expect(_stripOrder(tester).first, DateTime.monday);
        expect(_stripLetters(tester), <String>[
          'M',
          'T',
          'W',
          'T',
          'F',
          'S',
          'S',
        ]);
        _expectFirstRinged(tester, DateTime.monday);
        _expectChoices(
          tester,
          layout,
          order: <WeekStart>[
            WeekStart.sunday,
            WeekStart.monday,
            WeekStart.saturday,
          ],
          selected: WeekStart.monday,
        );
        expect(find.text(_privacy), findsOneWidget);
        _expectNothingSaved(us);
        await _unmount(tester);

        final FakeSettingsRepository germany = await _pumpWeek(
          tester,
          layout,
          country: 'DE',
        );
        await tester.pump(const Duration(seconds: 1));

        expect(_draft(tester)!.regionWeek, WeekStart.monday);
        expect(_draft(tester)!.week, WeekStart.monday);
        _expectChoices(
          tester,
          layout,
          order: <WeekStart>[
            WeekStart.monday,
            WeekStart.sunday,
            WeekStart.saturday,
          ],
          selected: WeekStart.monday,
        );
        expect(_stripOrder(tester).first, DateTime.monday);
        _expectFirstRinged(tester, DateTime.monday);
        expect(find.text(_privacy), findsOneWidget);
        _expectNothingSaved(germany);
        await _unmount(tester);
      });
    }
  });

  testWidgets('week moves the strip at once with reduce motion', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        final FakeSettingsRepository settings = await _pumpWeek(
          tester,
          layout,
          country: 'US',
          reduceMotion: true,
        );
        await tester.pump();

        expect(tester.hasRunningAnimations, isFalse);
        expect(
          _opacitiesAbove(tester, find.text('Your week starts on…')),
          everyElement(1),
        );
        expect(_opacitiesAbove(tester, find.text(_privacy)), everyElement(1));
        expect(
          _opacitiesAbove(
            tester,
            find.byKey(weekChoiceKey(WeekStart.saturday)),
          ),
          everyElement(1),
        );

        await tester.tap(find.byKey(weekChoiceKey(WeekStart.saturday)));
        await tester.pump();

        expect(tester.hasRunningAnimations, isFalse);
        expect(_draft(tester)!.week, WeekStart.saturday);
        expect(_stripOrder(tester), <int>[
          DateTime.saturday,
          DateTime.sunday,
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
        ]);
        _expectFirstRinged(tester, DateTime.saturday);
        _expectNothingSaved(settings);
        await _unmount(tester);
      });
    }
  });

  testWidgets('week choices are labelled targets of at least 48 points', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        await _pumpWeek(tester, layout, country: 'US');
        await tester.pump(const Duration(seconds: 1));

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await _unmount(tester);
      });
    }
  });
}
