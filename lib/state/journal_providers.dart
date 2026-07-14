import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'journal_providers.g.dart';

@riverpod
Stream<List<Day>> allDays(Ref ref) {
  return ref.watch(journalRepositoryProvider).watchAllDays();
}

@riverpod
Stream<Day?> dayForDate(Ref ref, String date) {
  return ref.watch(journalRepositoryProvider).watchDayForDate(date);
}

@riverpod
Stream<List<Day>> daysInMonth(
  Ref ref, {
  required int year,
  required int month,
}) {
  return ref
      .watch(journalRepositoryProvider)
      .watchDaysInMonth(year: year, month: month);
}

@riverpod
Stream<List<Entry>> entriesForDate(Ref ref, String date) {
  return ref.watch(journalRepositoryProvider).watchEntriesForDate(date);
}

@riverpod
Stream<List<Entry>> entriesForDay(Ref ref, String dayId) {
  return ref.watch(journalRepositoryProvider).watchEntriesForDay(dayId);
}

@riverpod
Stream<List<EntryPhoto>> photosForEntry(Ref ref, String entryId) {
  return ref.watch(journalRepositoryProvider).watchPhotosForEntry(entryId);
}
