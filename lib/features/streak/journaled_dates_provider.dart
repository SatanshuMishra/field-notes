import 'package:drift/drift.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'journaled_dates_provider.g.dart';

@riverpod
Stream<List<String>> journaledDates(Ref ref) {
  final AppDatabase db = ref.watch(databaseProvider);
  final query = db.select(db.days).join([
    innerJoin(db.entries, db.entries.dayId.equalsExp(db.days.id)),
  ])..where(db.days.deletedAt.isNull() & db.entries.deletedAt.isNull());
  return query.watch().map((rows) {
    final dates = <String>{};
    for (final row in rows) {
      dates.add(row.readTable(db.days).date);
    }
    return dates.toList();
  });
}
