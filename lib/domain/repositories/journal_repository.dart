import '../models/models.dart';

abstract interface class JournalRepository {
  Future<Day> createDay({required String date, Mood? mood});

  Future<Day?> dayById(String id);

  Future<Day?> activeDayForDate(String date);

  Future<Day> ensureDayForDate(String date);

  Future<Day> setMoodForDate({required String date, Mood? mood});

  Future<void> setMood({required String dayId, Mood? mood});

  Future<void> softDeleteDay(String id);

  Future<Entry> createEntry({
    required String dayId,
    required EntryType type,
    String? textContent,
    String? mediaId,
    String? thumbnailMediaId,
    int? durationMs,
  });

  Future<Entry?> entryById(String id);

  Future<void> updateEntryText({
    required String id,
    required String textContent,
  });

  Future<void> softDeleteEntry(String id);

  Future<List<Entry>> entriesForDay(String dayId);

  Future<EntryPhoto> addPhoto({
    required String entryId,
    required String mediaId,
    required int sortOrder,
  });

  Future<List<EntryPhoto>> photosForEntry(String entryId);

  Future<void> softDeletePhoto(String id);

  Stream<Day?> watchDayForDate(String date);

  Stream<List<Day>> watchDaysInMonth({required int year, required int month});

  Stream<List<Day>> watchAllDays();

  Stream<List<Entry>> watchEntriesForDay(String dayId);

  Stream<List<Entry>> watchEntriesForDate(String date);

  Stream<List<EntryPhoto>> watchPhotosForEntry(String entryId);

  Future<List<Day>> onThisDay({required int month, required int day});
}
