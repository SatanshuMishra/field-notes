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
const String _kicker = 'a day';
const String _title = 'Every feeling grows its own flower.';
const String _subtitle = 'There are ten. Pick the one that fits today.';
const List<String> _gone = <String>[
  'How was today, honestly?',
  "that's your peony from earlier · pick another if today felt different",
  'your peony · swipe for nine more →',
  'one flower a day · nobody else sees this',
  'one flower a day · swipe for more →',
];

const Size _sidebarArea = Size(1280, 758);
const Size _bottomBarArea = Size(360, 740);

Size _areaFor(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => _sidebarArea,
  ShellLayout.bottomBar => _bottomBarArea,
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

OnboardingDraft _draft(WidgetTester tester) =>
    switch (ProviderScope.containerOf(tester.element(find.byType(DayChapter)))
        .read(onboardingControllerProvider)) {
      OnboardingFlowRunning(:final OnboardingDraft draft) => draft,
      OnboardingFlowHidden() ||
      OnboardingFlowMap() => throw StateError('onboarding is not running'),
    };

Finder _tile(Mood mood) => find.byKey(dayMoodKey(mood));

Finder get _grid => find.byKey(dayMoodGridKey);

bool _isSelectedFace(Widget widget) {
  if (widget is! AnimatedContainer) {
    return false;
  }
  final Decoration? decoration = widget.decoration;
  return decoration is BoxDecoration &&
      decoration.color == FieldNotesColors.light.cardLight &&
      decoration.border == Border.all(color: Palette.coral, width: 2);
}

double _opacityAbove(WidgetTester tester, Finder finder) => tester
    .widgetList<Opacity>(
      find.ancestor(of: finder, matching: find.byType(Opacity)),
    )
    .fold(1, (double total, Opacity opacity) => total * opacity.opacity);

double _faceOpacity(WidgetTester tester, Mood mood) => _opacityAbove(
  tester,
  find.descendant(of: _tile(mood), matching: find.byType(FlowerBloom)),
);

void _expectCopy() {
  expect(find.text(_kicker), findsOneWidget);
  expect(find.text(_title), findsOneWidget);
  expect(find.text(_subtitle), findsOneWidget);
  for (final String text in _gone) {
    expect(find.text(text), findsNothing, reason: text);
  }
}

void _expectTiles(WidgetTester tester, ShellLayout layout) {
  expect(
    find.descendant(of: _grid, matching: find.byType(FlowerBloom)),
    findsNWidgets(moodOrder.length),
  );
  final List<Rect> tiles = <Rect>[
    for (final Mood mood in moodOrder) tester.getRect(_tile(mood)),
  ];
  for (final (int index, Mood mood) in moodOrder.indexed) {
    expect(
      find.descendant(of: _tile(mood), matching: find.text(mood.label)),
      findsOneWidget,
    );
    final FlowerBloom bloom = tester.widget<FlowerBloom>(
      find.descendant(of: _tile(mood), matching: find.byType(FlowerBloom)),
    );
    expect(bloom.kind, mood.flower);
    expect(tiles[index].width, greaterThanOrEqualTo(48), reason: mood.label);
    expect(tiles[index].height, greaterThanOrEqualTo(48), reason: mood.label);
  }
  switch (layout) {
    case ShellLayout.sidebar:
      for (int index = 1; index < tiles.length; index++) {
        expect(tiles[index].center.dy, tiles.first.center.dy);
        expect(tiles[index].left - tiles[index - 1].right, 8);
      }
      expect(tiles.first.size, const Size(76, 88));
      expect(
        (tiles.first.left + tiles.last.right) / 2,
        moreOrLessEquals(_sidebarArea.width / 2),
      );
      expect(tiles.first.bottom, _sidebarArea.height - 74);
    case ShellLayout.bottomBar:
      for (int index = 0; index < tiles.length; index++) {
        final int column = index % 5;
        final int row = index ~/ 5;
        expect(tiles[index].height, 72);
        expect(
          tiles[index].center.dx,
          moreOrLessEquals(tiles[column].center.dx),
        );
        expect(
          tiles[index].center.dy,
          moreOrLessEquals(tiles[row * 5].center.dy),
        );
        if (column > 0) {
          expect(
            tiles[index].left - tiles[index - 1].right,
            moreOrLessEquals(7),
          );
        }
      }
      expect(tiles[5].top - tiles[0].bottom, moreOrLessEquals(7));
      expect(tiles.first.left, 12);
      expect(tiles[4].right, moreOrLessEquals(_bottomBarArea.width - 12));
      expect(tiles.last.bottom, moreOrLessEquals(_bottomBarArea.height - 80));
  }
}

void _expectSelected(WidgetTester tester, Mood chosen) {
  expect(_draft(tester).mood, chosen);
  expect(
    find.descendant(
      of: _grid,
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

void main() {
  testWidgets(
    'a day lists ten moods on the soil, starts on happy and picks without saving',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        for (final ShellLayout layout in ShellLayout.values) {
          await _onLayout(layout, () async {
            final db.AppDatabase database = await _pumpDay(tester, layout);
            await _run(tester, const Duration(seconds: 3));

            _expectCopy();
            _expectTiles(tester, layout);
            _expectSelected(tester, Mood.happy);
            expect(_draft(tester).picked, isFalse);
            expect(
              tester.getSemantics(_tile(Mood.love)),
              isSemantics(
                label: Mood.love.label,
                isButton: true,
                isSelected: false,
              ),
            );

            await tester.tap(_tile(Mood.calm));
            await tester.pump();
            _expectSelected(tester, Mood.calm);
            expect(_draft(tester).picked, isTrue);

            await tester.tap(_tile(Mood.happy));
            await tester.pump();
            _expectSelected(tester, Mood.happy);
            expect(_draft(tester).picked, isTrue);

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
    'a day rises its words then its tiles and skips every entrance with reduce motion',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        for (final ShellLayout layout in ShellLayout.values) {
          await _onLayout(layout, () async {
            final db.AppDatabase database = await _pumpDay(tester, layout);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 550));
            expect(_opacityAbove(tester, find.text(_title)), 0);
            expect(_faceOpacity(tester, Mood.happy), 0);
            await tester.pump(const Duration(milliseconds: 500));
            expect(_opacityAbove(tester, find.text(_title)), greaterThan(0));
            expect(_faceOpacity(tester, Mood.happy), greaterThan(0));
            expect(_faceOpacity(tester, Mood.happy), lessThan(1));
            await _run(tester, const Duration(seconds: 1));
            expect(_opacityAbove(tester, find.text(_title)), 1);
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
            expect(_opacityAbove(tester, find.text(_title)), 1);
            expect(_opacityAbove(tester, find.text(_subtitle)), 1);
            for (final Mood mood in moodOrder) {
              expect(_faceOpacity(tester, mood), 1);
            }
            _expectSelected(tester, Mood.warm);

            await tester.tap(_tile(Mood.angry));
            await tester.pump();

            expect(tester.hasRunningAnimations, isFalse);
            _expectSelected(tester, Mood.angry);
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
