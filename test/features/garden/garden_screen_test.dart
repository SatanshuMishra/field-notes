import 'dart:async';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/model/meadow_key_provider.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_view_state.dart';
import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_full_screen.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_study_controls.dart';
import 'package:field_notes/features/garden/widgets/meadow_year_picker.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/garden_harness.dart';

const int _meadowKey = 24601;
const Size _window = Size(1140, 900);
const Duration _frame = Duration(milliseconds: 16);
const String _waiting =
    'Your meadow is waiting. Every day you journal plants a bloom here.';
const String _error = 'Your meadow could not be loaded right now.';

final DateTime _noon = DateTime.utc(2026, 9, 28, 18);
final SkyLocation _edmonton = resolveSkyLocation(
  'America/Edmonton',
  const Duration(hours: -6),
);

int _indexOf(int year, int month, int day) =>
    DateTime.utc(year, month, day).difference(DateTime.utc(year)).inDays;

SkyScene _skyAt(DateTime instant) =>
    skySceneAt(instant, _edmonton.latitude, _edmonton.longitude);

Future<void> _pump(
  WidgetTester tester, {
  required Stream<List<Day>> days,
  required Stream<Map<String, int>> counts,
  Future<int>? key,
}) async {
  tester.view.physicalSize = _window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    gardenHarness(
      const GardenScreen(),
      platform: TargetPlatform.macOS,
      overrides: <Override>[
        allDaysProvider.overrideWith((Ref ref) => days),
        journalEntryCountsProvider.overrideWith((Ref ref) => counts),
        meadowKeyProvider.overrideWith(
          (Ref ref) => key ?? Future<int>.value(_meadowKey),
        ),
        skyClockProvider.overrideWithValue(() => _noon),
        skyLocationProvider.overrideWith((Ref ref) async => _edmonton),
        skyDebugControlsProvider.overrideWithValue(false),
      ],
    ),
  );
  await tester.pump();
  await tester.pump();
}

MeadowStage _stage(WidgetTester tester) =>
    tester.widget<MeadowStage>(find.byType(MeadowStage));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GardenScreen)));

Finder _semanticsLabelled(String label) => find.byWidgetPredicate(
  (Widget widget) => widget is Semantics && widget.properties.label == label,
);

Offset _alongSlider(WidgetTester tester, Key key, double fraction) {
  final Rect track = tester.getRect(find.byKey(key));
  return Offset(
    track.left + 7 + (track.width - 14) * fraction,
    track.center.dy,
  );
}

