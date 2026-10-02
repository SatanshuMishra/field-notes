import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/database/app_database.dart' as db;
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/design/flowers/flower_bloom.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/domain/settings/week_start.dart';
import 'package:field_notes/features/onboarding/chapters/day_chapter.dart';
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

const String _entryDate = '2026-10-14';

const Size _sidebarArea = Size(1280, 758);
const Size _bottomBarArea = Size(360, 740);

Size _areaFor(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => _sidebarArea,
  ShellLayout.bottomBar => _bottomBarArea,
};

String _happyCaption(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar =>
    "that's your peony from earlier · pick another if today felt different",
  ShellLayout.bottomBar => 'your peony · swipe for nine more →',
};

String _otherCaption(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => 'one flower a day · nobody else sees this',
  ShellLayout.bottomBar => 'one flower a day · swipe for more →',
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

Future<db.AppDatabase> _pumpDay(
  WidgetTester tester,
  ShellLayout layout, {
  Mood? mood,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = _areaFor(layout);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db.AppDatabase database = newTestDatabase();
  final OnboardingDraft draft = OnboardingDraft(
    entryDate: _entryDate,
    regionWeek: WeekStart.sunday,
    week: WeekStart.sunday,
  );
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
            chapter: OnboardingChapter.day,
            draft: mood == null ? draft : draft.copyWith(mood: mood),
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
        home: Material(child: DayChapter(layout: layout)),
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

Future<void> _run(WidgetTester tester, Duration total) async {
  const Duration step = Duration(milliseconds: 100);
  for (Duration spent = Duration.zero; spent < total; spent += step) {
    await tester.pump(step);
  }
}

Mood _draftMood(WidgetTester tester) =>
    switch (ProviderScope.containerOf(tester.element(find.byType(DayChapter)))
        .read(onboardingControllerProvider)) {
      OnboardingFlowRunning(:final OnboardingDraft draft) => draft.mood,
      OnboardingFlowHidden() ||
      OnboardingFlowMap() => throw StateError('onboarding is not running'),
    };

Finder _tile(Mood mood) => find.byKey(dayMoodKey(mood));

Finder get _row => find.byKey(dayMoodRowKey);

Finder _plantPaint(FlowerKind kind) => find.descendant(
  of: find.byKey(dayPlantKey(kind)),
  matching: find.byType(CustomPaint),
);

Finder _inCard(String text) =>
    find.descendant(of: find.byKey(dayCardKey), matching: find.text(text));

DayPlantPainter _plant(WidgetTester tester, FlowerKind kind) =>
    tester.widget<CustomPaint>(_plantPaint(kind)).painter! as DayPlantPainter;

ScrollPosition _rowPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(of: _row, matching: find.byType(Scrollable)),
    )
    .position;

bool _isSelectedFace(Widget widget) {
  if (widget is! AnimatedContainer) {
    return false;
  }
  final Decoration? decoration = widget.decoration;
  return decoration is BoxDecoration &&
      decoration.color == FieldNotesColors.light.cardLight &&
      decoration.border == Border.all(color: Palette.coral, width: 2);
}

double _faceOpacity(WidgetTester tester, Mood mood) => tester
    .widgetList<Opacity>(
      find.ancestor(
        of: find.descendant(
          of: _tile(mood),
          matching: find.byType(FlowerBloom),
        ),
        matching: find.byType(Opacity),
      ),
    )
    .fold(1, (double total, Opacity opacity) => total * opacity.opacity);

void _expectTiles(WidgetTester tester) {
  expect(
    find.descendant(of: _row, matching: find.byType(FlowerBloom)),
    findsNWidgets(moodOrder.length),
  );
  double? lastX;
  for (final Mood mood in moodOrder) {
    expect(_tile(mood), findsOneWidget);
    expect(
      find.descendant(of: _tile(mood), matching: find.text(mood.label)),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FlowerBloom>(
            find.descendant(
              of: _tile(mood),
              matching: find.byType(FlowerBloom),
            ),
          )
          .kind,
      mood.flower,
    );
    final Offset centre = tester.getCenter(_tile(mood));
    if (lastX != null) {
      expect(centre.dx, greaterThan(lastX));
    }
    expect(
      centre.dy,
      moreOrLessEquals(tester.getCenter(_tile(Mood.happy)).dy, epsilon: 0.5),
    );
    final Size size = tester.getSize(_tile(mood));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    lastX = centre.dx;
  }
}

void _expectSelected(WidgetTester tester, Mood chosen) {
  expect(_draftMood(tester), chosen);
  expect(
    find.descendant(
      of: _row,
      matching: find.byWidgetPredicate(_isSelectedFace),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: _tile(chosen),
      matching: find.byWidgetPredicate(_isSelectedFace),
    ),
    findsOneWidget,
  );
  expect(
    tester.getSemantics(_tile(chosen)),
    isSemantics(
      label: chosen.label,
      isButton: true,
      isSelected: true,
      hasTapAction: true,
    ),
  );
}

void _expectPlant(WidgetTester tester, Mood mood, {required double growth}) {
  for (final Mood other in moodOrder) {
    expect(
      find.byKey(dayPlantKey(other.flower)),
      other == mood ? findsOneWidget : findsNothing,
    );
  }
  final DayPlantPainter painter = _plant(tester, mood.flower);
  expect(painter.spec.kind, mood.flower);
  expect(painter.growth, growth);
  expect(_inCard(mood.label), findsOneWidget);
  expect(_inCard(mood.flower.label.toLowerCase()), findsOneWidget);
  final Rect plant = tester.getRect(_plantPaint(mood.flower));
  final Rect soil = tester.getRect(find.byKey(daySoilKey));
  expect(plant.bottom, greaterThan(soil.top));
  expect(plant.bottom, lessThan(soil.bottom));
  expect(tester.getRect(find.byKey(dayCardKey)).left, greaterThan(plant.right));
}

Future<void> _bringIntoView(WidgetTester tester, Mood mood) async {
  await tester.ensureVisible(_tile(mood));
  await _run(tester, const Duration(seconds: 1));
}

void main() {
  testWidgets(
    'a day lists ten moods, starts on happy and grows the chosen plant',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        for (final ShellLayout layout in ShellLayout.values) {
          await _onLayout(layout, () async {
            final db.AppDatabase database = await _pumpDay(tester, layout);
            await _run(tester, const Duration(seconds: 3));

            expect(find.text('a day'), findsOneWidget);
            expect(find.text('How was today, honestly?'), findsOneWidget);
            _expectTiles(tester);
            _expectSelected(tester, Mood.happy);
            expect(
              tester.getSemantics(_tile(Mood.love)),
              isSemantics(
                label: Mood.love.label,
                isButton: true,
                isSelected: false,
              ),
            );
            expect(find.text(_happyCaption(layout)), findsOneWidget);
            expect(find.text(_otherCaption(layout)), findsNothing);
            _expectPlant(tester, Mood.happy, growth: 1);
            expect(_inCard('Happy'), findsOneWidget);
            expect(_inCard('peony'), findsOneWidget);

            if (layout == ShellLayout.bottomBar) {
              final ScrollPosition row = _rowPosition(tester);
              expect(row.pixels, 0);
              expect(row.maxScrollExtent, greaterThan(0));
              expect(
                tester.getRect(_tile(Mood.angry)).left,
                greaterThan(_bottomBarArea.width),
              );
              await tester.fling(_row, const Offset(-160, 0), 600);
              await _run(tester, const Duration(seconds: 2));
              expect(row.pixels, greaterThan(0));
              final double middle = _bottomBarArea.width / 2;
              expect(
                row.pixels == row.maxScrollExtent ||
                    moodOrder.any(
                      (Mood mood) =>
                          (tester.getCenter(_tile(mood)).dx - middle).abs() <
                          0.5,
                    ),
                isTrue,
              );
              await _bringIntoView(tester, Mood.calm);
            }

            await tester.tap(_tile(Mood.calm));
            await tester.pump();

            _expectSelected(tester, Mood.calm);
            expect(find.text(_otherCaption(layout)), findsOneWidget);
            expect(find.text(_happyCaption(layout)), findsNothing);
            expect(_plant(tester, FlowerKind.lavender).growth, lessThan(1));
            await tester.pump(const Duration(milliseconds: 300));
            expect(_plant(tester, FlowerKind.lavender).growth, greaterThan(0));
            expect(_plant(tester, FlowerKind.lavender).growth, lessThan(1));
            await _run(tester, const Duration(seconds: 1));
            _expectPlant(tester, Mood.calm, growth: 1);
            expect(_inCard('Calm'), findsOneWidget);
            expect(_inCard('lavender'), findsOneWidget);
            expect(_inCard('Happy'), findsNothing);
            expect(_inCard('peony'), findsNothing);

            await _expectNothingSaved(database);
            await _unmount(tester, database);
          });
        }
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets(
    'a day pops its tiles in turn and skips every entrance with reduce motion',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        for (final ShellLayout layout in ShellLayout.values) {
          await _onLayout(layout, () async {
            final db.AppDatabase database = await _pumpDay(tester, layout);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 520));
            expect(_faceOpacity(tester, Mood.happy), greaterThan(0));
            expect(_faceOpacity(tester, Mood.angry), 0);
            expect(_plant(tester, FlowerKind.peony).growth, greaterThan(0));
            expect(_plant(tester, FlowerKind.peony).growth, lessThan(1));
            await _run(tester, const Duration(seconds: 2));
            expect(_plant(tester, FlowerKind.peony).growth, 1);
            for (final Mood mood in moodOrder) {
              expect(_faceOpacity(tester, mood), 1);
            }
            await _unmount(tester, database);
          });

          await _onLayout(layout, () async {
            final db.AppDatabase database = await _pumpDay(
              tester,
              layout,
              mood: Mood.warm,
              reduceMotion: true,
            );
            await tester.pump();

            expect(tester.hasRunningAnimations, isFalse);
            for (final Mood mood in moodOrder) {
              expect(_faceOpacity(tester, mood), 1);
            }
            expect(
              tester
                  .widgetList<Opacity>(
                    find.ancestor(
                      of: find.text('How was today, honestly?'),
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
                      of: find.byKey(dayCardKey),
                      matching: find.byType(Opacity),
                    ),
                  )
                  .map((Opacity opacity) => opacity.opacity),
              everyElement(1),
            );
            _expectSelected(tester, Mood.warm);
            expect(find.text(_otherCaption(layout)), findsOneWidget);
            _expectPlant(tester, Mood.warm, growth: 1);

            if (layout == ShellLayout.bottomBar) {
              await _bringIntoView(tester, Mood.angry);
            }
            await tester.tap(_tile(Mood.angry));
            await tester.pump();

            expect(tester.hasRunningAnimations, isFalse);
            _expectSelected(tester, Mood.angry);
            _expectPlant(tester, Mood.angry, growth: 1);
            await _expectNothingSaved(database);
            await _unmount(tester, database);
          });
        }
      } finally {
        handle.dispose();
      }
    },
  );
}
