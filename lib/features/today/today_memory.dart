import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/note_plain_text.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/note_engine/capabilities.dart';

import 'today_date.dart';

const int memoryPreviewMaxLength = 90;

final RegExp _whitespaceRun = RegExp(r'\s+');

class OnThisDayMemory {
  const OnThisDayMemory({required this.day, required this.yearsAgo});

  final Day day;
  final int yearsAgo;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnThisDayMemory &&
          runtimeType == other.runtimeType &&
          day == other.day &&
          yearsAgo == other.yearsAgo;

  @override
  int get hashCode => Object.hash(day, yearsAgo);

  @override
  String toString() => 'OnThisDayMemory(day: $day, yearsAgo: $yearsAgo)';
}

OnThisDayMemory? selectOnThisDay({
  required List<Day> candidates,
  required DateTime today,
}) {
  final String todayKey = captureDateKey(today);
  final int currentYear = today.toLocal().year;
  OnThisDayMemory? best;
  for (final Day day in candidates) {
    if (day.isDeleted || day.date == todayKey) {
      continue;
    }
    final DateTime? moment = parseDateKey(day.date);
    if (moment == null) {
      continue;
    }
    final int yearsAgo = currentYear - moment.year;
    if (yearsAgo < 1) {
      continue;
    }
    if (best == null || yearsAgo < best.yearsAgo) {
      best = OnThisDayMemory(day: day, yearsAgo: yearsAgo);
    }
  }
  return best;
}

String? firstTextPreview(List<Entry> entries) {
  for (final Entry entry in entries) {
    if (entry.isDeleted || entry.type != EntryType.text) {
      continue;
    }
    final String collapsed =
        plainTextOf(entry.textContent ?? '', tables: tablesEnabled)
            .replaceAll(_whitespaceRun, ' ')
            .trim();
    if (collapsed.isEmpty) {
      continue;
    }
    if (collapsed.length <= memoryPreviewMaxLength) {
      return collapsed;
    }
    return '${collapsed.substring(0, memoryPreviewMaxLength)}…';
  }
  return null;
}
