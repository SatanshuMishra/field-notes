import 'package:drift/drift.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'journaled_dates_provider.g.dart';

@riverpod
Stream<Map<String, int>> journalEntryCounts(Ref ref) {
  final AppDatabase db = ref.watch(databaseProvider);
  final Expression<int> count = db.entries.id.count();
  final query = db.selectOnly(db.days)
    ..addColumns(<Expression<Object>>[db.days.date, count])
    ..join(<Join<HasResultSet, dynamic>>[
      innerJoin(
        db.entries,
        db.entries.dayId.equalsExp(db.days.id),
        useColumns: false,
      ),
    ])
    ..where(db.days.deletedAt.isNull() & db.entries.deletedAt.isNull())
    ..groupBy(<Expression<Object>>[db.days.date]);
  return query.watch().map(
    (List<TypedResult> rows) => Map<String, int>.unmodifiable(<String, int>{
      for (final TypedResult row in rows)
        row.read(db.days.date)!: row.read(count)!,
    }),
  );
}

@riverpod
Stream<List<String>> journaledDates(Ref ref) async* {
  final Map<String, int> counts = await ref.watch(
    journalEntryCountsProvider.future,
  );
  yield counts.keys.toList();
}
