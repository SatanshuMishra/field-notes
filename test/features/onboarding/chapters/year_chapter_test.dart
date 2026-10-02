import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/database/app_database.dart' as db;
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/domain/settings/week_start.dart';
import 'package:field_notes/features/calendar/model/calendar_month.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:field_notes/features/onboarding/chapters/year_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../app/support/app_shell_harness.dart';
import '../../capture/core/capture_test_support.dart' show newTestDatabase;

const String _entryDate = '2026-10-01';
const int _wholeYear = 365;
const int _readyFrames = 6000;
const Duration _frame = Duration(milliseconds: 100);
const int _framesToEleven = 110;
const int _framesToTen = 100;

const Size _sidebarArea = Size(1280, 758);
const Size _bottomBarArea = Size(360, 740);

final List<String> _yearLabels = <String>[
  for (int month = 1; month <= 12; month++) monthName(month),
  'A whole year',
];

final SkyLocation _solarClock = resolveSkyLocation(
  null,
  DateTime(2023, 9, 23).timeZoneOffset,
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

String _caption(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => 'every flower is a day · drag back through it',
  ShellLayout.bottomBar => 'every flower is a day · drag through it',
};

Future<db.AppDatabase> _pumpYear(
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
        skyLocationProvider.overrideWith((Ref ref) async => _solarClock),
        onboardingControllerProvider.overrideWithBuild(
          (Ref ref, OnboardingController controller) => OnboardingFlowRunning(
            chapter: OnboardingChapter.year,
            draft: const OnboardingDraft(
              entryDate: _entryDate,
              regionWeek: WeekStart.sunday,
              week: WeekStart.sunday,
            ),
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
        home: Material(child: YearChapter(layout: layout)),
      ),
    ),
  );
  return database;
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

MeadowStage _stageWidget(WidgetTester tester) =>
    tester.widget<MeadowStage>(find.byType(MeadowStage));

MeadowStageState _stageState(WidgetTester tester) =>
    tester.state<MeadowStageState>(find.byType(MeadowStage));

int? _growthPoint(WidgetTester tester) => _stageWidget(tester).growthPoint;

OnboardingDraft _draft(WidgetTester tester) =>
    switch (ProviderScope.containerOf(tester.element(find.byType(YearChapter)))
        .read(onboardingControllerProvider)) {
      OnboardingFlowRunning(:final OnboardingDraft draft) => draft,
      OnboardingFlowHidden() ||
      OnboardingFlowMap() => throw StateError('onboarding is not running'),
    };

String _shownLabel(WidgetTester tester) => _yearLabels.singleWhere(
  (String label) => find.text(label).evaluate().isNotEmpty,
);

Future<void> _untilReady(
  WidgetTester tester, {
  void Function()? eachFrame,
}) async {
  final MeadowStageState stage = _stageState(tester);
  for (int i = 0; i < _readyFrames && !stage.debugIsReady; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump();
    eachFrame?.call();
  }
  expect(stage.debugIsReady, isTrue, reason: 'the meadow never finished');
  await tester.pump();
  eachFrame?.call();
}

Future<void> _scrubToMiddle(WidgetTester tester) async {
  final Rect slider = tester.getRect(find.byKey(yearSliderKey));
  final TestGesture gesture = await tester.startGesture(
    Offset(slider.left + slider.width * 0.2, slider.center.dy),
  );
  await tester.pump();
  await gesture.moveTo(
    Offset(slider.left + slider.width * 0.35, slider.center.dy),
  );
  await tester.pump();
  await gesture.moveTo(slider.center);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets(
    'a year grows a sample year in about eleven seconds, scrubs and replays',
    (WidgetTester tester) async {
      for (final ShellLayout layout in ShellLayout.values) {
        await _onLayout(layout, () async {
          final db.AppDatabase database = await _pumpYear(tester, layout);
          await tester.pump(const Duration(seconds: 2));
          expect(find.text(meadowLoadingMessage), findsOneWidget);
          expect(find.text('a year'), findsOneWidget);
          expect(
            find.text('This is roughly what a year of you looks like.'),
            findsOneWidget,
          );
          expect(find.byKey(yearSliderKey), findsNothing);
          expect(_growthPoint(tester), 0, reason: '$layout before ready');
          expect(_draft(tester).yearDay, 0);

          await _untilReady(tester);
          expect(find.text(meadowLoadingMessage), findsNothing);
          expect(_growthPoint(tester), 0);
          expect(_stageWidget(tester).growAnimated, isTrue);
          final List<String> shown = <String>[_shownLabel(tester)];
          int previous = 0;
          for (int frame = 1; frame <= _framesToEleven; frame++) {
            await tester.pump(_frame);
            final int point = _growthPoint(tester)!;
            expect(point, greaterThanOrEqualTo(previous), reason: '$frame');
            previous = point;
            if (frame == _framesToTen) {
              expect(point, lessThan(_wholeYear), reason: '$layout at 10 s');
            }
            final String label = _shownLabel(tester);
            if (label != shown.last) {
              shown.add(label);
            }
          }
          expect(_growthPoint(tester), _wholeYear, reason: '$layout at 11 s');
          expect(_draft(tester).yearDay, _wholeYear);
          expect(shown, _yearLabels, reason: '$layout month labels');
          expect(find.text('365 of 365 days'), findsOneWidget);
          expect(find.text(_caption(layout)), findsOneWidget);
          expect(find.bySemanticsLabel('Replay the year'), findsOneWidget);

          await tester.tap(find.byKey(yearReplayKey));
          await tester.pump();
          expect(_growthPoint(tester), 0, reason: '$layout replay restarts');
          expect(find.text('January'), findsOneWidget);
          expect(find.text(_caption(layout)), findsNothing);
          await tester.pump(const Duration(seconds: 3));
          final int playing = _growthPoint(tester)!;
          expect(playing, inExclusiveRange(0, _wholeYear));
          expect(_draft(tester).yearScrubbed, isFalse);

          await _scrubToMiddle(tester);
          final int scrubbed = _growthPoint(tester)!;
          expect(scrubbed, inInclusiveRange(182, 183), reason: '$layout');
          expect(_draft(tester).yearDay, scrubbed);
          expect(_draft(tester).yearScrubbed, isTrue);
          expect(_stageWidget(tester).growAnimated, isFalse);
          await tester.pump(const Duration(seconds: 4));
          expect(_growthPoint(tester), scrubbed, reason: '$layout stopped');

          await tester.tap(find.byKey(yearReplayKey));
          await tester.pump();
          expect(_growthPoint(tester), 0);
          await tester.pump(const Duration(seconds: 2));
          expect(_growthPoint(tester), inExclusiveRange(0, _wholeYear));
          await tester.pump(const Duration(seconds: 9));
          await tester.pump();
          expect(_growthPoint(tester), _wholeYear);

          await _expectNothingSaved(database);
          await _unmount(tester, database);
        });

        await _onLayout(layout, () async {
          final db.AppDatabase database = await _pumpYear(
            tester,
            layout,
            reduceMotion: true,
          );
          await tester.pump(const Duration(seconds: 2));
          expect(_growthPoint(tester), 0, reason: '$layout still before ready');
          await _untilReady(tester);
          expect(_growthPoint(tester), _wholeYear, reason: '$layout at once');
          expect(_stageWidget(tester).growAnimated, isFalse);
          expect(find.text('A whole year'), findsOneWidget);
          expect(find.text(_caption(layout)), findsOneWidget);

          await tester.tap(find.byKey(yearReplayKey));
          await tester.pump();
          expect(_growthPoint(tester), _wholeYear);

          await _expectNothingSaved(database);
          await _unmount(tester, database);
        });
      }
    },
  );

  testWidgets('playing and scrubbing the year never regenerates the meadow', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        final db.AppDatabase database = await _pumpYear(tester, layout);
        final MeadowStage first = _stageWidget(tester);
        final MeadowYear year = first.year;
        final int seed = first.seed;
        final MeadowStageState state = _stageState(tester);
        final List<SkyScene> skies = <SkyScene>[first.sky];
        int frames = 0;
        void unchanged() {
          final MeadowStage stage = _stageWidget(tester);
          expect(identical(stage.year, year), isTrue, reason: '$layout year');
          expect(stage.seed, seed, reason: '$layout seed');
          expect(identical(_stageState(tester), state), isTrue);
          expect(state.debugGenerations, 1, reason: '$layout generations');
          if (stage.sky != skies.last) {
            skies.add(stage.sky);
          }
          frames++;
        }

        unchanged();
        await _untilReady(tester, eachFrame: unchanged);
        expect(year.daysInYear, _wholeYear);
        expect(year.year, 2023);
        expect(year.limit, _wholeYear);
        expect(year.blooms, greaterThan(0));
        expect(year.days.where((MeadowDay? day) => day == null), isNotEmpty);
        expect(_growthPoint(tester), 0);
        expect(
          _stageWidget(tester).sky.sunAltitude,
          lessThan(0),
          reason: 'early morning',
        );

        for (int frame = 0; frame < 60; frame++) {
          await tester.pump(_frame);
          unchanged();
        }
        final int midway = _growthPoint(tester)!;
        expect(midway, inExclusiveRange(150, 250));
        expect(_stageWidget(tester).sky.sunAltitude, greaterThan(0));

        await _scrubToMiddle(tester);
        unchanged();
        for (int frame = 0; frame < 10; frame++) {
          await tester.pump(_frame);
          unchanged();
        }

        await tester.tap(find.byKey(yearReplayKey));
        for (int frame = 0; frame <= _framesToEleven; frame++) {
          await tester.pump(_frame);
          unchanged();
        }
        expect(_growthPoint(tester), _wholeYear);
        expect(
          _stageWidget(tester).sky.sunAltitude,
          lessThan(0),
          reason: 'night',
        );
        expect(skies.length, greaterThan(100), reason: '$layout sky moves');
        expect(frames, greaterThan(_framesToEleven));

        await _expectNothingSaved(database);
        await _unmount(tester, database);
      });
    }
  });
}
