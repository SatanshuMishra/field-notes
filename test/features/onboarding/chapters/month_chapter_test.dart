import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/database/app_database.dart' as db;
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/design/flowers/flower_bloom.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/domain/settings/week_start.dart';
import 'package:field_notes/features/calendar/model/calendar_month.dart';
import 'package:field_notes/features/onboarding/chapters/month_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../app/support/app_shell_harness.dart';
import '../../capture/core/capture_test_support.dart' show newTestDatabase;

const String _entryDate = '2026-10-14';
const int _today = 14;
const int _lastDay = 31;

const Size _sidebarArea = Size(1280, 758);
const Size _bottomBarArea = Size(360, 740);

const Size _smallestSidebarArea = Size(873, 558);
const Size _smallestBottomBarArea = Size(360, 640);
const List<double> _textScales = <double>[1, 1.3];
const List<double> _fills = <double>[0, 1];
const int _sixWeekRows = 6;
const double _legibleCell = 24;
const double _sliderTarget = 48;
const double _phoneSlider = 36;
const double _edge = 0.5;

const int _sixRowYear = 2026;
const List<(WeekStart, int)> _sixRowMonths = <(WeekStart, int)>[
  (WeekStart.sunday, DateTime.august),
  (WeekStart.monday, DateTime.march),
  (WeekStart.saturday, DateTime.may),
];

const String _longLine =
    'Walked down to the lake after work and the water was so still it '
    'looked like glass. Stood there for a long while, thinking about '
    'nothing at all, until the light went orange and then grey.';

const List<Mood?> _octoberSamples = <Mood?>[
  Mood.sad,
  Mood.happy,
  Mood.angry,
  Mood.hopeful,
  Mood.sad,
  Mood.angry,
  Mood.grateful,
  Mood.angry,
  null,
  Mood.anxious,
  Mood.grateful,
  Mood.hopeful,
  null,
  Mood.anxious,
  Mood.grateful,
  Mood.sad,
  Mood.calm,
  Mood.love,
  Mood.anxious,
  Mood.sad,
  Mood.happy,
  Mood.angry,
  Mood.love,
  Mood.hopeful,
  Mood.grateful,
  Mood.angry,
  null,
  Mood.hopeful,
  Mood.angry,
  Mood.grateful,
  Mood.happy,
];

const List<Mood?> _februarySamples = <Mood?>[
  Mood.tired,
  Mood.happy,
  Mood.sad,
  Mood.hopeful,
  Mood.angry,
  null,
  Mood.anxious,
  Mood.hopeful,
  Mood.love,
  Mood.angry,
  Mood.angry,
  Mood.warm,
  Mood.calm,
  Mood.warm,
  Mood.angry,
  Mood.tired,
  Mood.angry,
  Mood.tired,
  Mood.calm,
  null,
  Mood.anxious,
  Mood.warm,
  Mood.sad,
  Mood.hopeful,
  Mood.tired,
  Mood.angry,
  Mood.angry,
  Mood.grateful,
];

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

OnboardingDraft _draft({
  required WeekStart week,
  required Mood mood,
  String note = '',
}) => OnboardingDraft(
  entryDate: _entryDate,
  regionWeek: WeekStart.sunday,
  week: week,
  mood: mood,
  noteText: note,
);

Future<db.AppDatabase> _pumpMonth(
  WidgetTester tester,
  ShellLayout layout,
  OnboardingDraft draft, {
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = switch (layout) {
    ShellLayout.sidebar => _sidebarArea,
    ShellLayout.bottomBar => _bottomBarArea,
  };
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db.AppDatabase database = newTestDatabase();
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        for (final Override override in shellOverrides())
          if (override.origin != journalRepositoryProvider) override,
        journalRepositoryProvider.overrideWithValue(
          DriftJournalRepository(database),
        ),
        onboardingControllerProvider.overrideWithBuild(
          (Ref ref, OnboardingController controller) => OnboardingFlowRunning(
            chapter: OnboardingChapter.month,
            draft: draft,
          ),
        ),
      ],
      child: MaterialApp(
        theme: fieldNotesTheme(platform: defaultTargetPlatform),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Material(child: MonthChapter(layout: layout)),
      ),
    ),
  );
  return database;
}

