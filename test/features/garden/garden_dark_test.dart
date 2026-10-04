import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/tokens/field_notes_colors.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/model/meadow_key_provider.dart';
import 'package:field_notes/features/garden/scene/meadow_plants.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart'
    hide MeadowRange;
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_desktop_page.dart';
import 'package:field_notes/features/garden/widgets/meadow_details_panel.dart';
import 'package:field_notes/features/garden/widgets/meadow_glass_popover.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_year_picker.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/settings_providers.dart';

import '../../support/theme_harness.dart';
import 'support/garden_harness.dart';

const Size _window = Size(1140, 900);
const int _buildFrames = 6000;
const FieldNotesColors _dark = FieldNotesColors.dark;

final DateTime _noon = DateTime.utc(2026, 9, 28, 18);
final SkyLocation _edmonton = resolveSkyLocation(
  'America/Edmonton',
  const Duration(hours: -6),
);

final List<Day> _days = <Day>[
  for (int day = 1; day <= 28; day++)
    dayOf(
      '2026-06-${day.toString().padLeft(2, '0')}',
      mood: moodOrder[day % moodOrder.length],
    ),
  dayOf('2025-04-02', mood: Mood.calm),
];

Future<void> _pump(WidgetTester tester, Brightness brightness) async {
  tester.view.physicalSize = _window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey<Brightness>(brightness),
      retry: (int retryCount, Object error) => null,
      overrides: <Override>[
        appSettingsProvider.overrideWith(
          (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
        ),
        allDaysProvider.overrideWith(
          (Ref ref) => Stream<List<Day>>.value(_days),
        ),
        journalEntryCountsProvider.overrideWith(
          (Ref ref) => Stream<Map<String, int>>.value(const <String, int>{
            '2026-06-03': 3,
            '2026-07-01': 1,
          }),
        ),
        meadowKeyProvider.overrideWith((Ref ref) async => 24601),
        skyClockProvider.overrideWithValue(() => _noon),
        skyLocationProvider.overrideWith((Ref ref) async => _edmonton),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(
          platform: TargetPlatform.macOS,
          brightness: brightness,
        ),
        home: Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const Scaffold(body: GardenScreen()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

MeadowStage _stage(WidgetTester tester) =>
    tester.widget<MeadowStage>(find.byType(MeadowStage));

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
  await tester.pump(const Duration(milliseconds: 400));
  return state;
}

Color? _textColour(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

Iterable<BoxDecoration> _fills(WidgetTester tester, Finder of) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: of, matching: find.byType(DecoratedBox)),
    )
    .map((DecoratedBox box) => box.decoration)
    .whereType<BoxDecoration>()
    .where((BoxDecoration decoration) => decoration.color != null);

int _argb(Color? colour) => colour!.toARGB32();

void main() {
  test('garden names no light-only colour', () {
    expect(lightOnlyTokenUses(<String>['lib/features/garden']), isEmpty);
  });

  testWidgets(
    'the meadow page keeps its glass chrome in both themes, draws its '
    'details in the dark palette and the scene the same',
    (WidgetTester tester) async {
      await _pump(tester, Brightness.light);
      final MeadowStage light = _stage(tester);
      final int lightKicker = _argb(_textColour(tester, 'your meadow'));
      final int lightTitle = _argb(_textColour(tester, 'Every day, a bloom'));

      await _pump(tester, Brightness.dark);
      final MeadowStage dark = _stage(tester);

      expect(dark.year.year, light.year.year);
      expect(listEquals(dark.year.days, light.year.days), isTrue);
      expect(dark.year.blooms, 28);
      expect(dark.seed, light.seed);
      expect(dark.sky, light.sky);
      expect(dark.morning, light.morning);
      expect(dark.mode, light.mode);
      expect(dark.compact, light.compact);
      expect(dark.growthPoint, light.growthPoint);
      expect(dark.growAnimated, light.growAnimated);
      expect(dark.highlight, light.highlight);
      expect(dark.motion, light.motion);

      expect(_argb(_textColour(tester, 'your meadow')), lightKicker);
      expect(_argb(_textColour(tester, 'your meadow')), _argb(meadowKickerInk));
      expect(_argb(_textColour(tester, 'Every day, a bloom')), lightTitle);
      expect(
        _argb(_textColour(tester, 'Every day, a bloom')),
        _argb(meadowCream),
      );
      expect(
        _textColour(
          tester,
          '28 blooms and 1 sprout so far in 2026 · '
          'quietly filling in as the year goes',
        )!.r,
        closeTo(meadowCream.r, 0.001),
      );
      expect(find.byKey(meadowDetailsPanelKey), findsNothing);

      await tester.tap(find.byKey(meadowDetailsButtonKey));
      await tester.pump();
      await tester.pump(meadowDetailsPanelSlide);
      final BoxDecoration panel =
          tester
                  .widget<DecoratedBox>(find.byKey(meadowDetailsPanelKey))
                  .decoration
              as BoxDecoration;
      expect(_argb(panel.color), _argb(_dark.cardWarm));
      expect(_argb((panel.border! as Border).top.color), _argb(_dark.line));
      expect(
        _argb(_textColour(tester, 'Hover a month to find its flowers')),
        _argb(_dark.muted),
      );
      expect(
        _argb(_textColour(tester, meadowDetailsKeysHint)),
        _argb(_dark.muted),
      );
      await tester.tap(find.byKey(meadowDetailsButtonKey));
      await tester.pump();
      await tester.pump(meadowDetailsPanelSlide);
      expect(find.byKey(meadowDetailsPanelKey), findsNothing);

      await tester.tap(find.byKey(meadowYearPickerButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        _argb(_fills(tester, find.byKey(meadowDropUpKey)).first.color),
        _argb(meadowGlassFill),
      );
      expect(
        _argb(
          tester
              .widget<Text>(
                find.descendant(
                  of: find.byKey(meadowDropUpKey),
                  matching: find.text('your meadows'),
                ),
              )
              .style
              ?.color,
        ),
        _argb(meadowKickerInk),
      );
      expect(
        _argb(
          tester
              .widget<Text>(
                find.descendant(
                  of: find.byKey(meadowYearRowKey(2026)),
                  matching: find.text('2026'),
                ),
              )
              .style
              ?.color,
        ),
        _argb(meadowCream),
      );
      await tester.tapAt(const Offset(4, 4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(meadowDropUpKey), findsNothing);

      final MeadowStageState state = await _grow(tester);
      final MeadowTerrain terrain = buildMeadowTerrain(
        seed: dark.seed,
        year: dark.year,
      );
      final Rect safe = Rect.fromLTRB(
        120,
        meadowDeskScrimDepth + 20,
        _window.width - 120,
        _window.height - 120,
      );
      final Offset origin = tester.getTopLeft(find.byType(MeadowStage));
      final Offset head =
          buildMeadowPlants(seed: dark.seed, year: dark.year, terrain: terrain)
              .plants
              .where((MeadowPlant plant) => !plant.hidden)
              .map(
                (MeadowPlant plant) =>
                    origin + state.debugViewport!.toLocal(plant.heads.last),
              )
              .firstWhere(safe.contains);
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(head);
      await tester.pump();

      expect(find.byType(MeadowGlassTip), findsOneWidget);
      expect(
        _argb(_fills(tester, find.byType(MeadowGlassTip)).single.color),
        _argb(const Color.fromRGBO(28, 22, 16, 0.5)),
      );
    },
  );
}
