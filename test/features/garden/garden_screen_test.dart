import 'dart:async';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_scene.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/garden_harness.dart';

void main() {
  testWidgets('shows a loading caption before days arrive', (
    WidgetTester tester,
  ) async {
    final StreamController<List<Day>> controller =
        StreamController<List<Day>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      gardenHarness(
        const GardenScreen(year: 2026),
        overrides: <Override>[
          journaledDatesProvider.overrideWith(
            (_) => Stream<List<String>>.value(const <String>[]),
          ),
          allDaysProvider.overrideWith((_) => controller.stream),
        ],
      ),
    );

    expect(find.text('Growing your garden…'), findsOneWidget);
  });

  testWidgets('renders the garden view for the target year', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      gardenHarness(
        const GardenScreen(year: 2026),
        overrides: <Override>[
          journaledDatesProvider.overrideWith(
            (_) => Stream<List<String>>.value(const <String>[]),
          ),
          allDaysProvider.overrideWith(
            (_) => Stream<List<Day>>.value(<Day>[
              dayOf('2026-03-01', mood: Mood.happy),
              dayOf('2026-03-02', mood: Mood.calm),
              dayOf('2025-12-31', mood: Mood.sad),
            ]),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(GardenView), findsOneWidget);
    expect(find.byType(MoodTallyChips), findsOneWidget);
    expect(find.text('Happy'), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget);
    expect(find.text('Sad'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows the waiting meadow when the year has no blooms', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      gardenHarness(
        const GardenScreen(year: 2026),
        overrides: <Override>[
          journaledDatesProvider.overrideWith(
            (_) => Stream<List<String>>.value(const <String>[]),
          ),
          allDaysProvider.overrideWith(
            (_) => Stream<List<Day>>.value(<Day>[dayOf('2026-04-01')]),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.textContaining('Your meadow is waiting'), findsOneWidget);
    expect(find.byType(MeadowScene), findsOneWidget);
  });

  testWidgets('loading and error keep the garden header', (
    WidgetTester tester,
  ) async {
    final StreamController<List<Day>> controller =
        StreamController<List<Day>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      gardenHarness(
        const GardenScreen(year: 2026),
        platform: TargetPlatform.macOS,
        overrides: <Override>[
          journaledDatesProvider.overrideWith(
            (_) => Stream<List<String>>.value(const <String>[]),
          ),
          allDaysProvider.overrideWith((_) => controller.stream),
          skyClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 9, 28, 18),
          ),
          skyLocationProvider.overrideWith(
            (_) async => resolveSkyLocation(
              'America/Edmonton',
              const Duration(hours: -6),
            ),
          ),
          skyDebugControlsProvider.overrideWithValue(false),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('your garden'), findsOneWidget);
    expect(find.text('Every day, a bloom'), findsOneWidget);
    expect(find.text('Growing your garden…'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Growing your garden…')).dy,
      greaterThan(tester.getBottomLeft(find.text('Every day, a bloom')).dy),
    );
    expect(find.byType(GardenView), findsNothing);

    controller.addError(Exception('boom'));
    await tester.pump();
    await tester.pump();

    expect(find.text('your garden'), findsOneWidget);
    expect(find.text('Every day, a bloom'), findsOneWidget);
    expect(
      find.text('Your garden could not be loaded right now.'),
      findsOneWidget,
    );
    expect(find.text('Growing your garden…'), findsNothing);
    expect(
      tester
          .getTopLeft(find.text('Your garden could not be loaded right now.'))
          .dy,
      greaterThan(tester.getBottomLeft(find.text('Every day, a bloom')).dy),
    );
  });

  testWidgets('surfaces a friendly message on error', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      gardenHarness(
        const GardenScreen(year: 2026),
        overrides: <Override>[
          journaledDatesProvider.overrideWith(
            (_) => Stream<List<String>>.value(const <String>[]),
          ),
          allDaysProvider.overrideWith(
            (_) => Stream<List<Day>>.error(Exception('boom')),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(EmptyStatePlaceholder), findsOneWidget);
    expect(find.textContaining('could not be loaded'), findsOneWidget);
  });

  testWidgets('surfaces the error even after a prior successful emission', (
    WidgetTester tester,
  ) async {
    final StreamController<List<Day>> controller =
        StreamController<List<Day>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      gardenHarness(
        const GardenScreen(year: 2026),
        overrides: <Override>[
          journaledDatesProvider.overrideWith(
            (_) => Stream<List<String>>.value(const <String>[]),
          ),
          allDaysProvider.overrideWith((_) => controller.stream),
        ],
      ),
    );

    controller.add(<Day>[dayOf('2026-03-01', mood: Mood.happy)]);
    await tester.pump();

    expect(find.byType(GardenView), findsOneWidget);

    controller.addError(Exception('boom'));
    await tester.pump();

    expect(find.byType(GardenView), findsNothing);
    expect(find.byType(EmptyStatePlaceholder), findsOneWidget);
    expect(find.textContaining('could not be loaded'), findsOneWidget);
  });
}