Future<List<String>> _pumpSmallestMonth(
  WidgetTester tester, {
  required ShellLayout layout,
  required DateTime today,
  required WeekStart week,
  required double fill,
}) async {
  tester.view.physicalSize = switch (layout) {
    ShellLayout.sidebar => _smallestSidebarArea,
    ShellLayout.bottomBar => _smallestBottomBarArea,
  };
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final List<String> problems = <String>[];
  final FlutterExceptionHandler? report = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) =>
      problems.add(details.exceptionAsString().split('\n').first);
  try {
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: <Override>[
          ...shellOverrides(),
          todayClockProvider.overrideWithValue(() => today),
          onboardingControllerProvider.overrideWithBuild(
            (Ref ref, OnboardingController controller) => OnboardingFlowRunning(
              chapter: OnboardingChapter.month,
              draft: OnboardingDraft(
                entryDate: ref.read(todayDateProvider),
                regionWeek: week,
                week: week,
                mood: Mood.calm,
                noteText: _longLine,
                monthFill: fill,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: fieldNotesTheme(platform: defaultTargetPlatform),
          home: Material(child: MonthChapter(layout: layout)),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
  } finally {
    FlutterError.onError = report;
  }
  return problems;
}

bool _within(Rect outer, Rect inner) =>
    inner.left >= outer.left - _edge &&
    inner.top >= outer.top - _edge &&
    inner.right <= outer.right + _edge &&
    inner.bottom <= outer.bottom + _edge;

void _expectFits(
  WidgetTester tester,
  ShellLayout layout,
  String shape,
  int today,
) {
  final Rect area = tester.getRect(find.byType(MonthChapter));
  final List<Rect> days = <Rect>[
    for (int day = 1; day <= _lastDay; day++) tester.getRect(_day(day)),
  ];
  expect(
    days.map((Rect day) => day.top.round()).toSet(),
    hasLength(_sixWeekRows),
    reason: shape,
  );
  for (final (int index, Rect day) in days.indexed) {
    expect(_within(area, day), isTrue, reason: '$shape: day ${index + 1}');
    expect(
      day.height,
      greaterThanOrEqualTo(_legibleCell),
      reason: '$shape: day ${index + 1}',
    );
  }
  expect(_flowerIn(today), findsOneWidget, reason: shape);
  final Rect slider = tester.getRect(find.byKey(monthSliderKey));
  expect(_within(area, slider), isTrue, reason: '$shape: slider');
  expect(slider.height, switch (layout) {
    ShellLayout.sidebar => greaterThanOrEqualTo(_sliderTarget),
    ShellLayout.bottomBar => moreOrLessEquals(_phoneSlider),
  }, reason: shape);
  final Finder card = find.byKey(monthNoteCardKey);
  if (card.evaluate().isNotEmpty) {
    expect(_within(area, tester.getRect(card)), isTrue, reason: '$shape: card');
  }
}

Future<void> _expectNothingSaved(db.AppDatabase database) async {
  expect(await database.select(database.days).get(), isEmpty);
  expect(await database.select(database.entries).get(), isEmpty);
}

Future<void> _unmount(WidgetTester tester, db.AppDatabase database) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await database.close();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MonthChapter)));

double _fill(WidgetTester tester) =>
    switch (_container(tester).read(onboardingControllerProvider)) {
      OnboardingFlowRunning(:final OnboardingDraft draft) => draft.monthFill,
      OnboardingFlowHidden() || OnboardingFlowMap() => -1,
    };

Finder _day(int day) => find.byKey(monthDayKey(day));

