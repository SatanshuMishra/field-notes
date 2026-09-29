import 'package:field_notes/design/format/clock_format.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/paint/meadow_painter.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_scene.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

final DateTime _noon = DateTime.utc(2026, 9, 28, 18);
final SkyLocation _edmonton = resolveSkyLocation(
  'America/Edmonton',
  const Duration(hours: -6),
);

final List<Day> _twoBloomsAndASprout = <Day>[
  dayOf('2026-03-01', mood: Mood.happy),
  dayOf('2026-03-02', mood: Mood.calm),
  dayOf('2026-03-03'),
];

Future<void> _pumpGarden(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Size size,
  List<Day> days = const <Day>[],
  List<String> journaled = const <String>[],
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
          child: const GardenScreen(year: 2026),
        ),
      ),
      platform: platform,
      overrides: <Override>[
        allDaysProvider.overrideWith((_) => Stream<List<Day>>.value(days)),
        journaledDatesProvider.overrideWith(
          (_) => Stream<List<String>>.value(journaled),
        ),
        skyClockProvider.overrideWithValue(() => _noon),
        skyLocationProvider.overrideWith((_) async => _edmonton),
        skyDebugControlsProvider.overrideWithValue(false),
      ],
    ),
  );
  await tester.pump();
  await tester.pump();
}

String _clock(WidgetTester tester, DateTime instant) => formatClock(
  tester.element(find.byType(GardenView)),
  TimeOfDay.fromDateTime(instant.toLocal()),
);

MeadowPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(MeadowScene),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as MeadowPainter;

