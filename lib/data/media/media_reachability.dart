import '../database/app_database.dart';

Future<Set<String>> liveJournalMediaIds(AppDatabase database) async {
  final List<Entry> entries = await (database.select(
    database.entries,
  )..where((t) => t.deletedAt.isNull())).get();
  final List<EntryPhoto> photos = await (database.select(
    database.entryPhotos,
  )..where((t) => t.deletedAt.isNull())).get();
  return Set<String>.unmodifiable(<String>{
    for (final entry in entries) ...[?entry.mediaId, ?entry.thumbnailMediaId],
    for (final photo in photos) photo.mediaId,
  });
}
