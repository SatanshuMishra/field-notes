import 'package:drift/drift.dart';
import 'package:field_notes/data/database/app_database.dart' show AppDatabase;
import 'package:field_notes/data/journal/journal_mappers.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_entries_provider.g.dart';

@riverpod
Stream<List<Entry>> searchAllEntries(Ref ref) {
  final AppDatabase db = ref.watch(databaseProvider);
  final query = db.select(db.entries)
    ..where((t) => t.deletedAt.isNull())
    ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
  return query.watch().map(
        (rows) => rows.map(toDomainEntry).toList(),
      );
}
