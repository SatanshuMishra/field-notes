import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/garden_motion.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const int _meadowKey = 20280229;
const int _buildFrames = 6000;
const Size _phoneScreen = Size(411.4, 868.6);
const Duration _settle = Duration(milliseconds: 400);
const Duration _moment = Duration(milliseconds: 100);

final SkyScene _noon = skySceneAt(
  DateTime.utc(2028, 6, 21, 19, 30),
  53.55,
  -113.4667,
);

MeadowYear _sampleYear() => MeadowYear.build(
  days: <Day>[
    for (int i = 0; i < 40; i++)
      dayOf(
        captureDateKey(DateTime(2028, 1, 1 + i)),
        mood: moodOrder[i % moodOrder.length],
      ),
  ],
  entryCounts: const <String, int>{},
  year: 2028,
  today: DateTime(2029, 3, 1),
);

void _moveLifecycle(WidgetTester tester, List<AppLifecycleState> states) {
  for (final AppLifecycleState state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

Future<MeadowStageState> _pumpStage(
  WidgetTester tester, {
  required bool pausesWhenInactive,
}) async {
  final MeadowYear year = _sampleYear();
  tester.view.physicalSize = _phoneScreen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: TargetPlatform.android),
      home: MeadowStage(
        year: year,
        seed: meadowSeed(_meadowKey, year.year),
        sky: _noon,
        morning: false,
        mode: MeadowSceneMode.page,
        compact: true,
        motion: GardenMotionProfile.full,
        cover: true,
        pausesWhenInactive: pausesWhenInactive,
      ),
    ),
  );
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
  await tester.pump(_settle);
  return state;
}

void main() {
  testWidgets(
    'a Meadow set to keep moving animates while Field Notes is visible but '
    'not focused, and still stops once it is hidden',
    (WidgetTester tester) async {
      final MeadowStageState state = await _pumpStage(
        tester,
        pausesWhenInactive: false,
      );
      expect(state.debugIsTicking, isTrue);

      _moveLifecycle(tester, const <AppLifecycleState>[
        AppLifecycleState.inactive,
      ]);
      await tester.pump();
      expect(state.debugIsTicking, isTrue);
      final double unfocused = state.debugTime;
      await tester.pump(_moment);
      expect(state.debugTime, greaterThan(unfocused));

      _moveLifecycle(tester, const <AppLifecycleState>[
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);
      await tester.pump();
      expect(state.debugIsTicking, isFalse);
      final double hidden = state.debugTime;
      await tester.pump(const Duration(seconds: 1));
      expect(state.debugTime, hidden);

      _moveLifecycle(tester, const <AppLifecycleState>[
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
      ]);
      await tester.pump();
      expect(state.debugIsTicking, isTrue);
      _moveLifecycle(tester, const <AppLifecycleState>[
        AppLifecycleState.resumed,
      ]);
      await tester.pump();
      expect(state.debugIsTicking, isTrue);
    },
  );

  testWidgets(
    'a Meadow left at the default pauses while Field Notes is not focused',
    (WidgetTester tester) async {
      final MeadowStageState state = await _pumpStage(
        tester,
        pausesWhenInactive: true,
      );
      expect(state.debugIsTicking, isTrue);
      _moveLifecycle(tester, const <AppLifecycleState>[
        AppLifecycleState.inactive,
      ]);
      await tester.pump();
      expect(state.debugIsTicking, isFalse);
      _moveLifecycle(tester, const <AppLifecycleState>[
        AppLifecycleState.resumed,
      ]);
      await tester.pump();
      expect(state.debugIsTicking, isTrue);
    },
  );
}
