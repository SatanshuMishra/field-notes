import 'package:drift/drift.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'journaled_dates_provider.g.dart';

@riverpod
Stream<Map<String, int>> journalEntryCounts(Ref ref) {
  final AppDatabase db = ref.watch(databaseProvider);
  final query = db.select(db.days).join([
    innerJoin(db.entries, db.entries.dayId.equalsExp(db.days.id)),
  ])..where(db.days.deletedAt.isNull() & db.entries.deletedAt.isNull());
  return query.watch().map((rows) {
    final counts = <String, int>{};
    for (final row in rows) {
      final String date = row.readTable(db.days).date;
      counts[date] = (counts[date] ?? 0) + 1;
    }
    return Map<String, int>.unmodifiable(counts);
  });
}

@riverpod
Stream<List<String>> journaledDates(Ref ref) async* {
  final Map<String, int> counts = await ref.watch(
    journalEntryCountsProvider.future,
  );
  yield counts.keys.toList();
}
