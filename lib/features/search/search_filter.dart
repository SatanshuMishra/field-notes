import 'search_day_view.dart';

List<SearchDayView> filterSearchDays(
  List<SearchDayView> views,
  String query,
) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return views;
  }
  return <SearchDayView>[
    for (final SearchDayView view in views)
      if (view.searchText.contains(needle)) _focusOnMatch(view, needle),
  ];
}

SearchDayView _focusOnMatch(SearchDayView view, String needle) {
  for (final SearchEntryText entry in view.entryTexts) {
    if (entry.plainText.toLowerCase().contains(needle)) {
      return view.matching(
        entryId: entry.entryId,
        preview: _matchingLine(entry.plainText, needle),
      );
    }
  }
  return view;
}

String _matchingLine(String plainText, String needle) {
  final List<String> lines = <String>[
    for (final String line in plainText.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];
  for (final String line in lines) {
    if (line.toLowerCase().contains(needle)) {
      return line;
    }
  }
  return lines.isEmpty ? '' : lines.first;
}
