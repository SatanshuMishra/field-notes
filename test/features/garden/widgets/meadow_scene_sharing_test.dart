import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/garden_motion.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/render/meadow_stage_painter.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const int _meadowKey = 20280229;
const int _buildFrames = 6000;
const Size _phoneScreen = Size(411.4, 868.6);

final SkyScene _noon = skySceneAt(
  DateTime.utc(2028, 6, 21, 19, 30),
  53.55,
  -113.4667,
);

MeadowYear _leapYear() => MeadowYear.build(
  days: <Day>[
    for (int i = 0; i < 366; i++)
      dayOf(
        captureDateKey(DateTime(2028, 1, 1 + i)),
        mood: moodOrder[(i ~/ 5) % moodOrder.length],
      ),
  ],
  entryCounts: <String, int>{
    for (int i = 0; i < 366; i++)
      captureDateKey(DateTime(2028, 1, 1 + i)): 1 + i % 4,
  },
  year: 2028,
  today: DateTime(2029, 3, 1),
);

MeadowStage _stage(MeadowYear year, MeadowSceneMode mode, Key key) =>
    MeadowStage(
      key: key,
      year: year,
      seed: meadowSeed(_meadowKey, year.year),
      sky: _noon,
      morning: false,
      mode: mode,
      compact: true,
      motion: GardenMotionProfile.reduced,
      cover: true,
    );

List<MeadowStagePainter> _paintersOf(WidgetTester tester, Key key) =>
    <MeadowStagePainter>[
      for (final CustomPaint paint in tester.widgetList<CustomPaint>(
        find.descendant(
          of: find.byKey(key, skipOffstage: false),
          matching: find.byWidgetPredicate(
            (Widget widget) =>
                widget is CustomPaint && widget.painter is MeadowStagePainter,
            skipOffstage: false,
          ),
          skipOffstage: false,
        ),
      ))
        paint.painter! as MeadowStagePainter,
    ];

const Key _pageKey = ValueKey<String>('page');
const Key _fullKey = ValueKey<String>('full');

void main() {
  testWidgets(
    'the full-screen Meadow over the page shares the page scene images and '
    'the page keeps them when full screen closes',
    (WidgetTester tester) async {
      final MeadowYear year = _leapYear();
      tester.view.physicalSize = _phoneScreen;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
      final double screen = MeadowViewport.resolve(
        box: _phoneScreen,
        cover: true,
        focusX: 0,
      ).scale;
      MeadowStagePainter? sharp(Key key) {
        final MeadowStageState state = tester.state<MeadowStageState>(
          find.byKey(key, skipOffstage: false),
        );
        if (!state.debugIsReady) {
          return null;
        }
        for (final MeadowStagePainter painter in _paintersOf(tester, key)) {
          if ((painter.layers.density - screen).abs() < 1e-9 &&
              (painter.atlas.density - screen).abs() < 1e-9) {
            return painter;
          }
        }
        return null;
      }

      Future<MeadowStagePainter> settle(Key key) async {
        for (int i = 0; i < _buildFrames && sharp(key) == null; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 2)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        return sharp(key) ?? _paintersOf(tester, key).last;
      }

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          debugShowCheckedModeBanner: false,
          theme: fieldNotesTheme(platform: TargetPlatform.android),
          home: _stage(year, MeadowSceneMode.page, _pageKey),
        ),
      );
      final MeadowStagePainter page = await settle(_pageKey);

      navigator.currentState!.push(
        PageRouteBuilder<void>(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondary,
          ) => _stage(year, MeadowSceneMode.full, _fullKey),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final MeadowStagePainter full = await settle(_fullKey);
      expect(identical(page.layers, full.layers), isTrue);
      expect(identical(page.atlas, full.atlas), isTrue);

      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final MeadowStagePainter kept = _paintersOf(tester, _pageKey).last;
      expect(identical(kept.layers, page.layers), isTrue);
      expect(kept.layers.isReady, isTrue);
      expect(kept.atlas.isReady, isTrue);
    },
  );
}
