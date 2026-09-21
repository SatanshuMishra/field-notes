import 'dart:async';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/features/day_detail/day_detail.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/search/search_day_tile.dart';
import 'package:field_notes/features/search/search_entries_provider.dart';
import 'package:field_notes/features/search/search_screen.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../state/state_test_support.dart';
import 'support/search_harness.dart';

class _FakeResolver implements MediaResolver {
  const _FakeResolver();

  @override
  ResolvedMedia? resolved(String? mediaId) => null;

  @override
  Future<ResolvedMedia> resolve(String? mediaId) async =>
      const ResolvedMedia.missing();
}

void main() {
  testWidgets('shows a loading caption before days arrive',
      (WidgetTester tester) async {
    final StreamController<List<Day>> controller =
        StreamController<List<Day>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      searchHarness(
        const SearchScreen(),
        overrides: <Override>[
          allDaysProvider.overrideWith((_) => controller.stream),
        ],
      ),
    );

    expect(find.text('Loading your days…'), findsOneWidget);
  });

  testWidgets('shows the empty-journal state when there are no days',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      searchHarness(
        const SearchScreen(),
        overrides: <Override>[
          allDaysProvider.overrideWith((_) => Stream<List<Day>>.value(
                const <Day>[],
              )),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(EmptyStatePlaceholder), findsOneWidget);
    expect(find.textContaining('No days yet'), findsOneWidget);
  });

  testWidgets('renders a tile per day with count and preview',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      searchHarness(
        const SearchScreen(),
        overrides: <Override>[
          allDaysProvider.overrideWith((_) => Stream<List<Day>>.value(<Day>[
                dayOf('2026-07-15', id: 'd1', mood: Mood.happy),
                dayOf('2026-07-14', id: 'd2', mood: Mood.calm),
              ])),
          searchAllEntriesProvider.overrideWith(
            (_) => Stream<List<Entry>>.value(<Entry>[
              entryOf(dayId: 'd1', id: 'e1', textContent: 'Rainy walk'),
              entryOf(dayId: 'd2', id: 'e2', textContent: 'Sunny picnic'),
            ]),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(SearchDayTile), findsNWidgets(2));
    expect(find.text('Rainy walk'), findsOneWidget);
    expect(find.text('Sunny picnic'), findsOneWidget);
  });

  testWidgets('filters the list to matching days, then shows no-match state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      searchHarness(
        const SearchScreen(),
        overrides: <Override>[
          allDaysProvider.overrideWith((_) => Stream<List<Day>>.value(<Day>[
                dayOf('2026-07-15', id: 'd1', mood: Mood.happy),
                dayOf('2026-07-14', id: 'd2', mood: Mood.calm),
              ])),
          searchAllEntriesProvider.overrideWith(
            (_) => Stream<List<Entry>>.value(<Entry>[
              entryOf(dayId: 'd1', id: 'e1', textContent: 'Rainy walk'),
              entryOf(dayId: 'd2', id: 'e2', textContent: 'Sunny picnic'),
            ]),
          ),
        ],
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'picnic');
    await tester.pump();
    expect(find.byType(SearchDayTile), findsOneWidget);
    expect(find.text('Sunny picnic'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.byType(SearchDayTile), findsNothing);
    expect(find.textContaining('No days match'), findsOneWidget);
  });

  testWidgets('tapping a day opens the Day-detail modal',
      (WidgetTester tester) async {
    final db = newTestDatabase();
    addTearDown(db.close);
    final container = newTestContainer(
      db,
      overrides: <Override>[
        dayDetailMediaResolverProvider
            .overrideWith((_) async => const _FakeResolver()),
      ],
    );
    final JournalRepository repo = container.read(journalRepositoryProvider);
    final day = await repo.createDay(date: '2026-07-15');
    await repo.createEntry(
      dayId: day.id,
      type: EntryType.text,
      textContent: 'Rainy walk',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: SearchScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SearchDayTile).first);
    await tester.pumpAndSettle();

    expect(find.byType(DayDetailPanel), findsOneWidget);
  });
}
