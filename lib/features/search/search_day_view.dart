import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/notes.dart';

class SearchDayView {
  const SearchDayView({
    required this.date,
    required this.mood,
    required this.entryCount,
    required this.preview,
    required this.searchText,
  });

  final String date;
  final Mood? mood;
  final int entryCount;
  final String preview;
  final String searchText;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchDayView &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          mood == other.mood &&
          entryCount == other.entryCount &&
          preview == other.preview &&
          searchText == other.searchText;

  @override
  int get hashCode =>
      Object.hash(date, mood, entryCount, preview, searchText);

  @override
  String toString() =>
      'SearchDayView(date: $date, mood: $mood, entryCount: $entryCount, '
      'preview: $preview)';
}

List<SearchDayView> buildSearchDayViews(List<Day> days, List<Entry> entries) {
  final Map<String, List<Entry>> byDayId = <String, List<Entry>>{};
  for (final Entry entry in entries) {
    (byDayId[entry.dayId] ??= <Entry>[]).add(entry);
  }

  final List<SearchDayView> views = <SearchDayView>[];
  for (final Day day in days) {
    final List<Entry> dayEntries =
        List<Entry>.of(byDayId[day.id] ?? const <Entry>[])
          ..sort((Entry a, Entry b) => a.createdAt.compareTo(b.createdAt));
    views.add(
      SearchDayView(
        date: day.date,
        mood: day.mood,
        entryCount: dayEntries.length,
        preview: _previewFor(dayEntries),
        searchText: _searchTextFor(day, dayEntries),
      ),
    );
  }
  return views;
}

String _previewFor(List<Entry> entries) {
  for (final Entry entry in entries) {
    final String? text = entry.textContent;
    if (text == null) {
      continue;
    }
    final String? line = _firstProjectedLine(text);
    if (line != null) {
      return line;
    }
  }
  if (entries.isEmpty) {
    return '';
  }
  return _typeLabel(entries.first.type);
}

String _searchTextFor(Day day, List<Entry> entries) {
  final List<String> parts = <String>[day.date];
  final Mood? mood = day.mood;
  if (mood != null) {
    parts.add(mood.label);
  }
  for (final Entry entry in entries) {
    final String? text = entry.textContent;
    if (text != null && text.isNotEmpty) {
      parts.add(plainTextOf(text));
    }
  }
  return parts.join('\n').toLowerCase();
}

String? _firstProjectedLine(String text) {
  for (final String line in plainTextOf(text).split('\n')) {
    final String trimmed = line.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

String _typeLabel(EntryType type) {
  switch (type) {
    case EntryType.text:
      return 'Text note';
    case EntryType.voice:
      return 'Voice recording';
    case EntryType.video:
      return 'Video recording';
  }
}
