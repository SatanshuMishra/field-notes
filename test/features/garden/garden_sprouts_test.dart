import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/model/garden_data.dart';
import 'package:field_notes/features/garden/model/meadow_layout.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/garden_harness.dart';

void main() {
  test('a journaled day without a mood grows a sprout', () {
    final List<Day> days = <Day>[
      dayOf('2026-09-23'),
      dayOf('2026-09-24', mood: Mood.grateful),
    ];
    const List<String> journaled = <String>['2026-09-23', '2026-09-24'];

    final List<String> sprouts = gardenSproutsForYear(days, journaled, 2026);
    expect(sprouts, <String>['2026-09-23']);

    final List<GardenBloomData> blooms = gardenBloomsForYear(days, 2026);
    expect(blooms, <GardenBloomData>[
      const GardenBloomData(date: '2026-09-24', mood: Mood.grateful),
    ]);

    final List<PlantedBloom> planted = layoutMeadow(
      blooms: blooms,
      sprouts: sprouts,
      size: const Size(400, 300),
      seed: 2026,
    );
    final List<PlantedBloom> plantedSprouts = planted
        .where((PlantedBloom p) => p.isSprout)
        .toList();
    expect(plantedSprouts, hasLength(1));
    expect(plantedSprouts.single.date, '2026-09-23');
  });

  testWidgets('the garden shows a sprout instead of the empty state', (
    WidgetTester tester,
  ) async {
    final int year = DateTime.now().year;
    final String date = '$year-09-23';
    await tester.pumpWidget(
      gardenHarness(
        const GardenScreen(),
        overrides: <Override>[
          allDaysProvider.overrideWith(
            (_) => Stream<List<Day>>.value(<Day>[dayOf(date)]),
          ),
          journaledDatesProvider.overrideWith(
            (_) => Stream<List<String>>.value(<String>[date]),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Your meadow is waiting'), findsNothing);
    final Finder chip = find.ancestor(
      of: find.text('Sprouts'),
      matching: find.byType(DecoratedBox),
    );
    expect(chip, findsOneWidget);
    expect(find.descendant(of: chip, matching: find.text('1')), findsOneWidget);
    expect(
      find.descendant(of: chip, matching: find.text('Sprouts')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
  });
}
