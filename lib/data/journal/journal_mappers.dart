import '../../domain/models/models.dart';
import '../database/app_database.dart' as db;
import 'journal_exceptions.dart';

Day toDomainDay(db.Day row) {
  final moodId = row.moodId;
  final mood = moodId == null ? null : Mood.fromId(moodId);
  if (moodId != null && mood == null) {
    throw MalformedRowException('unknown mood id "$moodId" for day ${row.id}');
  }
  return Day(
    id: row.id,
    date: row.date,
    mood: mood,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );
}

Entry toDomainEntry(db.Entry row) {
  final type = EntryType.fromId(row.type);
  if (type == null) {
    throw MalformedRowException(
      'unknown entry type "${row.type}" for entry ${row.id}',
    );
  }
  return Entry(
    id: row.id,
    dayId: row.dayId,
    type: type,
    textContent: row.textContent,
    mediaId: row.mediaId,
    thumbnailMediaId: row.thumbnailMediaId,
    durationMs: row.durationMs,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );
}

EntryPhoto toDomainEntryPhoto(db.EntryPhoto row) {
  return EntryPhoto(
    id: row.id,
    entryId: row.entryId,
    mediaId: row.mediaId,
    sortOrder: row.sortOrder,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );
}
