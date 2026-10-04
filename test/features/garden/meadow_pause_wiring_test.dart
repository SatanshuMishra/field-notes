import 'dart:async';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/model/meadow_key_provider.dart';
import 'package:field_notes/features/garden/model/meadow_view_state.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_full_screen.dart';
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

final DateTime _noon = DateTime.utc(2026, 9, 28, 18);
final SkyLocation _edmonton = resolveSkyLocation(
  'America/Edmonton',
  const Duration(hours: -6),
);

final List<Day> _days = <Day>[
  dayOf('2026-03-01', mood: Mood.happy),
  dayOf('2026-03-02', mood: Mood.calm),
];

Future<void> _pump(
  WidgetTester tester, {
  required Stream<AppSettings> settings,
}) async {
  tester.view.physicalSize = _window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    gardenHarness(
      const GardenScreen(),
      platform: TargetPlatform.macOS,
      settings: settings,
      overrides: <Override>[
        allDaysProvider.overrideWith(
          (Ref ref) => Stream<List<Day>>.value(_days),
        ),
        journalEntryCountsProvider.overrideWith(
          (Ref ref) => Stream<Map<String, int>>.value(const <String, int>{}),
        ),
        meadowKeyProvider.overrideWith(
          (Ref ref) => Future<int>.value(_meadowKey),
        ),
        skyClockProvider.overrideWithValue(() => _noon),
        skyLocationProvider.overrideWith((Ref ref) async => _edmonton),
      ],
    ),
  );
  await tester.pump();
  await tester.pump();
}

MeadowStage _stage(WidgetTester tester) =>
    tester.widget<MeadowStage>(find.byType(MeadowStage));

Future<MeadowStage> _fullScreenStage(
  WidgetTester tester, {
  required bool compact,
}) async {
  final BuildContext page = tester.element(find.byType(GardenScreen));
  final MeadowStage shown = _stage(tester);
  unawaited(
    openMeadowFullScreen(
      page,
      request: MeadowFullScreenRequest(
        year: shown.year.year,
        hourMinutes: null,
        growthPoint: shown.resolvedGrowthPoint,
      ),
      year: shown.year,
      seed: shown.seed,
      compact: compact,
    ),
  );
  await tester.pump();
  await tester.pump(meadowFullScreenFade + _frame);
  final MeadowStage full = _stage(tester);
  Navigator.of(page, rootNavigator: true).pop();
  await tester.pump();
  await tester.pump(meadowFullScreenFade + _frame);
  return full;
}

Future<void> _expectStagesPause(WidgetTester tester, bool pauses) async {
  final MeadowStage page = _stage(tester);
  expect(page.mode, MeadowSceneMode.page);
  expect(page.pausesWhenInactive, pauses, reason: 'the Meadow page');
  for (final bool compact in <bool>[true, false]) {
    final MeadowStage full = await _fullScreenStage(tester, compact: compact);
    expect(full.mode, MeadowSceneMode.full);
    expect(
      full.pausesWhenInactive,
      pauses,
      reason: compact ? 'the phone full screen' : 'the desktop full screen',
    );
    expect(_stage(tester).mode, MeadowSceneMode.page);
  }
}

void main() {
  testWidgets(
    'the Meadow page and full screen follow the background pause setting',
    (WidgetTester tester) async {
      final StreamController<AppSettings> settings =
          StreamController<AppSettings>();
      addTearDown(settings.close);
      settings.add(
        AppSettings.defaults.copyWith(meadowPausesWhenInactive: false),
      );

      await _pump(tester, settings: settings.stream);
      await _expectStagesPause(tester, false);

      settings.add(AppSettings.defaults);
      await tester.pump();
      await tester.pump();
      await _expectStagesPause(tester, true);
    },
  );
}
