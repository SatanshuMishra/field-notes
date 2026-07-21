import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/search/search_entries_provider.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../state/state_test_support.dart';

void main() {
  group('searchAllEntriesProvider', () {
    test('streams only live entries, ordered by createdAt ascending',
        () async {
      final db = newTestDatabase();
      addTearDown(db.close);
      final container = newTestContainer(db);
      final repo = container.read(journalRepositoryProvider);

      final dayA = await repo.createDay(date: '2026-07-15');
      final e1 = await repo.createEntry(
        dayId: dayA.id,
        type: EntryType.text,
        textContent: 'first',
      );
      final gone = await repo.createEntry(
        dayId: dayA.id,
        type: EntryType.text,
        textContent: 'deleted',
      );
      await repo.softDeleteEntry(gone.id);

      final dayB = await repo.createDay(date: '2026-07-14');
      final e2 = await repo.createEntry(
        dayId: dayB.id,
        type: EntryType.voice,
        durationMs: 1000,
      );

      final sub = container.listen(
        searchAllEntriesProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      await pumpEventQueue();

      final List<Entry> entries =
          container.read(searchAllEntriesProvider).value ?? const <Entry>[];

      expect(entries.map((Entry e) => e.id).toList(), <String>[e1.id, e2.id]);
      expect(entries.every((Entry e) => e.deletedAt == null), isTrue);
    });
  });
}
