import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/search/search_day_view.dart';
import 'package:field_notes/features/search/search_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../state/state_test_support.dart';

void main() {
  group('search providers', () {
    test('searchQuery starts empty and updates', () {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(db);

      expect(container.read(searchQueryProvider), '');
      container.read(searchQueryProvider.notifier).update('rain');
      expect(container.read(searchQueryProvider), 'rain');
    });

    test('searchDayViews assembles reverse-chron views with counts and preview',
        () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(db);
      final repo = container.read(journalRepositoryProvider);

      final older = await repo.createDay(date: '2026-07-14');
      await repo.createEntry(
        dayId: older.id,
        type: EntryType.text,
        textContent: 'Sunny picnic',
      );
      final newer = await repo.createDay(date: '2026-07-15');
      await repo.createEntry(
        dayId: newer.id,
        type: EntryType.text,
        textContent: 'Rainy walk',
      );
      await repo.createEntry(
        dayId: newer.id,
        type: EntryType.voice,
        durationMs: 500,
      );

      final sub = container.listen(searchDayViewsProvider, (_, _) {},
          fireImmediately: true);
      addTearDown(sub.close);
      await pumpEventQueue();

      final List<SearchDayView> views = container.read(searchDayViewsProvider);
      expect(views.map((SearchDayView v) => v.date).toList(),
          <String>['2026-07-15', '2026-07-14']);
      expect(views.first.entryCount, 2);
      expect(views.first.preview, 'Rainy walk');
    });

    test('searchResults filters by the current query', () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(db);
      final repo = container.read(journalRepositoryProvider);

      final dayA = await repo.createDay(date: '2026-07-15');
      await repo.createEntry(
        dayId: dayA.id,
        type: EntryType.text,
        textContent: 'Rainy walk',
      );
      final dayB = await repo.createDay(date: '2026-07-14');
      await repo.createEntry(
        dayId: dayB.id,
        type: EntryType.text,
        textContent: 'Sunny picnic',
      );

      final sub = container.listen(searchResultsProvider, (_, _) {},
          fireImmediately: true);
      addTearDown(sub.close);
      await pumpEventQueue();

      expect(container.read(searchResultsProvider).length, 2);

      container.read(searchQueryProvider.notifier).update('picnic');
      expect(
        container.read(searchResultsProvider).map((SearchDayView v) => v.date),
        <String>['2026-07-14'],
      );
    });
  });
}