void main() {
  testWidgets(
    'desktop page shows the header, day count, chips, clock, next events and captions',
    (WidgetTester tester) async {
      await _pumpGarden(
        tester,
        platform: TargetPlatform.macOS,
        size: const Size(1140, 766),
        days: _twoBloomsAndASprout,
        journaled: const <String>['2026-03-03'],
      );

      expect(find.text('your garden'), findsOneWidget);
      expect(find.text('Every day, a bloom'), findsOneWidget);
      expect(
        find.text(
          '3 days planted in 2026 · quietly filling in as the year goes',
        ),
        findsOneWidget,
      );
      expect(find.text(_clock(tester, _noon)), findsOneWidget);
      final String sunset = _clock(tester, DateTime.utc(2026, 9, 29, 1, 17));
      final String moonrise = _clock(tester, DateTime.utc(2026, 9, 29, 1, 29));
      expect(find.text('sunset $sunset · moonrise $moonrise'), findsOneWidget);
      expect(find.text('Happy'), findsOneWidget);
      expect(find.text('Calm'), findsOneWidget);
      expect(find.text('1 Sprout'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byType(MoodTallyChips)).dy,
        lessThan(tester.getTopLeft(find.byType(MeadowScene)).dy),
      );
      expect(
        tester.getTopLeft(find.text('Every day, a bloom')).dy,
        lessThan(tester.getTopLeft(find.byType(MoodTallyChips)).dy),
      );

      expect(find.text('Sep 2026 · still growing'), findsOneWidget);
      expect(find.text('sky over Edmonton · waning gibbous'), findsOneWidget);
      final Rect card = tester.getRect(find.byType(MeadowScene));
      expect(card.height, greaterThanOrEqualTo(452));
      expect(
        tester.getBottomLeft(find.text('Sep 2026 · still growing')).dy,
        closeTo(card.bottom - 12, 1),
      );
      expect(
        tester
            .getBottomRight(find.text('sky over Edmonton · waning gibbous'))
            .dx,
        closeTo(card.right - 16, 1),
      );
      expect(
        tester.widget<ClipRRect>(find.byType(ClipRRect).first).borderRadius,
        const BorderRadius.all(Radius.circular(20)),
      );
      expect(
        tester.widget<MeadowScene>(find.byType(MeadowScene)).compact,
        false,
      );
      expect(
        tester.widget<MeadowScene>(find.byType(MeadowScene)).sky,
        skySceneAt(_noon, _edmonton.latitude, _edmonton.longitude),
      );
    },
  );

  testWidgets(
    'phone page shows the compact header, the next sun event and the right caption',
    (WidgetTester tester) async {
      await _pumpGarden(
        tester,
        platform: TargetPlatform.android,
        size: const Size(393, 700),
        days: _twoBloomsAndASprout,
        journaled: const <String>['2026-03-03'],
      );

      expect(find.text('your garden'), findsOneWidget);
      expect(find.text('Every day, a bloom'), findsOneWidget);
      expect(find.text('3 days planted in 2026'), findsOneWidget);
      expect(find.textContaining('quietly filling in'), findsNothing);
      expect(find.text(_clock(tester, _noon)), findsOneWidget);
      final String sunset = _clock(tester, DateTime.utc(2026, 9, 29, 1, 17));
      expect(find.text('sunset $sunset'), findsOneWidget);
      expect(find.textContaining('moonrise'), findsNothing);
      expect(
        tester.getBottomLeft(find.byType(MoodTallyChips)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text('sunset $sunset')).dy),
      );

      expect(find.text('sky over Edmonton · waning gibbous'), findsOneWidget);
      expect(find.textContaining('still growing'), findsNothing);
      final Rect card = tester.getRect(find.byType(MeadowScene));
      expect(card.height, greaterThanOrEqualTo(320));
      expect(
        tester.getBottomRight(find.text('sky over Edmonton · waning gibbous')),
        offsetMoreOrLessEquals(
          Offset(card.right - 12, card.bottom - 9),
          epsilon: 1,
        ),
      );
      expect(
        tester.widget<ClipRRect>(find.byType(ClipRRect).first).borderRadius,
        const BorderRadius.all(Radius.circular(16)),
      );
      expect(
        tester.widget<MeadowScene>(find.byType(MeadowScene)).compact,
        true,
      );
    },
  );

  testWidgets(
    'an empty garden shows the header, the sky over grass and the waiting message',
    (WidgetTester tester) async {
      await _pumpGarden(
        tester,
        platform: TargetPlatform.macOS,
        size: const Size(1140, 766),
      );

      expect(find.text('your garden'), findsOneWidget);
      expect(find.text('Every day, a bloom'), findsOneWidget);
      expect(
        find.text(
          '0 days planted in 2026 · quietly filling in as the year goes',
        ),
        findsOneWidget,
      );
      expect(find.byType(MoodTallyChips), findsNothing);
      expect(find.byType(MeadowScene), findsOneWidget);
      expect(_painter(tester).layout.plants, isEmpty);
      expect(_painter(tester).layout.tufts, isNotEmpty);

      final Finder message = find.text(
        'Your meadow is waiting. Every day you journal plants a bloom here.',
      );
      expect(message, findsOneWidget);
      expect(
        tester.widget<Text>(message).style?.color,
        const Color.fromRGBO(60, 48, 36, 0.72),
      );
      expect(
        tester.widget<Text>(message).style?.color,
        skySceneAt(
          _noon,
          _edmonton.latitude,
          _edmonton.longitude,
        ).captionColour,
      );
      expect(_painter(tester).animate, isFalse);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      final Rect card = tester.getRect(find.byType(MeadowScene));
      expect(card.contains(tester.getCenter(message)), isTrue);
      expect(
        tester.getCenter(message).dy,
        greaterThan(card.top + card.height * 0.29),
      );
    },
  );

  testWidgets('degrades the scene when the platform disables animations', (
    WidgetTester tester,
  ) async {
    await _pumpGarden(
      tester,
      platform: TargetPlatform.macOS,
      size: const Size(1140, 766),
      days: _twoBloomsAndASprout,
      disableAnimations: true,
    );

    expect(_painter(tester).animate, isFalse);
    expect(tester.widget<MeadowScene>(find.byType(MeadowScene)).motion, isNull);
  });
}
