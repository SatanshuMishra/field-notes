import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/note_plain_text.dart';
import 'package:field_notes/features/note_engine/capabilities.dart';
import 'package:flutter/foundation.dart';

class SearchEntryText {
  const SearchEntryText({required this.entryId, required this.plainText});

  final String entryId;
  final String plainText;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchEntryText &&
          runtimeType == other.runtimeType &&
          entryId == other.entryId &&
          plainText == other.plainText;

  @override
  int get hashCode => Object.hash(entryId, plainText);
}

class SearchDayView {
  const SearchDayView({
    required this.date,
    required this.mood,
    required this.entryCount,
    required this.preview,
    required this.searchText,
    this.entryTexts = const <SearchEntryText>[],
    this.matchedEntryId,
  });

  final String date;
  final Mood? mood;
  final int entryCount;
  final String preview;
  final String searchText;
  final List<SearchEntryText> entryTexts;
  final String? matchedEntryId;

  SearchDayView matching({
    required String entryId,
    required String preview,
  }) {
    return SearchDayView(
      date: date,
      mood: mood,
      entryCount: entryCount,
      preview: preview,
      searchText: searchText,
      entryTexts: entryTexts,
      matchedEntryId: entryId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchDayView &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          mood == other.mood &&
          entryCount == other.entryCount &&
          preview == other.preview &&
          searchText == other.searchText &&
          listEquals(entryTexts, other.entryTexts) &&
          matchedEntryId == other.matchedEntryId;

  @override
  int get hashCode => Object.hash(
        date,
        mood,
        entryCount,
        preview,
        searchText,
        Object.hashAll(entryTexts),
        matchedEntryId,
      );

  @override
  String toString() =>
      'SearchDayView(date: $date, mood: $mood, entryCount: $entryCount, '
      'preview: $preview, matchedEntryId: $matchedEntryId)';
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
    final List<SearchEntryText> entryTexts = _entryTextsFor(dayEntries);
    views.add(
      SearchDayView(
        date: day.date,
        mood: day.mood,
        entryCount: dayEntries.length,
        preview: _previewFor(dayEntries),
        searchText: _searchTextFor(day, entryTexts),
        entryTexts: entryTexts,
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

String _searchTextFor(Day day, List<SearchEntryText> entryTexts) {
  final Mood? mood = day.mood;
  return <String>[
    day.date,
    if (mood != null) mood.label,
    for (final SearchEntryText entry in entryTexts) entry.plainText,
  ].join('\n').toLowerCase();
}

List<SearchEntryText> _entryTextsFor(List<Entry> entries) {
  return List<SearchEntryText>.unmodifiable(<SearchEntryText>[
    for (final Entry entry in entries)
      if (entry.textContent case final String text when text.isNotEmpty)
        SearchEntryText(
          entryId: entry.id,
          plainText: plainTextOf(text, tables: tablesEnabled),
        ),
  ]);
}

String? _firstProjectedLine(String text) {
  for (final String line
      in plainTextOf(text, tables: tablesEnabled).split('\n')) {
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