Finder _flowerIn(int day) =>
    find.descendant(of: _day(day), matching: find.byType(FlowerBloom));

Finder _ringIn(int day) =>
    find.descendant(of: _day(day), matching: find.byKey(monthRingKey));

Finder get _letters => find.descendant(
  of: find.byKey(monthLettersKey),
  matching: find.byType(Text),
);

Finder _inCard(String text) => find.descendant(
  of: find.byKey(monthNoteCardKey),
  matching: find.text(text),
);

double _opacity(WidgetTester tester, int day) => tester
    .widget<AnimatedOpacity>(
      find.descendant(of: _day(day), matching: find.byType(AnimatedOpacity)),
    )
    .opacity;

void _expectGrid(
  WidgetTester tester, {
  required int firstWeekday,
  required List<String> letters,
}) {
  expect(
    tester.widgetList<Text>(_letters).map((Text text) => text.data).toList(),
    letters,
  );
  final int leading = (DateTime(2026, 10).weekday - firstWeekday + 7) % 7;
  for (int slot = 0; slot < leading; slot++) {
    expect(find.byKey(monthBlankKey(slot)), findsOneWidget);
  }
  expect(find.byKey(monthBlankKey(leading)), findsNothing);
  for (int day = 1; day <= _lastDay; day++) {
    expect(_day(day), findsOneWidget);
  }
  expect(_day(_lastDay + 1), findsNothing);
  expect(
    tester.getCenter(_day(1)).dx,
    moreOrLessEquals(tester.getCenter(_letters.at(leading)).dx, epsilon: 0.5),
  );
  expect(
    tester.getCenter(_day(8 - leading)).dx,
    moreOrLessEquals(tester.getCenter(_letters.at(0)).dx, epsilon: 0.5),
  );
  expect(
    tester.getTopLeft(_day(8 - leading)).dy,
    greaterThan(tester.getBottomLeft(_day(1)).dy),
  );
}

void _expectBeforeLooking(WidgetTester tester, Mood mood) {
  for (int day = 1; day < _today; day++) {
    expect(_opacity(tester, day), lessThan(1));
    expect(_flowerIn(day), findsNothing);
    expect(_ringIn(day), findsNothing);
  }
  expect(_opacity(tester, _today), 1);
  expect(tester.widget<FlowerBloom>(_flowerIn(_today)).kind, mood.flower);
  expect(
    find.descendant(of: _day(_today), matching: find.byKey(monthPetalKey)),
    findsOneWidget,
  );
  for (int day = _today + 1; day <= _lastDay; day++) {
    expect(_opacity(tester, day), lessThan(1));
    expect(_flowerIn(day), findsNothing);
    expect(_ringIn(day), findsNothing);
  }
  expect(find.text('1 flower so far'), findsOneWidget);
  expect(find.text('drag to look ahead →'), findsOneWidget);
}

void _expectFilledThrough(WidgetTester tester, int last) {
  for (int day = _today + 1; day <= _lastDay; day++) {
    final Mood? sample = _octoberSamples[day - 1];
    if (day > last) {
      expect(_flowerIn(day), findsNothing);
      expect(_ringIn(day), findsNothing);
    } else if (sample == null) {
      expect(_opacity(tester, day), 1);
      expect(_ringIn(day), findsOneWidget);
      expect(_flowerIn(day), findsNothing);
    } else {
      expect(_opacity(tester, day), 1);
      expect(_ringIn(day), findsNothing);
      expect(tester.widget<FlowerBloom>(_flowerIn(day)).kind, sample.flower);
    }
  }
  final int flowers =
      1 +
      <int>[
        for (int day = _today + 1; day <= last; day++)
          if (_octoberSamples[day - 1] != null) day,
      ].length;
  expect(find.text('$flowers flowers'), findsOneWidget);
}

