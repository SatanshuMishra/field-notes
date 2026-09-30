import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/garden_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_year_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const Size _sidebarSurface = Size(1140, 900);
const Size _bottomBarSurface = Size(400, 860);

final SkyMoment _moment = SkyMoment(instant: DateTime.utc(2025, 5, 15, 18));

Future<void> _pump(
  WidgetTester tester,
  Widget header, {
  required Size surface,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    gardenHarness(
      Padding(padding: const EdgeInsets.all(16), child: header),
      platform: TargetPlatform.macOS,
    ),
  );
}

MeadowHeader _header({
  required bool compact,
  required MeadowSceneMode mode,
  required int year,
  required int blooms,
  required int sprouts,
  required String weather,
  VoidCallback? onBack,
}) {
  final MeadowYear shown = MeadowYear.build(
    days: const <Day>[],
    entryCounts: const <String, int>{},
    year: year,
    today: DateTime(2025, 5, 15),
  );
  return MeadowHeader(
    compact: compact,
    mode: mode,
    year: year,
    blooms: blooms,
    sprouts: sprouts,
    weather: weather,
    onBack: onBack,
    controls: MeadowHeaderControls(
      compact: compact,
      clock: mode == MeadowSceneMode.page
          ? GardenSkyClock(moment: _moment, compact: compact)
          : null,
      picker: MeadowYearPicker(
        years: <MeadowYear>[shown],
        openYear: year,
        onPick: (int picked) {},
        compact: compact,
      ),
      onFullScreen: () {},
    ),
  );
}

void main() {
  testWidgets("this year's header counts blooms and sprouts so far", (
    WidgetTester tester,
  ) async {
    for (final (bool compact, Size surface) in <(bool, Size)>[
      (false, _sidebarSurface),
      (true, _bottomBarSurface),
    ]) {
      await _pump(
        tester,
        _header(
          compact: compact,
          mode: MeadowSceneMode.page,
          year: 2025,
          blooms: 129,
          sprouts: 6,
          weather: 'Clear skies',
        ),
        surface: surface,
      );

      expect(find.text('your meadow'), findsOneWidget);
      expect(find.text('Every day, a bloom'), findsOneWidget);
      expect(
        find.text(
          '129 blooms and 6 sprouts so far in 2025 · '
          'quietly filling in as the year goes',
        ),
        findsOneWidget,
      );
      expect(find.text('meadow study'), findsNothing);
      expect(find.text(meadowBackLabel), findsNothing);
      expect(find.text(meadowBackCompactLabel), findsNothing);
      expect(find.byType(GardenSkyClock), findsOneWidget);
      expect(find.byKey(meadowYearPickerButtonKey), findsOneWidget);
      expect(find.bySemanticsLabel(meadowFullScreenLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    "a past year's header says meadow study with its weather and a way back",
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      int backs = 0;
      for (final (bool compact, Size surface, String back, String other)
          in <(bool, Size, String, String)>[
            (false, _sidebarSurface, meadowBackLabel, meadowBackCompactLabel),
            (true, _bottomBarSurface, meadowBackCompactLabel, meadowBackLabel),
          ]) {
        await _pump(
          tester,
          _header(
            compact: compact,
            mode: MeadowSceneMode.study,
            year: 2024,
            blooms: 205,
            sprouts: 6,
            weather: 'Changeable skies',
            onBack: () => backs++,
          ),
          surface: surface,
        );

        expect(find.text('meadow study'), findsOneWidget);
        expect(find.text('Your meadow, 2024'), findsOneWidget);
        expect(
          find.text('Changeable skies · 205 blooms and 6 sprouts across 2024'),
          findsOneWidget,
        );
        expect(find.text('your meadow'), findsNothing);
        expect(find.text('Every day, a bloom'), findsNothing);
        expect(find.text(other), findsNothing);
        expect(
          tester.getSemantics(find.text(back)),
          isSemantics(label: back, isButton: true),
        );

        final int before = backs;
        await tester.tap(find.text(back));
        await tester.pump();

        expect(backs, before + 1);
      }
      semantics.dispose();
    },
  );
}
