import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/model/garden_data.dart';
import 'package:field_notes/features/garden/model/meadow_key_provider.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/garden_harness.dart';

const String _sproutDate = '2026-09-23';

final DateTime _now = DateTime(2026, 9, 28, 12);

Future<void> _pumpSprout(WidgetTester tester) async {
  await tester.pumpWidget(
    gardenHarness(
      const GardenScreen(),
      overrides: <Override>[
        allDaysProvider.overrideWith(
          (Ref ref) => Stream<List<Day>>.value(<Day>[dayOf(_sproutDate)]),
        ),
        journalEntryCountsProvider.overrideWith(
          (Ref ref) => Stream<Map<String, int>>.value(const <String, int>{
            _sproutDate: 1,
          }),
        ),
        meadowKeyProvider.overrideWith((Ref ref) async => 24601),
        skyClockProvider.overrideWithValue(() => _now),
        skyLocationProvider.overrideWith(
          (Ref ref) async =>
              resolveSkyLocation('America/Edmonton', const Duration(hours: -6)),
        ),
      ],
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _openDetails(WidgetTester tester) async {
  await tester.tap(find.byKey(meadowDetailsButtonKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

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

    final MeadowYear year = MeadowYear.build(
      days: days,
      entryCounts: const <String, int>{'2026-09-23': 1, '2026-09-24': 2},
      year: 2026,
      today: _now,
    );
    final List<MeadowDay> grown = year.days.nonNulls.toList();
    expect(year.blooms, 1);
    expect(year.sprouts, 1);
    expect(
      grown.where((MeadowDay day) => day.isSprout).single.date,
      '2026-09-23',
    );
  });

  testWidgets('the garden shows a sprout instead of the empty state', (
    WidgetTester tester,
  ) async {
    await _pumpSprout(tester);

    expect(find.textContaining('Your meadow is waiting'), findsNothing);
    final MeadowStage stage = tester.widget<MeadowStage>(
      find.byType(MeadowStage),
    );
    expect(stage.year.sprouts, 1);
    expect(stage.year.blooms, 0);
    expect(find.text('0 blooms and 1 sprout so far in 2026'), findsOneWidget);

    await _openDetails(tester);
    expect(find.text('Sprout'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('one sprout reads 1 Sprout', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpSprout(tester);
    await _openDetails(tester);

    expect(find.text('Sprout'), findsOneWidget);
    expect(find.bySemanticsLabel('1 Sprout'), findsOneWidget);

    handle.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
