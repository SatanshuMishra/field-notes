import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/features/day_detail/day_detail.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/search/search_day_tile.dart';
import 'package:field_notes/features/search/search_day_view.dart';
import 'package:field_notes/features/search/search_filter.dart';
import 'package:field_notes/features/search/search_screen.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../state/state_test_support.dart';
import 'support/search_harness.dart';

const String _harbourWalk =
    'Harbour walk\n\nThe ferry left late and the gulls followed it out.';

const String _beachPhotos =
    'Photos from the beach\n\nThe tide was out and the sand was warm.\n'
    'We found three shells by the rocks.';

class _FakeResolver implements MediaResolver {
  const _FakeResolver();

  @override
  ResolvedMedia? resolved(String? mediaId) => null;

  @override
  Future<ResolvedMedia> resolve(String? mediaId) async =>
      const ResolvedMedia.missing();
}

void main() {
  test('a result previews the entry that matched', () {
    final List<SearchDayView> results = filterSearchDays(
      buildSearchDayViews(
        <Day>[dayOf('2026-09-20', id: 'd1')],
        <Entry>[
          entryOf(
            dayId: 'd1',
            id: 'harbour',
            textContent: _harbourWalk,
            createdAt: 1,
          ),
          entryOf(
            dayId: 'd1',
            id: 'beach',
            textContent: _beachPhotos,
            createdAt: 2,
          ),
        ],
      ),
      'shells',
    );

    expect(results, hasLength(1));
    expect(results.single.preview, contains('shells'));
  });

  testWidgets('opening a result focuses the matching entry',
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
    final day = await repo.createDay(date: '2026-09-20');
    await repo.createEntry(
      dayId: day.id,
      type: EntryType.text,
      textContent: _harbourWalk,
    );
    final Entry beach = await repo.createEntry(
      dayId: day.id,
      type: EntryType.text,
      textContent: _beachPhotos,
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

    await tester.enterText(find.byType(TextField), 'shells');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SearchDayTile).first);
    await tester.pumpAndSettle();

    final DayDetailPanel panel =
        tester.widget<DayDetailPanel>(find.byType(DayDetailPanel));
    expect(panel.focusEntryId, beach.id);
  });
}
