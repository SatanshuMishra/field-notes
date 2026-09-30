import 'package:field_notes/design/format/clock_format.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/model/meadow_key_provider.dart';
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
import 'package:field_notes/features/garden/widgets/meadow_ribbon.dart';
import 'package:field_notes/features/garden/widgets/meadow_study_controls.dart';
import 'package:field_notes/features/garden/widgets/meadow_tabs.dart';
import 'package:field_notes/features/garden/widgets/meadow_year_picker.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const int _buildFrames = 6000;
const Size _desk = Size(1140, 900);
const Size _phone = Size(393, 852);
const Duration _frame = Duration(milliseconds: 16);

final DateTime _noon = DateTime.utc(2026, 9, 28, 18);
final DateTime _midnight = DateTime.utc(2026, 9, 29, 6);
final SkyLocation _edmonton = resolveSkyLocation(
  'America/Edmonton',
  const Duration(hours: -6),
);

final List<Day> _days = <Day>[
  dayOf('2024-08-08', mood: Mood.hopeful),
  for (int day = 1; day <= 12; day++)
    dayOf(
      '2025-03-${day.toString().padLeft(2, '0')}',
      mood: moodOrder[day % moodOrder.length],
    ),
  dayOf('2026-03-01', mood: Mood.happy),
  dayOf('2026-03-02', mood: Mood.calm),
  dayOf('2026-03-03'),
];

const Map<String, int> _counts = <String, int>{'2026-03-03': 1};

Future<ProviderContainer> _pumpPage(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Size size,
  List<Day>? days,
  Map<String, int> counts = _counts,
  DateTime? now,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    gardenHarness(
      Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: const GardenScreen(),
        ),
      ),
      platform: platform,
      overrides: <Override>[
        allDaysProvider.overrideWith(
          (Ref ref) => Stream<List<Day>>.value(days ?? _days),
        ),
        journalEntryCountsProvider.overrideWith(
          (Ref ref) => Stream<Map<String, int>>.value(counts),
        ),
        meadowKeyProvider.overrideWith((Ref ref) async => 24601),
        skyClockProvider.overrideWithValue(() => now ?? _noon),
        skyLocationProvider.overrideWith((Ref ref) async => _edmonton),
        skyDebugControlsProvider.overrideWithValue(false),
      ],
    ),
  );
  await tester.pump();
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(GardenScreen)));
}

Future<MeadowStageState> _grow(WidgetTester tester) async {
  final MeadowStageState state = tester.state<MeadowStageState>(
    find.byType(MeadowStage),
  );
  for (int i = 0; i < _buildFrames && !state.debugIsReady; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump();
  }
  expect(state.debugIsReady, isTrue, reason: 'the meadow never finished');
  return state;
}

String _clock(WidgetTester tester, DateTime instant) => formatClock(
  tester.element(find.byType(GardenScreen)),
  TimeOfDay.fromDateTime(instant.toLocal()),
);

MeadowStage _stage(WidgetTester tester) =>
    tester.widget<MeadowStage>(find.byType(MeadowStage));

Finder _semanticsLabelled(String label) => find.byWidgetPredicate(
  (Widget widget) => widget is Semantics && widget.properties.label == label,
);

BorderRadiusGeometry? _cardRadius(WidgetTester tester) => tester
    .widget<ClipRRect>(
      find
          .ancestor(
            of: find.byType(MeadowStage),
            matching: find.byType(ClipRRect),
          )
          .first,
    )
    .borderRadius;

BoxDecoration _cardEdge(WidgetTester tester) =>
    tester
            .widgetList<DecoratedBox>(
              find.ancestor(
                of: find.byType(MeadowStage),
                matching: find.byType(DecoratedBox),
              ),
            )
            .firstWhere(
              (DecoratedBox box) =>
                  box.position == DecorationPosition.foreground,
            )
            .decoration
        as BoxDecoration;

bool _hasInsetShadow(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.ancestor(
        of: find.byType(MeadowStage),
        matching: find.byType(CustomPaint),
      ),
    )
    .any(
      (CustomPaint paint) =>
          paint.painter.runtimeType.toString() == '_InsetShadowPainter',
    );

