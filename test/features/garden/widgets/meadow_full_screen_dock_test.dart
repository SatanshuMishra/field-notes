import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/model/meadow_key_provider.dart';
import 'package:field_notes/features/garden/model/meadow_view_state.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_full_screen.dart';
import 'package:field_notes/features/garden/widgets/meadow_glass_popover.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const Size _phone = Size(384, 832);
const Size _window = Size(1140, 820);
const double _gestureBar = 24;
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

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required TargetPlatform platform,
}) async {
  final bool phone = platform == TargetPlatform.android;
  tester.view.physicalSize = phone ? _phone : _window;
  tester.view.devicePixelRatio = 1;
  if (phone) {
    tester.view.padding = const FakeViewPadding(top: 34, bottom: _gestureBar);
    tester.view.viewPadding = const FakeViewPadding(
      top: 34,
      bottom: _gestureBar,
    );
  }
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    gardenHarness(
      const GardenScreen(),
      platform: platform,
      overrides: <Override>[
        allDaysProvider.overrideWith(
          (Ref ref) => Stream<List<Day>>.value(_days),
        ),
        journalEntryCountsProvider.overrideWith(
          (Ref ref) => Stream<Map<String, int>>.value(const <String, int>{}),
        ),
        meadowKeyProvider.overrideWith((Ref ref) async => 24601),
        skyClockProvider.overrideWithValue(() => _noon),
        skyLocationProvider.overrideWith((Ref ref) async => _edmonton),
      ],
    ),
  );
  await tester.pump();
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(GardenScreen)));
}

Future<void> _enter(WidgetTester tester) async {
  await tester.tap(find.byKey(meadowFullScreenButtonKey));
  await tester.pump();
  await tester.pump();
  await tester.pump(meadowFullScreenFade + _frame);
}

void main() {
  testWidgets(
    'full screen puts its controls in a bottom row on the phone and the dock '
    'on macOS',
    (WidgetTester tester) async {
      final ProviderContainer phone = await _pump(
        tester,
        platform: TargetPlatform.android,
      );
      await _enter(tester);
      expect(phone.read(meadowViewStateProvider).fullScreen, isNotNull);
      expect(
        tester.widget<MeadowStage>(find.byType(MeadowStage)).mode,
        MeadowSceneMode.full,
      );

      final Rect play = tester.getRect(find.byKey(meadowFullScreenPlayKey));
      final Rect leave = tester.getRect(find.byKey(meadowFullScreenCloseKey));
      final double rowBottom = _phone.height - _gestureBar - 12;
      expect(play.height, 48);
      expect(leave.size, const Size(48, 48));
      expect(play.bottom, rowBottom);
      expect(leave.bottom, rowBottom);
      expect(play.left, 12);
      expect(leave.right, _phone.width - 12);
      expect(leave.left, closeTo(play.right + 8, 0.01));
      for (final Key key in <Key>[
        meadowFullScreenPlayKey,
        meadowFullScreenCloseKey,
      ]) {
        final GlassSurface glass = tester.widget<GlassSurface>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(GlassSurface),
          ),
        );
        expect(glass.tone, GlassTone.scene);
        expect(glass.borderRadius, const BorderRadius.all(Radius.circular(14)));
      }
      expect(
        find.descendant(
          of: find.byKey(meadowFullScreenPlayKey),
          matching: find.text('Play the day'),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Play the day'), findsOneWidget);
      expect(find.byTooltip('Leave full screen'), findsOneWidget);
      expect(find.bySemanticsLabel('Leave full screen'), findsOneWidget);

      final Rect label = tester.getRect(find.byKey(meadowFullScreenTitleKey));
      expect(find.text('2026'), findsOneWidget);
      expect(label.left, 14);
      expect(label.top, 40);
      final Iterable<Rect> controls = tester
          .widgetList<MeadowGlassButton>(find.byType(MeadowGlassButton))
          .map(
            (MeadowGlassButton button) => tester.getRect(find.byWidget(button)),
          );
      expect(controls, hasLength(2));
      for (final Rect control in controls) {
        expect(control.top, greaterThan(_phone.height / 2));
      }
      expect(find.byKey(meadowDockKey), findsNothing);

      await tester.tap(find.byKey(meadowFullScreenCloseKey));
      await tester.pump();
      await tester.pump(meadowFullScreenFade + _frame);
      expect(phone.read(meadowViewStateProvider).fullScreen, isNull);
      await tester.pumpWidget(const SizedBox());

      final ProviderContainer mac = await _pump(
        tester,
        platform: TargetPlatform.macOS,
      );
      expect(find.byTooltip('Full screen (F)'), findsOneWidget);
      await _enter(tester);
      expect(mac.read(meadowViewStateProvider).fullScreen, isNotNull);
      expect(
        tester.widget<MeadowStage>(find.byType(MeadowStage)).mode,
        MeadowSceneMode.full,
      );
      expect(find.byKey(meadowDockKey), findsOneWidget);
      expect(find.byTooltip('Exit full screen (F)'), findsOneWidget);
      expect(find.byTooltip('Full screen (F)'), findsNothing);
      expect(find.bySemanticsLabel(meadowExitFullScreenLabel), findsOneWidget);
      expect(
        tester
            .widget<MeadowGlyph>(
              find.descendant(
                of: find.byKey(meadowFullScreenButtonKey),
                matching: find.byType(MeadowGlyph),
              ),
            )
            .path,
        same(meadowCollapseCorners),
      );
      expect(find.byKey(meadowFullScreenCloseKey), findsNothing);
      expect(find.byKey(meadowFullScreenPlayKey), findsNothing);
      expect(find.text('Every day, a bloom'), findsOneWidget);
      final Rect dock = tester.getRect(find.byKey(meadowDockKey));
      expect(dock.center.dx, closeTo(_window.width / 2, 0.5));
      expect(dock.bottom, _window.height - 20);

      await tester.tap(find.byKey(meadowFullScreenButtonKey));
      await tester.pump();
      await tester.pump(meadowFullScreenFade + _frame);
      expect(mac.read(meadowViewStateProvider).fullScreen, isNull);
      expect(find.byTooltip('Full screen (F)'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