Future<void> _lookAllTheWayAhead(WidgetTester tester) async {
  await tester.drag(find.byKey(monthSliderKey), const Offset(2000, 0));
  await tester.pump(const Duration(seconds: 2));
  expect(_fill(tester), 1);
  _expectFilledThrough(tester, _lastDay);
  expect(find.text('17 flowers'), findsOneWidget);
  expect(find.text('by the end of Oct'), findsOneWidget);
  expect(find.text('1 flower so far'), findsNothing);
}

void main() {
  testWidgets(
    'a month rings today with the chosen flower and fills sample days without saving',
    (WidgetTester tester) async {
      await _onLayout(ShellLayout.sidebar, () async {
        final db.AppDatabase database = await _pumpMonth(
          tester,
          ShellLayout.sidebar,
          _draft(week: WeekStart.monday, mood: Mood.calm),
        );
        await tester.pump(const Duration(seconds: 3));

        expect(find.text('a month'), findsOneWidget);
        expect(find.text('Give it a few weeks.'), findsOneWidget);
        expect(find.text('October'), findsOneWidget);
        _expectGrid(
          tester,
          firstWeekday: DateTime.monday,
          letters: <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'],
        );
        _expectBeforeLooking(tester, Mood.calm);
        expect(find.text('Drag to see the weeks ahead'), findsOneWidget);
        expect(find.text('today'), findsOneWidget);
        expect(_inCard("No words yet. That's fine."), findsOneWidget);
        expect(_inCard('Today · Calm'), findsOneWidget);
        expect(
          find.text(
            'Every day stays open. Tap one to look back, or add to it.',
          ),
          findsOneWidget,
        );
        final Rect card = tester.getRect(find.byKey(monthNoteCardKey));
        final Rect today = tester.getRect(_day(_today));
        expect(card.left, greaterThan(today.right));
        expect(card.top, lessThan(today.bottom));
        expect(card.bottom, greaterThan(today.top));

        _container(tester)
            .read(onboardingControllerProvider.notifier)
            .setMonthFill(5 / 17);
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('5 days from now'), findsOneWidget);
        _expectFilledThrough(tester, 19);

        await _lookAllTheWayAhead(tester);
        await _expectNothingSaved(database);
        await _unmount(tester, database);
      });

      await _onLayout(ShellLayout.sidebar, () async {
        final db.AppDatabase database = await _pumpMonth(
          tester,
          ShellLayout.sidebar,
          _draft(week: WeekStart.monday, mood: Mood.calm, note: ' $_longLine '),
        );
        await tester.pump(const Duration(seconds: 3));

        final Finder line = _inCard(_longLine);
        expect(line, findsOneWidget);
        expect(tester.widget<Text>(line).maxLines, 3);
        expect(tester.widget<Text>(line).overflow, TextOverflow.ellipsis);
        expect(
          tester.renderObject<RenderParagraph>(line).didExceedMaxLines,
          isTrue,
        );
        expect(_inCard('Today · Calm'), findsOneWidget);
        expect(find.text("No words yet. That's fine."), findsNothing);
        await _expectNothingSaved(database);
        await _unmount(tester, database);
      });

      await _onLayout(ShellLayout.bottomBar, () async {
        final db.AppDatabase database = await _pumpMonth(
          tester,
          ShellLayout.bottomBar,
          _draft(week: WeekStart.saturday, mood: Mood.love, note: _longLine),
        );
        await tester.pump(const Duration(seconds: 3));

        expect(find.text('a month'), findsOneWidget);
        expect(find.text('Give it a few weeks.'), findsOneWidget);
        expect(find.text('October'), findsOneWidget);
        _expectGrid(
          tester,
          firstWeekday: DateTime.saturday,
          letters: <String>['S', 'S', 'M', 'T', 'W', 'T', 'F'],
        );
        _expectBeforeLooking(tester, Mood.love);
        expect(find.text('drag to see the weeks ahead'), findsOneWidget);
        expect(find.byKey(monthNoteCardKey), findsNothing);
        expect(find.text(_longLine), findsNothing);
        expect(find.text('Today · Loved'), findsNothing);
        expect(
          find.text(
            'Every day stays open. Tap one to look back, or add to it.',
          ),
          findsNothing,
        );

        await _lookAllTheWayAhead(tester);
        await _expectNothingSaved(database);
        await _unmount(tester, database);
      });
    },
  );

  testWidgets('a month skips every entrance and loop with reduce motion', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        final db.AppDatabase database = await _pumpMonth(
          tester,
          layout,
          _draft(week: WeekStart.sunday, mood: Mood.warm),
          reduceMotion: true,
        );
        await tester.pump();

        expect(tester.hasRunningAnimations, isFalse);
        expect(
          tester
              .widgetList<Opacity>(
                find.ancestor(
                  of: _flowerIn(_today),
                  matching: find.byType(Opacity),
                ),
              )
              .map((Opacity opacity) => opacity.opacity),
          everyElement(1),
        );
        expect(
          tester
              .widgetList<Opacity>(
                find.ancestor(
                  of: find.text('Give it a few weeks.'),
                  matching: find.byType(Opacity),
                ),
              )
              .map((Opacity opacity) => opacity.opacity),
          everyElement(1),
        );

        await tester.drag(find.byKey(monthSliderKey), const Offset(2000, 0));
        await tester.pump();

        expect(tester.hasRunningAnimations, isFalse);
        expect(_opacity(tester, _lastDay), 1);
        expect(
          tester
              .widgetList<Opacity>(
                find.ancestor(
                  of: _flowerIn(_lastDay),
                  matching: find.byType(Opacity),
                ),
              )
              .map((Opacity opacity) => opacity.opacity),
          everyElement(1),
        );
        await _expectNothingSaved(database);
        await _unmount(tester, database);
      });
    }
  });

  testWidgets('a month fits the smallest windows even with six week rows', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final (WeekStart week, int month) in _sixRowMonths) {
      for (final int day in <int>[1, _lastDay]) {
        final DateTime today = DateTime(_sixRowYear, month, day, 9);
        for (final ShellLayout layout in ShellLayout.values) {
          for (final double scale in _textScales) {
            for (final double fill in _fills) {
              final String shape =
                  '${layout.name}, ${week.name} week, '
                  '${today.year}-${today.month}-${today.day}, '
                  'text scale $scale, fill $fill';
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              await _onLayout(layout, () async {
                final List<String> problems = await _pumpSmallestMonth(
                  tester,
                  layout: layout,
                  today: today,
                  week: week,
                  fill: fill,
                );
                expect(problems, isEmpty, reason: shape);
                expect(tester.takeException(), isNull, reason: shape);
                _expectFits(tester, layout, shape, day);
              });
            }
          }
        }
      }
    }
  });

  test('sample days follow a fixed sequence for each month, about one in '
      'six left open', () {
    expect(monthSampleMoods(const MonthRef(2026, 10)), _octoberSamples);
    expect(monthSampleMoods(const MonthRef(2031, 10)), _octoberSamples);
    expect(monthSampleMoods(const MonthRef(2026, 2)), _februarySamples);
    final List<Mood?> year = <Mood?>[
      for (int month = 1; month <= 12; month++)
        ...monthSampleMoods(MonthRef(2026, month)),
    ];
    expect(year, hasLength(365));
    expect(
      year.where((Mood? mood) => mood == null).length / year.length,
      inInclusiveRange(0.1, 0.25),
    );
  });

  test('monthName and WeekStart.weekday name the month and the first day', () {
    expect(
      <String>[for (int month = 1; month <= 12; month++) monthName(month)],
      <String>[
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ],
    );
    expect(WeekStart.sunday.weekday, DateTime.sunday);
    expect(WeekStart.monday.weekday, DateTime.monday);
    expect(WeekStart.saturday.weekday, DateTime.saturday);
  });
}
