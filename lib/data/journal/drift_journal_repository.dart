import '../../domain/models/models.dart';
import '../../domain/repositories/journal_repository.dart';
import '../database/app_database.dart' show AppDatabase;
import '../database/ids.dart';
import 'days_dao.dart';
import 'entries_dao.dart';
import 'entry_photos_dao.dart';
import 'journal_exceptions.dart';
import 'journal_mappers.dart';

class DriftJournalRepository implements JournalRepository {
  DriftJournalRepository(
    AppDatabase db, {
    String Function()? idGenerator,
    int Function()? clock,
  })  : _db = db,
        _newId = idGenerator ?? newId,
        _clock = clock ?? _systemClock,
        _days = DaysDao(db),
        _entries = EntriesDao(db),
        _photos = EntryPhotosDao(db);

  final AppDatabase _db;
  final String Function() _newId;
  final int Function() _clock;
  final DaysDao _days;
  final EntriesDao _entries;
  final EntryPhotosDao _photos;

  @override
  Future<Day> createDay({required String date, Mood? mood}) {
    return _db.transaction(() async {
      final existing = await _days.activeDayForDate(date);
      if (existing != null) {
        throw DuplicateDayException(date);
      }
      final now = _clock();
      final row = await _days.insertDay(
        id: _newId(),
        date: date,
        moodId: mood?.id,
        createdAt: now,
        updatedAt: now,
      );
      return toDomainDay(row);
    });
  }

  @override
  Future<Day?> dayById(String id) async {
    final row = await _days.dayById(id);
    return row == null ? null : toDomainDay(row);
  }

  @override
  Future<Day?> activeDayForDate(String date) async {
    final row = await _days.activeDayForDate(date);
    return row == null ? null : toDomainDay(row);
  }

  @override
  Future<Day> ensureDayForDate(String date) {
    return _db.transaction(() async {
      final existing = await _days.activeDayForDate(date);
      if (existing != null) {
        return toDomainDay(existing);
      }
      final now = _clock();
      final row = await _days.insertDay(
        id: _newId(),
        date: date,
        moodId: null,
        createdAt: now,
        updatedAt: now,
      );
      return toDomainDay(row);
    });
  }

  @override
  Future<Day> setMoodForDate({required String date, Mood? mood}) {
    return _db.transaction(() async {
      final existing = await _days.activeDayForDate(date);
      final now = _clock();
      if (existing == null) {
        final row = await _days.insertDay(
          id: _newId(),
          date: date,
          moodId: mood?.id,
          createdAt: now,
          updatedAt: now,
        );
        return toDomainDay(row);
      }
      await _days.updateMood(id: existing.id, moodId: mood?.id, updatedAt: now);
      final refreshed = await _days.dayById(existing.id);
      return toDomainDay(refreshed!);
    });
  }

  @override
  Future<void> setMood({required String dayId, Mood? mood}) async {
    await _days.updateMood(id: dayId, moodId: mood?.id, updatedAt: _clock());
  }

  @override
  Future<void> softDeleteDay(String id) async {
    await _days.softDelete(id: id, deletedAt: _clock());
  }

  @override
  Future<Entry> createEntry({
    required String dayId,
    required EntryType type,
    String? textContent,
    String? mediaId,
    String? thumbnailMediaId,
    int? durationMs,
  }) async {
    final now = _clock();
    final row = await _entries.insertEntry(
      id: _newId(),
      dayId: dayId,
      type: type.id,
      textContent: textContent,
      mediaId: mediaId,
      thumbnailMediaId: thumbnailMediaId,
      durationMs: durationMs,
      createdAt: now,
      updatedAt: now,
    );
    return toDomainEntry(row);
  }

  @override
  Future<Entry?> entryById(String id) async {
    final row = await _entries.entryById(id);
    return row == null ? null : toDomainEntry(row);
  }

  @override
  Future<void> updateEntryText({
    required String id,
    required String textContent,
  }) async {
    await _entries.updateText(
      id: id,
      textContent: textContent,
      updatedAt: _clock(),
    );
  }

  @override
  Future<void> softDeleteEntry(String id) async {
    await _entries.softDelete(id: id, deletedAt: _clock());
  }

  @override
  Future<List<Entry>> entriesForDay(String dayId) async {
    final rows = await _entries.activeEntriesForDay(dayId);
    return rows.map(toDomainEntry).toList();
  }

  @override
  Future<EntryPhoto> addPhoto({
    required String entryId,
    required String mediaId,
    required int sortOrder,
  }) async {
    final now = _clock();
    final row = await _photos.insertPhoto(
      id: _newId(),
      entryId: entryId,
      mediaId: mediaId,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );
    return toDomainEntryPhoto(row);
  }

  @override
  Future<List<EntryPhoto>> photosForEntry(String entryId) async {
    final rows = await _photos.activePhotosForEntry(entryId);
    return rows.map(toDomainEntryPhoto).toList();
  }

  @override
  Future<void> softDeletePhoto(String id) async {
    await _photos.softDelete(id: id, deletedAt: _clock());
  }

  @override
  Stream<Day?> watchDayForDate(String date) {
    return _days
        .watchActiveDayForDate(date)
        .map((row) => row == null ? null : toDomainDay(row));
  }

  @override
  Stream<List<Day>> watchDaysInMonth({required int year, required int month}) {
    final prefix = '${_pad4(year)}-${_pad2(month)}-';
    return _days
        .watchActiveDaysInMonth(prefix)
        .map((rows) => rows.map(toDomainDay).toList());
  }

  @override
  Stream<List<Day>> watchAllDays() {
    return _days
        .watchAllActiveDays()
        .map((rows) => rows.map(toDomainDay).toList());
  }

  @override
  Stream<List<Entry>> watchEntriesForDay(String dayId) {
    return _entries
        .watchActiveEntriesForDay(dayId)
        .map((rows) => rows.map(toDomainEntry).toList());
  }

  @override
  Stream<List<Entry>> watchEntriesForDate(String date) {
    return _entries
        .watchActiveEntriesForDate(date)
        .map((rows) => rows.map(toDomainEntry).toList());
  }

  @override
  Stream<List<EntryPhoto>> watchPhotosForEntry(String entryId) {
    return _photos
        .watchActivePhotosForEntry(entryId)
        .map((rows) => rows.map(toDomainEntryPhoto).toList());
  }

  @override
  Future<List<Day>> onThisDay({required int month, required int day}) async {
    final suffix = '-${_pad2(month)}-${_pad2(day)}';
    final rows = await _days.activeDaysOnMonthDay(suffix);
    return rows.map(toDomainDay).toList();
  }

  static int _systemClock() => DateTime.now().millisecondsSinceEpoch;

  static String _pad2(int value) => value.toString().padLeft(2, '0');

  static String _pad4(int value) => value.toString().padLeft(4, '0');
}