void main() {
  testWidgets('loading, error and empty states of the meadow', (
    WidgetTester tester,
  ) async {
    final StreamController<List<Day>> days = StreamController<List<Day>>();
    addTearDown(days.close);
    final StreamController<Map<String, int>> counts =
        StreamController<Map<String, int>>();
    addTearDown(counts.close);
    final Completer<int> key = Completer<int>();

    await _pump(
      tester,
      days: days.stream,
      counts: counts.stream,
      key: key.future,
    );

    expect(find.text('your meadow'), findsOneWidget);
    expect(find.text('Every day, a bloom'), findsOneWidget);
    expect(find.text(meadowLoadingMessage), findsOneWidget);
    expect(find.byType(MeadowStage), findsNothing);
    expect(
      tester.getTopLeft(find.text(meadowLoadingMessage)).dy,
      greaterThan(tester.getBottomLeft(find.text('Every day, a bloom')).dy),
    );

    days.add(const <Day>[]);
    await tester.pump();
    expect(find.text(meadowLoadingMessage), findsOneWidget);
    expect(find.byType(MeadowStage), findsNothing);

    counts.add(const <String, int>{});
    await tester.pump();
    expect(find.text(meadowLoadingMessage), findsOneWidget);
    expect(find.byType(MeadowStage), findsNothing);

    key.complete(_meadowKey);
    await tester.pump();
    await tester.pump();

    final MeadowStage stage = _stage(tester);
    expect(stage.year.year, 2026);
    expect(stage.year.blooms, 0);
    expect(stage.year.sprouts, 0);
    expect(stage.seed, meadowSeed(_meadowKey, 2026));
    expect(stage.sky, _skyAt(_noon));
    expect(
      find.text(
        '0 blooms and 0 sprouts so far in 2026 · '
        'quietly filling in as the year goes',
      ),
      findsOneWidget,
    );
    final MeadowStageState state = tester.state<MeadowStageState>(
      find.byType(MeadowStage),
    );
    for (int i = 0; i < 6000 && !state.debugIsReady; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump();
    }
    expect(state.debugIsReady, isTrue);
    final Finder message = find.text(_waiting);
    expect(message, findsOneWidget);
    expect(
      tester.widget<Text>(message).style?.color,
      MeadowPalette.from(
        sky: stage.sky,
        morning: stage.morning,
        heavyShare: 0,
      ).captionColour,
    );
    final Rect scene = tester.getRect(find.byType(MeadowStage));
    expect(scene.contains(tester.getCenter(message)), isTrue);
    expect(tester.getCenter(message).dx, closeTo(scene.center.dx, 1));

    days.addError(Exception('boom'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(EmptyStatePlaceholder), findsOneWidget);
    expect(find.text(_error), findsOneWidget);
    expect(find.byType(MeadowStage), findsNothing);
    expect(find.text(_waiting), findsNothing);
    expect(find.text('your meadow'), findsOneWidget);
    expect(find.text('Every day, a bloom'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(_error)).dy,
      greaterThan(tester.getBottomLeft(find.text('Every day, a bloom')).dy),
    );
  });

  testWidgets('a partial year grows only days up to today', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pump(
      tester,
      days: Stream<List<Day>>.value(<Day>[
        dayOf('2025-06-01', mood: Mood.love),
        dayOf('2026-01-05', mood: Mood.happy),
        dayOf('2026-09-28', mood: Mood.calm),
        dayOf('2026-10-05', mood: Mood.warm),
        dayOf('2026-12-24', mood: Mood.sad),
      ]),
      counts: Stream<Map<String, int>>.value(const <String, int>{
        '2026-09-27': 2,
        '2026-09-28': 1,
        '2026-11-02': 1,
      }),
    );

    final MeadowStage stage = _stage(tester);
    expect(stage.mode, MeadowSceneMode.page);
    expect(stage.year.year, 2026);
    expect(stage.year.limit, _indexOf(2026, 9, 28) + 1);
    expect(stage.year.blooms, 2);
    expect(stage.year.sprouts, 1);
    expect(stage.growthPoint, isNull);
    expect(stage.resolvedGrowthPoint, _indexOf(2026, 9, 28) + 1);
    expect(stage.year.days[_indexOf(2026, 1, 5)]?.mood, Mood.happy);
    expect(stage.year.days[_indexOf(2026, 9, 27)]?.isSprout, isTrue);
    expect(stage.year.days[_indexOf(2026, 9, 28)]?.mood, Mood.calm);
    expect(stage.year.days[_indexOf(2026, 10, 5)], isNull);
    expect(stage.year.days[_indexOf(2026, 11, 2)], isNull);
    expect(stage.year.days[_indexOf(2026, 12, 24)], isNull);
    expect(find.text(_waiting), findsNothing);
    expect(
      find.text(
        '2 blooms and 1 sprout so far in 2026 · '
        'quietly filling in as the year goes',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Meadow, 2026: 2 blooms and 1 sprout so far'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('picking a past year shows its study and full screen opens', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      days: Stream<List<Day>>.value(<Day>[
        for (int day = 1; day <= 20; day++)
          dayOf(
            '2025-05-${day.toString().padLeft(2, '0')}',
            mood: moodOrder[day % moodOrder.length],
          ),
        dayOf('2026-02-14', mood: Mood.love),
      ]),
      counts: Stream<Map<String, int>>.value(const <String, int>{
        '2025-07-04': 1,
      }),
    );
    final ProviderContainer container = _container(tester);
    expect(_stage(tester).year.year, 2026);
    expect(find.byType(MeadowStudyControls), findsNothing);

    await tester.tap(find.byKey(meadowYearPickerButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(meadowYearRowKey(2026)), findsOneWidget);
    expect(find.byKey(meadowYearRowKey(2025)), findsOneWidget);

    await tester.tap(find.byKey(meadowYearRowKey(2025)));
    await tester.pumpAndSettle();

    expect(container.read(meadowViewStateProvider).studyYear, 2025);
    expect(find.text('meadow study'), findsOneWidget);
    expect(find.text('Your meadow, 2025'), findsOneWidget);
    expect(find.text(meadowBackLabel), findsOneWidget);
    expect(find.byType(MeadowStudyControls), findsOneWidget);
    MeadowStage stage = _stage(tester);
    expect(stage.mode, MeadowSceneMode.study);
    expect(stage.year.year, 2025);
    expect(stage.year.blooms, 20);
    expect(stage.year.sprouts, 1);
    expect(stage.seed, meadowSeed(_meadowKey, 2025));
    expect(stage.sky, _skyAt(_noon));

    await tester.tapAt(_alongSlider(tester, meadowHourSliderKey, 0.25));
    await tester.pump();
    final DateTime today = _noon.toLocal();
    final DateTime morning = DateTime(today.year, today.month, today.day, 6);
    expect(_stage(tester).sky, _skyAt(morning));
    expect(_stage(tester).sky, isNot(_skyAt(_noon)));

    await tester.tapAt(_alongSlider(tester, meadowGrowthSliderKey, 0.5));
    await tester.pump();
    stage = _stage(tester);
    expect(stage.growthPoint, 183);
    expect(stage.growAnimated, isTrue);

    await tester.tap(_semanticsLabelled(meadowFullScreenLabel));
    await tester.pump();
    await tester.pump(meadowFullScreenFade + _frame);

    expect(
      container.read(meadowViewStateProvider).fullScreen,
      const MeadowFullScreenRequest(
        year: 2025,
        hourMinutes: 6 * 60,
        growthPoint: 183,
      ),
    );
    final MeadowStage full = _stage(tester);
    expect(full.mode, MeadowSceneMode.full);
    expect(full.year.year, 2025);
    expect(full.growthPoint, 183);
    expect(full.seed, meadowSeed(_meadowKey, 2025));
    expect(full.sky, _skyAt(morning));

    await tester.tap(find.byKey(meadowFullScreenCloseKey));
    await tester.pump();
    await tester.pump(meadowFullScreenFade + _frame);

    expect(container.read(meadowViewStateProvider).fullScreen, isNull);
    expect(container.read(meadowViewStateProvider).studyYear, 2025);
    expect(_stage(tester).mode, MeadowSceneMode.study);
    expect(_stage(tester).growthPoint, 183);

    await tester.tap(find.text(meadowBackLabel));
    await tester.pumpAndSettle();
    expect(container.read(meadowViewStateProvider).studyYear, isNull);
    expect(find.text('your meadow'), findsOneWidget);
    expect(find.byType(MeadowStudyControls), findsNothing);
    expect(_stage(tester).mode, MeadowSceneMode.page);
    expect(_stage(tester).year.year, 2026);
  });
}