Future<void> _pickYear(WidgetTester tester, int year) async {
  await tester.tap(find.byKey(meadowYearPickerButtonKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(meadowYearRowKey(year)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'the sidebar page has the header with clock, picker and full screen, the '
    'fitted scene card and the tabs 16 below it',
    (WidgetTester tester) async {
      final ProviderContainer container = await _pumpPage(
        tester,
        platform: TargetPlatform.macOS,
        size: _desk,
      );

      expect(find.text('your meadow'), findsOneWidget);
      expect(find.text('Every day, a bloom'), findsOneWidget);
      expect(
        find.text(
          '2 blooms and 1 sprout so far in 2026 · '
          'quietly filling in as the year goes',
        ),
        findsOneWidget,
      );
      expect(tester.getTopLeft(find.text('your meadow')).dy, closeTo(26, 1));
      expect(tester.getTopLeft(find.text('your meadow')).dx, closeTo(34, 1));
      expect(find.text(_clock(tester, _noon)), findsOneWidget);
      final String sunset = _clock(tester, DateTime.utc(2026, 9, 29, 1, 17));
      final String moonrise = _clock(tester, DateTime.utc(2026, 9, 29, 1, 28));
      expect(find.text('sunset $sunset · moonrise $moonrise'), findsOneWidget);
      expect(find.byType(GardenSkyClock), findsOneWidget);
      expect(find.byKey(meadowYearPickerButtonKey), findsOneWidget);
      expect(find.byType(MeadowStudyControls), findsNothing);

      final MeadowStage stage = _stage(tester);
      expect(stage.mode, MeadowSceneMode.page);
      expect(stage.compact, isFalse);
      expect(stage.growthPoint, isNull);
      expect(stage.highlight, isNull);
      expect(
        stage.sky,
        skySceneAt(_noon, _edmonton.latitude, _edmonton.longitude),
      );

      final Rect scene = tester.getRect(find.byType(MeadowStage));
      expect(scene.left, closeTo(34, 0.5));
      expect(scene.width, closeTo(_desk.width - 68, 0.5));
      expect(scene.height, closeTo(scene.width * 640 / 1400, 0.5));
      expect(_cardRadius(tester), const BorderRadius.all(Radius.circular(20)));
      final Border edge = _cardEdge(tester).border! as Border;
      expect(edge.top.color, FieldNotesColors.light.ink22);
      expect(edge.top.width, 1.5);
      expect(_hasInsetShadow(tester), isTrue);

      final Rect tabs = tester.getRect(find.byType(MeadowTabs));
      expect(tabs.top, closeTo(scene.bottom + 16, 0.5));
      expect(tabs.width, closeTo(scene.width, 0.5));
      expect(find.text('The year, day by day'), findsOneWidget);
      expect(find.text('This year so far'), findsOneWidget);

      final Rect button = tester.getRect(
        _semanticsLabelled(meadowFullScreenLabel),
      );
      expect(button.width, greaterThanOrEqualTo(48));
      expect(button.height, greaterThanOrEqualTo(48));
      await tester.tap(_semanticsLabelled(meadowFullScreenLabel));
      await tester.pump();
      await tester.pump(meadowFullScreenFade + _frame);
      expect(
        container.read(meadowViewStateProvider).fullScreen,
        MeadowFullScreenRequest(
          year: 2026,
          hourMinutes: null,
          growthPoint: stage.year.limit,
        ),
      );
      expect(_stage(tester).mode, MeadowSceneMode.full);
      expect(_stage(tester).compact, isFalse);

      await tester.tap(find.byKey(meadowFullScreenCloseKey));
      await tester.pump();
      await tester.pump(meadowFullScreenFade + _frame);
      expect(container.read(meadowViewStateProvider).fullScreen, isNull);
    },
  );

  testWidgets(
    'the bottom-bar page has the compact header, a 300-tall scene card and '
    'the tabs',
    (WidgetTester tester) async {
      await _pumpPage(tester, platform: TargetPlatform.android, size: _phone);

      expect(find.text('your meadow'), findsOneWidget);
      expect(find.text('Every day, a bloom'), findsOneWidget);
      expect(tester.getTopLeft(find.text('your meadow')).dx, closeTo(18, 1));
      expect(find.text(_clock(tester, _noon)), findsOneWidget);
      final String sunset = _clock(tester, DateTime.utc(2026, 9, 29, 1, 17));
      expect(find.text('sunset $sunset'), findsOneWidget);
      expect(find.textContaining('moonrise'), findsNothing);

      final MeadowStage stage = _stage(tester);
      expect(stage.compact, isTrue);
      expect(stage.mode, MeadowSceneMode.page);
      final Rect scene = tester.getRect(find.byType(MeadowStage));
      expect(scene.left, closeTo(16, 0.5));
      expect(scene.width, closeTo(_phone.width - 32, 0.5));
      expect(scene.height, closeTo(300, 0.5));
      expect(_cardRadius(tester), const BorderRadius.all(Radius.circular(16)));
      expect(
        (_cardEdge(tester).border! as Border).top.color,
        FieldNotesColors.light.ink22,
      );
      expect(_hasInsetShadow(tester), isFalse);
      expect(
        tester.getTopLeft(find.byType(MeadowTabs)).dy,
        closeTo(scene.bottom + 16, 0.5),
      );
      expect(find.text('Day by day'), findsOneWidget);
    },
  );

  testWidgets(
    'the study keeps its hour, growth point and highlight until the year '
    'changes',
    (WidgetTester tester) async {
      await _pumpPage(tester, platform: TargetPlatform.android, size: _phone);

      await _pickYear(tester, 2025);
      expect(find.byType(MeadowStudyControls), findsOneWidget);
      expect(find.text(meadowBackCompactLabel), findsOneWidget);
      expect(find.byType(GardenSkyClock), findsNothing);
      expect(find.text('Landmarks'), findsOneWidget);

      await tester.drag(find.byKey(meadowHourSliderKey), const Offset(-400, 0));
      await tester.pump();
      final MeadowStudyControls controls = tester.widget<MeadowStudyControls>(
        find.byType(MeadowStudyControls),
      );
      expect(controls.hourMinutes, 0);
      final DateTime today = _noon.toLocal();
      expect(
        _stage(tester).sky,
        skySceneAt(
          DateTime(today.year, today.month, today.day),
          _edmonton.latitude,
          _edmonton.longitude,
        ),
      );

      await tester.drag(
        find.byKey(meadowGrowthSliderKey),
        const Offset(-400, 0),
      );
      await tester.pump();
      expect(_stage(tester).growthPoint, 1);

      await tester.ensureVisible(find.text('Mar'));
      await tester.tap(find.text('Mar'));
      await tester.pump();
      final MeadowRange march = meadowMonthRange(_stage(tester).year.months[2]);
      expect(_stage(tester).highlight, march);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();
      await _pickYear(tester, 2024);
      final MeadowStage reset = _stage(tester);
      expect(reset.year.year, 2024);
      expect(reset.mode, MeadowSceneMode.study);
      expect(reset.growthPoint, reset.year.limit);
      expect(reset.growAnimated, isFalse);
      expect(reset.highlight, isNull);
      expect(
        tester
            .widget<MeadowStudyControls>(find.byType(MeadowStudyControls))
            .hourMinutes,
        isNull,
      );
      expect(
        reset.sky,
        skySceneAt(_noon, _edmonton.latitude, _edmonton.longitude),
      );
    },
  );

  testWidgets(
    "the waiting message takes the caption colour of the scene's sky",
    (WidgetTester tester) async {
      await _pumpPage(
        tester,
        platform: TargetPlatform.macOS,
        size: _desk,
        days: const <Day>[],
        counts: const <String, int>{},
        now: _midnight,
      );

      final MeadowStage stage = _stage(tester);
      final Finder message = find.text(
        'Your meadow is waiting. Every day you journal plants a bloom here.',
      );
      final Color? colour = tester.widget<Text>(message).style?.color;
      expect(
        colour,
        MeadowPalette.from(
          sky: stage.sky,
          morning: stage.morning,
          heavyShare: 0,
        ).captionColour,
      );
      expect(colour, const Color.fromRGBO(236, 230, 214, 0.85));
      final Rect scene = tester.getRect(find.byType(MeadowStage));
      final Offset centre = tester.getCenter(message);
      expect(scene.contains(centre), isTrue);
      expect(centre.dx, closeTo(scene.center.dx, 1));
      expect(
        tester.getTopLeft(message).dy,
        greaterThan(tester.getBottomLeft(find.text(meadowLoadingMessage)).dy),
      );
    },
  );

  testWidgets('the page leaves motion to the platform setting', (
    WidgetTester tester,
  ) async {
    await _pumpPage(
      tester,
      platform: TargetPlatform.macOS,
      size: _desk,
      disableAnimations: true,
    );
    expect(_stage(tester).motion, isNull);
    MeadowStageState state = await _grow(tester);
    expect(state.debugIsTicking, isFalse);
    await tester.pumpWidget(const SizedBox());

    await _pumpPage(tester, platform: TargetPlatform.macOS, size: _desk);
    expect(_stage(tester).motion, isNull);
    state = await _grow(tester);
    expect(state.debugIsTicking, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
